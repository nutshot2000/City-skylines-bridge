#requires -Version 7.5
$ErrorActionPreference='Stop'
. "$PSScriptRoot/coach.ps1" -LibraryOnly
$script:checks=0
function Check($Condition,[string]$Label){if(!$Condition){throw "FAIL: $Label"};$script:checks++;Write-Output "PASS: $Label"}
function Reject([scriptblock]$Body,[string]$Label){$failed=$false;try{& $Body|Out-Null}catch{$failed=$true};Check $failed $Label}
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('utility-coach-tests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tmp|Out-Null
$RecordPath=Join-Path $tmp 'records'
$city=@{cityName='Fixture';money=1000;selectedSpeed=0;controlEnabled=$true}
$buildings=@{buildings=@(@{index=1;version=1;prefab='Ruins';components=@('Game.Common.Native');issues=@('no_road_connection')},@{index=2;version=1;prefab='Transformer';components=@('Game.Buildings.Transformer');issues=@()})}
$diag=@{utilitiesRaw=@{electricity=@{capacity=0;production=0};water=@{capacity=0;production=0};sewage=@{capacity=0;processing=0}};persistentShortages=@()}
$r=Diagnose $city $buildings $diag
Check ($r.buildings.Count -eq 1) 'native decorations excluded'
Check ($r.buildings[0].roles -contains 'transformer_not_generator') 'transformer never classified as generator'
Check ($r.status -eq 'inspection_only_supply_not_certified') 'zero demand and zero shortages do not imply success'
Check (($r.next -join ' ') -match 'No local freshwater') 'missing freshwater gets a concrete next step'
$r=Diagnose $city $buildings $null
Check ($r.partial -and ($r.next -join ' ') -notmatch 'No local freshwater') 'missing diagnostics stays unknown'
$s=@{session='s';citySession='c'}
$p=@{schema=1;id=[guid]::NewGuid().ToString('N');session='s';citySession='c';expiresUtc=[DateTimeOffset]::UtcNow.AddMinutes(5).ToString('O');command='place_building';prefabName='FixtureSource';reserve=500;args=@{maxCost=100;prefabIndex=10;prefabVersion=1;position=@{x=1;z=2};allowDemolition=$false}}
ValidatePlan $p $s $city
Check $true 'valid plan accepted'
$p.citySession='other';Reject {ValidatePlan $p $s $city} 'cross-city plan rejected';$p.citySession='c'
$p.expiresUtc=[DateTimeOffset]::UtcNow.AddMinutes(-1).ToString('O');Reject {ValidatePlan $p $s $city} 'expired plan rejected';$p.expiresUtc=[DateTimeOffset]::UtcNow.AddMinutes(5).ToString('O')
$p.reserve=999;Reject {ValidatePlan $p $s $city} 'reserve protected';$p.reserve=500
$p.args.allowDemolition=$true;Reject {ValidatePlan $p $s $city} 'collateral demolition blocked';$p.args.allowDemolition=$false
$p.command='build_network';$p.args.elevation=-10;Reject {ValidatePlan $p $s $city} 'double-offset node height blocked';$p.command='place_building';$p.args.Remove('elevation')
$nodeA=@{index=20;version=1;position=@{x=0;y=0;z=0};components=@('Game.Net.Node','Game.Simulation.WaterPipeNodeConnection')}
$nodeB=@{index=21;version=1;position=@{x=100;y=0;z=0};components=@('Game.Net.Node','Game.Simulation.WaterPipeNodeConnection')}
CheckNodes @{name='Small Water Pipe'} $nodeA $nodeB
Check $true 'compatible pipe nodes accepted'
Reject {CheckNodes @{name='Power Line'} $nodeA $nodeB} 'water nodes cannot be used as electricity connectors'
$nodeB.components=@('Game.Net.Node');Reject {CheckNodes @{name='Small Water Pipe'} $nodeA $nodeB} 'ordinary road node rejected as utility connector'
$nodeB.components=$nodeA.components;$nodeB.position.x=1001;Reject {CheckNodes @{name='Small Water Pipe'} $nodeA $nodeB} 'oversized connection rejected'
# Mock all bridge access below. These tests never talk to the game.
function Session {return $s}
function Control {return $s}
$script:calls=[System.Collections.Generic.List[string]]::new();$script:saveStatus='complete';$script:buildStatus='complete'
function Call([string]$Command,[hashtable]$Data=@{}) {
 $script:calls.Add($Command)
 switch($Command){
  'get_city_state' {return $city}
  'save_checkpoint' {return @{id='save'}}
  'get_operation' {if($Data.id -eq 'save'){return @{id='save';status=$script:saveStatus;saveName='fixture-save'}};return @{id='build';status=$script:buildStatus}}
  'get_prefab_details' {return @{name='FixtureSource';locked=$false}}
  'place_building' {return @{id='build';status='queued'}}
  default {throw "Unexpected mocked command: $Command"}
 }
}
$PlanPath=Join-Path $tmp 'plan.json';$p|ConvertTo-Json -Depth 10|Set-Content $PlanPath
$r=ApplyPlan
Check ($r.status -eq 'complete' -and @($script:calls|Where-Object {$_ -eq 'place_building'}).Count -eq 1) 'one submit followed by operation polling'
$renamed=Join-Path $tmp 'renamed.json';Copy-Item $PlanPath $renamed;$PlanPath=$renamed
Reject {ApplyPlan} 'renaming plan cannot bypass durable attempt guard'
Check (@($script:calls|Where-Object {$_ -eq 'place_building'}).Count -eq 1) 'duplicate attempt sent no second mutation'
$p.id=[guid]::NewGuid().ToString('N');$PlanPath=Join-Path $tmp 'save-failure.json';$p|ConvertTo-Json -Depth 10|Set-Content $PlanPath;$script:saveStatus='failed'
Reject {ApplyPlan} 'failed checkpoint prevents construction'
Check (@($script:calls|Where-Object {$_ -eq 'place_building'}).Count -eq 1) 'save failure did not dispatch construction'
$script:buildStatus='running';$r=Await 'build' 'get_operation' 0
Check ($r.status -eq 'pending_do_not_resubmit' -and $r.id -eq 'build') 'poll deadline retains original operation ID'
Check (@($script:calls|Where-Object {$_ -eq 'place_building'}).Count -eq 1) 'poll timeout never resubmits mutation'
Write-Output "$script:checks checks passed. No game commands sent. Fixtures: $tmp"
