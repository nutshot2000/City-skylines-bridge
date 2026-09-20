#requires -Version 7.5
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Command,
 [string]$ArgsJson='{}',[string]$ArgsFile='',
 [ValidateRange(1,60)][int]$WaitSeconds=10,
 [string]$MailboxPath=(Join-Path $env:LOCALAPPDATA 'CitiesIIAgentBridge'),
 [string]$RecordPath=(Join-Path $PSScriptRoot 'records')
)
$ErrorActionPreference='Stop'
$client=Join-Path $PSScriptRoot 'bridge-client.ps1'
function Send([string]$Name,[string]$Json) {
 $raw=& $client $Name -ArgsJson $Json -MailboxPath $MailboxPath
 $r=($raw -join "`n")|ConvertFrom-Json -DateKind String
 New-Item -ItemType Directory -Force $RecordPath|Out-Null
 $r|ConvertTo-Json -Depth 60|Set-Content (Join-Path $RecordPath (([guid]::NewGuid().ToString('N'))+'-'+$Name+'.json'))
 if($r.ok -and $null -eq $r.result){throw "result_missing_outcome_unknown_do_not_repeat"}; if(!$r.ok){throw "$Name rejected: $($r.error)"}
 return $r
}
try {
 if($ArgsFile){$ArgsJson=Get-Content -LiteralPath $ArgsFile -Raw}
 $envelope=Send $Command $ArgsJson
 $result=$envelope.result
 $poll=$null;$id=$null
 if($Command -eq 'execute_neighborhood'){$id=$result.batch.id;$poll='get_batch';$result=$result.batch}
 elseif($Command -in @('batch_execute','get_batch')){$id=$result.id;$poll='get_batch'}
 elseif($Command -in @('simulate_step','get_simulation_step')){$id=$result.id;$poll='get_simulation_step'}
 elseif($result.id -and $result.status){$id=$result.id;$poll='get_operation'}
 $end=[DateTime]::UtcNow.AddSeconds($WaitSeconds)
 if(($poll -or $result.status -in @('queued','running','validating','applying')) -and !$id){throw "operation_id_missing_outcome_unknown_do_not_repeat"}
 $progressAt=[DateTime]::UtcNow.AddSeconds(5)
 while($poll -and $result.status -in @('queued','running','validating','applying')) {
  if([DateTime]::UtcNow -ge $end){
   @{status='pending_do_not_resubmit';operationId=$id;pollCommand=$poll;next="Run agent.ps1 -Command $poll -ArgsJson '{`"id`":`"$id`"}'. Do not repeat $Command."}|ConvertTo-Json -Depth 5
   exit 2
  }
  if([DateTime]::UtcNow -ge $progressAt){[Console]::Error.WriteLine("Still waiting for $poll $id ($($result.status)); no construction is being repeated.");$progressAt=[DateTime]::UtcNow.AddSeconds(5)}
  Start-Sleep -Milliseconds 1000
  $reply=Send $poll (@{id=$id}|ConvertTo-Json -Compress)
  if($reply.session -ne $envelope.session -or $reply.citySession -ne $envelope.citySession){throw 'City/session changed while waiting. Outcome unknown; do not replay.'}
  $result=$reply.result
 }
 # Preserve canonical keys; add unambiguous aliases for older binaries.
 if($Command -in @('get_batch','batch_execute','execute_neighborhood')){
  if(!$result.PSObject.Properties['completedCount']){$result|Add-Member completedCount $result.completed}
  if(!$result.PSObject.Properties['failureIndex']){$result|Add-Member failureIndex $result.failedStep}
 }
 @{status=if($result.status){$result.status}else{'response_received'};result=$result;note='Completion is verified only for the requested operation. Utility delivery and resident access need separate observations.'}|ConvertTo-Json -Depth 60
 if($result.status -in @('failed','interrupted')){exit 1}
} catch {
 @{status=if($_.Exception.Message -match 'stagnant|reassess_required'){'stagnant_no_progress'}elseif($_.Exception.Message -match 'zone_has_no_growables|use_zoning_for_growables'){'invalid_zone'}elseif($_.Exception.Message -match 'finish_or_cancel|construction_busy|tool_operation'){'tool_busy'}else{'failed_or_outcome_unknown'};error=$_.Exception.Message;next='Inspect the original response/operation. Never automatically repeat a mutation.'}|ConvertTo-Json
 exit 1
}
