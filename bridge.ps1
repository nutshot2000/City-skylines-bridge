param(
    [ValidateSet('get_status','get_nearby_infrastructure','get_zone_catalog','get_tool_status','cancel_tool','get_outside_connections','batch_execute','build_network','build_road','cancel_batch','cancel_simulation_step','clear_zoning','demolish','diagnose_connections','execute_neighborhood','find_building_sites','get_batch','get_build_prefabs','get_buildings','get_camera','get_capabilities','get_city_diagnostics','get_city_management','get_city_map','get_city_state','get_neighborhood_plan','get_network','get_network_edges','get_operation','get_prefab_details','get_selected','get_services','get_simulation_step','get_tiles','get_water_facilities','get_zone_cells','inspect_entity','pause_for_analysis','ping','place_building','plan_neighborhood','preview_building','purchase_tiles','relocate_building','sample_terrain','save_checkpoint','set_camera','set_service_budget','set_simulation_speed','set_tax','simulate_step','trace_network','upgrade_network','zone_rectangle','stop')]
    [string]$Command = 'ping',
    [string]$ArgsJson = '{}',
    [ValidateRange(1,45)][int]$TimeoutSeconds = 15,
    [string]$MailboxPath = (Join-Path $env:LOCALAPPDATA 'CitiesIIAgentBridge'),
    [switch]$LibraryOnly
)
$ErrorActionPreference = 'Stop'
function Get-HeartbeatUtc($Value) {
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime() }
    if ($Value -is [datetime]) {
        if ($Value.Kind -eq [DateTimeKind]::Unspecified) { throw 'Heartbeat DateTime has no timezone; refuse ambiguous time.' }
        return [DateTimeOffset]$Value.ToUniversalTime()
    }
    return [DateTimeOffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
}
function Convert-RequestBytes($Packet) {
    $json=$Packet | ConvertTo-Json -Depth 30 -Compress
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($json)
    if ($bytes.Length -gt 16384) { throw "request_too_large_before_send: $($bytes.Length) bytes, limit 16384. Split this request; no command was sent." }
    return ,$bytes
}
function Read-MailboxText([string]$Path) {
    # Permit atomic replacement while reading a complete snapshot from the open handle.
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
        ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $reader = $null
    try {
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true)
        return $reader.ReadToEnd()
    } finally {
        if ($null -ne $reader) { $reader.Dispose() } else { $stream.Dispose() }
    }
}
function Test-MailboxReadContention($ErrorRecord) {
    $cause = $ErrorRecord.Exception.GetBaseException()
    return $cause -is [IO.IOException] -and (($cause.HResult -band 0xffff) -in @(32,33))
}
function Record-JournalEvent($text,$requestId,$result) {
    # Logging failure must never change command delivery or cause a mutation retry.
    if(!(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'journals\active.json'))){return}
    try {
        $event=@{text=$text;command=$Command;requestId=$requestId;args=($ArgsJson|ConvertFrom-Json);result=$result}
        & (Join-Path $PSScriptRoot 'journal.ps1') event -EventJson ($event|ConvertTo-Json -Depth 25 -Compress) | Out-Null
    } catch {Write-Warning "Journal update failed: $($_.Exception.Message)"}
}
if ($LibraryOnly) { return }
if ($Command -eq 'stop') {
    New-Item -ItemType Directory -Force -Path $MailboxPath | Out-Null
    [IO.File]::WriteAllText((Join-Path $MailboxPath 'STOP'), [DateTime]::UtcNow.ToString('O'))
    Record-JournalEvent 'Control stop requested; inspection remains available.' '' $null
    Write-Output '{"ok":true,"message":"Control stop requested. Inspection remains available."}'
    return
}
$sessionPath = Join-Path $MailboxPath 'session.json'
# Heartbeat replacement can briefly make the file unavailable; retry only this read,
# before generating or sending any command, so mutations are never replayed.
for ($heartbeatAttempt = 0; $heartbeatAttempt -lt 10; $heartbeatAttempt++) {
    try { $session = Read-MailboxText $sessionPath | ConvertFrom-Json; break }
    catch { if ($heartbeatAttempt -eq 9) { throw }; Start-Sleep -Milliseconds 50 }
}
$heartbeatAge=([DateTimeOffset]::UtcNow - (Get-HeartbeatUtc $session.heartbeatUtc)).TotalSeconds
if ($session.status -ne 'ready' -or $heartbeatAge -gt 10 -or $heartbeatAge -lt -5) {
    throw 'Bridge heartbeat is stale or clock is invalid. Close Options/pause menus, return to the city, and check game responsiveness. Nothing was sent. Do not restart or replay a previous mutation automatically.'
}
$arguments = $ArgsJson | ConvertFrom-Json
if ($null -eq $arguments -or $arguments -isnot [pscustomobject]) { throw 'ArgsJson must be a JSON object' }
if ($Command -eq 'sample_terrain' -and @($arguments.points).Count -gt 32) {
    $points=@($arguments.points)
    if($points.Count -gt 1024){throw 'At most 1024 terrain points per helper call; none sent.'}
    $samples=[System.Collections.Generic.List[object]]::new()
    for($offset=0;$offset -lt $points.Count;$offset+=32){
        $last=[Math]::Min($offset+31,$points.Count-1)
        $part= & $PSCommandPath sample_terrain -ArgsJson (@{points=@($points[$offset..$last])}|ConvertTo-Json -Depth 12 -Compress) -TimeoutSeconds $TimeoutSeconds -MailboxPath $MailboxPath
        $r=($part -join "`n")|ConvertFrom-Json
        if(!$r.ok){$r|ConvertTo-Json -Depth 30;return}
        if($r.session -ne $session.session -or $r.citySession -ne $session.citySession){throw 'City changed during terrain sampling. Discard partial results; no mixed-session result returned.'}
        foreach($sample in $r.result.samples){$samples.Add($sample)}
    }
    @{ok=$true;protocol=1;session=$session.session;citySession=$session.citySession;result=@{samples=$samples.ToArray();chunked=$true;chunks=[Math]::Ceiling($points.Count/32.0)}}|ConvertTo-Json -Depth 30
    return
}
$id = [Guid]::NewGuid().ToString('N')
$packet = [ordered]@{
    protocol = 1; id = $id; session = $session.session; citySession = $session.citySession
    command = $Command; args = $arguments; expiresUtc = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds).ToString('O')
}
$requestPath = Join-Path (Join-Path $MailboxPath 'requests') "$id.json"
$responsePath = Join-Path (Join-Path $MailboxPath 'responses') "$id.json"
$temp = "$requestPath.tmp"
[IO.File]::WriteAllBytes($temp, (Convert-RequestBytes $packet))
[IO.File]::Move($temp, $requestPath)
Record-JournalEvent "Sent $Command (request $id). Completion is not yet confirmed." $id $null
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds + 2)
while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $responsePath) {
        try { $responseText=Read-MailboxText $responsePath }
        catch {
            if (!(Test-MailboxReadContention $_)) { throw }
            # Keep polling this response ID within the original deadline; never resend.
            Start-Sleep -Milliseconds 50
            continue
        }
        try {
            $response=$responseText|ConvertFrom-Json
            $summary=@{ok=$response.ok;status=$response.result.status;operationId=$response.result.id;error=$response.error}
            Record-JournalEvent "$Command response: ok=$($summary.ok); status=$($summary.status)." $id $summary
        } catch {Write-Warning 'Could not summarize bridge response for the journal.'}
        Write-Output $responseText
        return
    }
    Start-Sleep -Milliseconds 100
}
Record-JournalEvent "$Command timed out; outcome unknown. Inspect before retrying." $id $null
throw "outcome_unknown: Request $id timed out. Inspect $responsePath for the ORIGINAL response; do not resend. Close native menus and check heartbeat/game responsiveness. The request deadline is not the operation deadline: if the response contains an operation or batch ID, poll that ID. Never assume expiry undid an already-dispatched action."
