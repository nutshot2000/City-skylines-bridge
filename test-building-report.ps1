$ErrorActionPreference='Stop'
. "$PSScriptRoot/building-report.ps1"
$n=0
function Check($ok,$label){if(!$ok){throw "FAIL: $label"};$script:n++;Write-Output "PASS: $label"}
$entity=@{index=12;version=2;prefab='Home';components=@('Game.Buildings.Building');position=@{x=1;z=2}}
$detail=@{index=12;version=2;roadEdge=@{index=30;version=3};electricityConsumer=@{wantedConsumption=4;fulfilledConsumption=1};waterConsumer=@{wantedConsumption=2;fulfilledFresh=2;fulfilledSewage=0};issues=@()}
$road=@{index=30;version=3;components=@('Game.Net.Edge')}
$r=Get-BuildingReport $entity $detail $road $null
Check ($r.utilities.electricity.state -eq 'shortfall' -and $r.utilities.sewage.state -eq 'shortfall') 'electricity and sewage shortfalls retained'
Check ($r.utilities.freshwater.state -eq 'demand_fulfilled_at_snapshot') 'fulfilled demand is snapshot evidence only'
Check ($r.road.state -eq 'live_edge_reference_routing_unverified') 'live edge does not certify routing'
Check ($r.nextCommand.parameters.Index -eq 12 -and $r.nextCommand.parameters.Version -eq 2) 'next command preserves building identity'
$r=Get-BuildingReport $entity $null $null $null
Check ($r.utilities.electricity.state -eq 'unknown' -and $r.unknown.Count -gt 0) 'missing row never looks healthy'
Check ((Get-UtilityReading 0 0).state -eq 'no_demand_unproven') 'zero demand never certifies supply'
$detail.electricityConsumer=$null;$detail.serviceDataRaw=@{'Game.Buildings.ElectricityConsumer'=@{m_WantedConsumption=5;m_FulfilledConsumption=2}}
$r=Get-BuildingReport $entity $detail $null 'stale'
Check ($r.utilities.electricity.wanted -eq 5 -and $r.road.state -eq 'unknown') 'older raw readings supported and stale road stays unknown'
$entity.components+= 'Game.Objects.UnderConstruction'
$r=Get-BuildingReport $entity $detail $road $null
Check ($r.underConstruction -and ($r.findings -join ' ') -match 'blocker is unknown') 'construction does not invent a blocker'
function Session { @{session='a';citySession='city'} }
$calls=[System.Collections.Generic.List[string]]::new()
$script:fixtureEntity=$entity;$script:fixtureDetail=$detail;$script:fixtureRoad=$road
function Call($command,$data){$script:calls.Add($command);if($command -eq 'get_buildings'){return @{buildings=@($script:fixtureDetail)}};if($data.index -eq 30){return $script:fixtureRoad};return $script:fixtureEntity}
$r=DiagnoseOneBuilding 12 2
Check ($calls.Count -eq 3 -and @($calls|Where-Object {$_ -notin @('inspect_entity','get_buildings')}).Count -eq 0) 'diagnosis uses at most three read queries'
$count=0
function Session {$script:count++;@{session=if($count -eq 1){'a'}else{'b'};citySession='city'}}
$rejected=$false;try{DiagnoseOneBuilding 12 2|Out-Null}catch{$rejected=$true}
Check $rejected 'mixed-session evidence is rejected'
Write-Output "$n building report checks passed. No game commands sent."
