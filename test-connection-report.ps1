#requires -Version 7.5
$ErrorActionPreference='Stop'
. "$PSScriptRoot/connection-report.ps1"
$script:count=0;$script:reads=0;$script:sessions=0;$script:change=$false
$script:nodeType='Game.Simulation.WaterPipeNodeConnection'
$script:path=@{connected=$true;edges=@(@{index=9;version=1});visited=2}
function Session {$script:sessions++;@{session='s';citySession=if($script:change -and $script:sessions -gt 1){'different'}else{'c'}}}
function Call($Command,$Data){
 $script:reads++
 switch($Command){
  'inspect_entity' {return @{index=$Data.index;version=$Data.version;position=@{x=0;y=-10;z=0};components=@('Game.Net.Node',$script:nodeType)}}
  'trace_network' {return $script:path}
  default {throw "Unexpected command $Command"}
 }
}
function Check($ok,$label){if(!$ok){throw "FAIL: $label"};$script:count++;Write-Output "PASS: $label"}
$r=CheckUtilityConnection 1 1 2 1
Check ($r.physicalConnection -eq $true -and $r.supplying -eq 'not_verified' -and !$r.continueConstruction) 'physical path never certifies flow or authorizes further building'
Check ($script:reads -eq 3) 'inspection uses only three reads'
$script:path=@{connected=$false;edges=@();visited=3};$r=CheckUtilityConnection 1 1 2 1
Check ($r.status -eq 'disconnected_stop' -and !$r.retryOriginal) 'missing path stops construction without replay'
$script:path.visited=100001;$r=CheckUtilityConnection 1 1 2 1
Check ($r.status -eq 'connection_unknown_stop' -and $null -eq $r.physicalConnection) 'truncated trace is unknown not disconnected'
$script:path=@{connected=$true;edges=@();visited=2};$r=CheckUtilityConnection 1 1 2 1
Check ($r.status -eq 'connection_unknown_stop') 'empty path between distinct nodes is not proof'
$script:nodeType='Game.Net.Road';$script:reads=0;$r=CheckUtilityConnection 1 1 2 1
Check ($r.status -eq 'connection_unknown_stop' -and $script:reads -eq 2) 'ordinary road node is not a utility connector'
$script:nodeType='Game.Simulation.WaterPipeNodeConnection';$script:path=@{connected=$true;edges=@(@{index=9;version=1});visited=2};$script:change=$true;$script:sessions=0
$r=CheckUtilityConnection 1 1 2 1
Check ($r.status -eq 'connection_unknown_stop' -and $null -eq $r.physicalConnection) 'mixed city snapshots rejected'
$script:change=$false;$script:reads=0;$r=CheckUtilityConnection 1 1 2 1 @{session='old';citySession='c'}
Check ($r.status -eq 'connection_unknown_stop' -and $script:reads -eq 0) 'construction receipt from another session cannot verify'
$failed=$false;try{CheckUtilityConnection 1 1 1 1}catch{$failed=$true};Check $failed 'self connection rejected'
Write-Output "$script:count connection checks passed. No game commands sent."
