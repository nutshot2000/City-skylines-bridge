# Evidence-only building report. No simulation, construction or automatic retries.
function Get-UtilityReading($Wanted,$Delivered) {
 if($null -eq $Wanted -or $null -eq $Delivered){return @{state='unknown';wanted=$Wanted;delivered=$Delivered}}
 if($Wanted -le 0){return @{state='no_demand_unproven';wanted=$Wanted;delivered=$Delivered}}
 return @{state=if($Delivered -lt $Wanted){'shortfall'}else{'demand_fulfilled_at_snapshot'};wanted=$Wanted;delivered=$Delivered}
}
function Get-BuildingReport($Entity,$Detail,$Road,$RoadError) {
 if(@($Entity.components) -notcontains 'Game.Buildings.Building'){throw 'target_must_be_a_placed_building_not_a_prefab_or_network_node'}
 $unknown=[System.Collections.Generic.List[string]]::new()
 $findings=[System.Collections.Generic.List[string]]::new()
 $b=if($null -ne $Detail){$Detail}else{$Entity}
 if($null -eq $Detail){$unknown.Add('Detailed building row unavailable or outside the response limit; omitted connections/issues are unknown.')}
 $electric=$b.electricityConsumer
 if($null -eq $electric){
  $raw=$b.serviceDataRaw.'Game.Buildings.ElectricityConsumer'
  if($null -ne $raw){$electric=@{wantedConsumption=$raw.m_WantedConsumption;fulfilledConsumption=$raw.m_FulfilledConsumption}}
 }
 $water=$b.waterConsumer
 $readings=[ordered]@{
  electricity=(Get-UtilityReading $electric.wantedConsumption $electric.fulfilledConsumption)
  freshwater=(Get-UtilityReading $water.wantedConsumption $water.fulfilledFresh)
  sewage=(Get-UtilityReading $water.wantedConsumption $water.fulfilledSewage)
 }
 foreach($name in $readings.Keys){
  if($readings[$name].state -eq 'shortfall'){$findings.Add("${name}: delivery below demand in this snapshot.")}
  elseif($readings[$name].state -eq 'unknown'){$unknown.Add("${name}: consumer readings unavailable; this does not imply disconnected.")}
 }
 $roadState='unknown'
 if($null -ne $b.roadEdge){
  if($b.roadEdge.index -eq 0){$roadState='no_road_reference';$findings.Add('No road edge reference reported; access requirements depend on the building type.')}
  elseif($null -ne $Road -and $Road.index -eq $b.roadEdge.index -and $Road.version -eq $b.roadEdge.version -and @($Road.components) -contains 'Game.Net.Edge' -and @($Road.components) -notcontains 'Game.Common.Deleted' -and @($Road.components) -notcontains 'Game.Tools.Temp'){$roadState='live_edge_reference_routing_unverified'}
  else{$unknown.Add('Road reference could not be verified. '+$RoadError)}
 }else{$unknown.Add('Road edge reference unavailable.')}
 $construction=@($Entity.components) -contains 'Game.Objects.UnderConstruction'
 if($construction){$findings.Add('Building is under construction; the completion blocker is unknown.')}
 $issues=@($b.issues|Where-Object {$_})
 foreach($issue in $issues){$findings.Add("Recognised component issue: $issue")}
 $unknown.Add('Visible notification icons, construction progress and source-to-consumer flow are not collected. No-issue results do not certify service.')
 $next=if($findings.Count){'Inspect the reported issue first. Do not add speculative infrastructure. Nearby nodes are candidates, not confirmed connections.'}else{'No recognised shortfall in this snapshot. If the UI disagrees, compare this exact building and its warning before changing the city.'}
 $command=if($null -ne $Entity.position){@{script='coach.ps1';action='inspect';parameters=@{Index=$Entity.index;Version=$Entity.version;Radius=120}}}else{$null}
 [ordered]@{status='inspection_only_supply_not_certified';building=@{index=$Entity.index;version=$Entity.version;name=$Entity.prefab;position=$Entity.position};utilities=$readings;road=@{state=$roadState;edge=$b.roadEdge};underConstruction=$construction;connectionReferences=@{electricity=$b.electricityConnections;water=$b.waterConnections};findings=$findings.ToArray();unknown=$unknown.ToArray();nextAction=$next;nextCommand=$command;note='Read-only observations may pause the game. Fulfillment means this snapshot only; zero demand is unproven. No building changes or simulation were performed.'}
}
function DiagnoseOneBuilding([int]$BuildingIndex,[int]$BuildingVersion) {
 if($BuildingIndex -le 0 -or $BuildingVersion -le 0){throw 'Supply -Index and -Version of a current placed building.'}
 $session=Session
 $entity=Call inspect_entity @{index=$BuildingIndex;version=$BuildingVersion}
 if($entity.index -ne $BuildingIndex -or $entity.version -ne $BuildingVersion){throw 'building_identity_mismatch'}
 if(@($entity.components) -notcontains 'Game.Buildings.Building'){throw 'target_must_be_a_placed_building_not_a_prefab_or_network_node'}
 $detail=$null;$detailError=$null;$road=$null;$roadError=$null
 try {
  $rows=Call get_buildings @{filter=$entity.prefab}
  $detail=@($rows.buildings|Where-Object {$_.index -eq $BuildingIndex -and $_.version -eq $BuildingVersion})|Select-Object -First 1
 }catch{$detailError=$_.Exception.Message}
 if($detail.roadEdge.index -gt 0){
  try{$road=Call inspect_entity @{index=$detail.roadEdge.index;version=$detail.roadEdge.version}}catch{$roadError=$_.Exception.Message}
 }
 $after=Session
 if($after.session -ne $session.session -or $after.citySession -ne $session.citySession){throw 'City/session changed during diagnosis; discard mixed evidence.'}
 $report=Get-BuildingReport $entity $detail $road $roadError
 if($detailError){$report.unknown+=('Detailed lookup failed: '+$detailError)}
 $report['session']=$session.session;$report['citySession']=$session.citySession
 return $report
}
