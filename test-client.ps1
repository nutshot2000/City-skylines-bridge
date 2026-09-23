#requires -Version 7.5
$ErrorActionPreference='Stop'
. "$PSScriptRoot/bridge-client.ps1" -LibraryOnly
$n=0
function Check($Condition,$Name){if(!$Condition){throw "FAIL: $Name"};$script:n++;Write-Output "PASS: $Name"}
$original=[Threading.Thread]::CurrentThread.CurrentCulture
try {
 foreach($culture in @('en-GB','en-US','de-DE')){
  [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo($culture)
  $expected=[DateTimeOffset]::Parse('2026-09-20T12:00:00Z',[Globalization.CultureInfo]::InvariantCulture)
  foreach($value in @('2026-09-20T12:00:00Z','2026-09-20T13:00:00+01:00',$expected.UtcDateTime,$expected)){
   Check ((Get-HeartbeatUtc $value) -eq $expected) "culture $culture preserves UTC for $($value.GetType().Name)"
  }
 }
} finally {[Threading.Thread]::CurrentThread.CurrentCulture=$original}
$failed=$false;try{Get-HeartbeatUtc ([datetime]::SpecifyKind([datetime]::Now,[DateTimeKind]::Unspecified))|Out-Null}catch{$failed=$true}
Check $failed 'timezone-free DateTime is rejected'
$bytes=Convert-RequestBytes @{id='x';args=@{label=('é'*100)}}
Check ($bytes.Length -eq [Text.Encoding]::UTF8.GetByteCount([Text.Encoding]::UTF8.GetString($bytes))) 'UTF-8 byte count is checked, not character count'
$failed=$false;try{Convert-RequestBytes @{data=('x'*17000)}|Out-Null}catch{$failed=$true}
Check $failed 'oversized packet rejected before file write'
# Synthetic server tests terrain chunking and async wrapper polling, never the game.
$root=Join-Path ([IO.Path]::GetTempPath()) ('coach-protocol-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$root/requests","$root/responses"|Out-Null
$job=Start-Job -ArgumentList $root -ScriptBlock {
 param($root)
 $deadline=[DateTime]::UtcNow.AddSeconds(40);$seen=@{};$chunks=0;$mutations=0;$polls=0
 while([DateTime]::UtcNow -lt $deadline -and !(Test-Path "$root/done")){
  $session=@{status='ready';session='fixture';citySession='city';heartbeatUtc=[DateTime]::UtcNow.ToString('O');controlEnabled=$true}
  $temp="$root/session.tmp";$session|ConvertTo-Json -Compress|Set-Content $temp;Move-Item $temp "$root/session.json" -Force
  foreach($file in Get-ChildItem "$root/requests/*.json"){
   if($seen[$file.Name]){continue};$seen[$file.Name]=$true
   $q=Get-Content $file -Raw|ConvertFrom-Json
   switch($q.command){
    'sample_terrain' {$chunks++;$result=@{samples=@($q.args.points|ForEach-Object {@{position=$_;waterDepth=0}})}}
    'get_chirper' {$result=@{posts=@(@{text='Please improve healthcare';sender=@{index=6;version=1};creationFrame=10;likes=2});limit=$q.args.limit;pausesGame=$false}}
    'ping' {$result=$null}
    'get_tool_status' {$result=@{status='queued'}}
    'save_checkpoint' {$mutations++;$result=@{id='op';status='queued';kind='save'}}
    'get_operation' {$polls++;$result=@{id='op';status=if($polls -ge 2){'complete'}else{'queued'};kind='save'}}
    default {throw "Unexpected command $($q.command)"}
   }
   $r=@{ok=$true;id=$q.id;session='fixture';citySession='city';result=$result}
   $tmp="$root/responses/$($q.id).tmp";$r|ConvertTo-Json -Depth 15 -Compress|Set-Content $tmp;Move-Item $tmp "$root/responses/$($q.id).json"
  }
  Start-Sleep -Milliseconds 20
 }
 @{chunks=$chunks;mutations=$mutations;polls=$polls}
}
try {
 $deadline=[DateTime]::UtcNow.AddSeconds(10)
 while(!(Test-Path "$root/session.json") -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 50}
 $points=@(1..169|ForEach-Object {@{x=$_;z=0}})
 $r=(& "$PSScriptRoot/bridge-client.ps1" sample_terrain -ArgsJson (@{points=$points}|ConvertTo-Json -Depth 5 -Compress) -MailboxPath $root)|ConvertFrom-Json
 Check ($r.ok -and $r.result.samples.Count -eq 169 -and $r.result.chunks -eq 6) '169 terrain points automatically split and recombined'
 Check ($r.result.samples[168].position.x -eq 169) 'terrain sample order preserved'
 Check (@(Get-ChildItem "$root/requests/*.json"|Where-Object Length -gt 16384).Count -eq 0) 'all chunk packets fit the actual byte cap'
 $r=(& "$PSScriptRoot/agent.ps1" -Command save_checkpoint -MailboxPath $root -RecordPath "$root/records")|ConvertFrom-Json
 Check ($r.status -eq 'complete') 'agent wrapper waits for operation completion'
 $r=(& "$PSScriptRoot/agent.ps1" -Command ping -MailboxPath $root -RecordPath "$root/records")|ConvertFrom-Json
 Check ($r.status -eq 'failed_or_outcome_unknown' -and $r.error -match 'result_missing') 'null result cannot appear successful'
 $r=(& "$PSScriptRoot/agent.ps1" -Command get_tool_status -MailboxPath $root -RecordPath "$root/records")|ConvertFrom-Json
 Check ($r.status -eq 'failed_or_outcome_unknown' -and $r.error -match 'operation_id_missing') 'queued result without ID is not completion'
 $r=(& "$PSScriptRoot/coach.ps1" chirper -Limit 2 -MailboxPath $root -RecordPath "$root/records")|ConvertFrom-Json
 Check ($r.limit -eq 2 -and $r.posts[0].text -eq 'Please improve healthcare' -and !$r.pausesGame) 'Chirper helper passes limit and preserves native feed fields'
 New-Item -ItemType File "$root/done"|Out-Null
 $stats=Receive-Job $job -Wait
 Check ($stats.mutations -eq 1 -and $stats.polls -eq 2) 'wrapper sends mutation once and polls original ID'
} finally {Stop-Job $job -ErrorAction SilentlyContinue;Remove-Job $job -Force -ErrorAction SilentlyContinue}
Write-Output "$n client checks passed. No game commands sent."
