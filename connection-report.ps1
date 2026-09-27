# Bounded inspection only. A graph path is not a utility-flow certificate.
function CheckUtilityConnection([int]$FromIndex,[int]$FromVersion,[int]$ToIndex,[int]$ToVersion,$ExpectedSession=$null) {
 if($FromIndex -le 0 -or $FromVersion -le 0 -or $ToIndex -le 0 -or $ToVersion -le 0){throw 'Supply both current network node index/version pairs. Building IDs and prefab IDs are not nodes.'}
 if($FromIndex -eq $ToIndex -and $FromVersion -eq $ToVersion){throw 'Choose two different connector nodes; tracing a node to itself proves nothing.'}
 $report=[ordered]@{status='connection_unknown_stop';physicalConnection=$null;supplying='not_verified';continueConstruction=$false;retryOriginal=$false;from=@{index=$FromIndex;version=$FromVersion};to=@{index=$ToIndex;version=$ToVersion};sharedUtilityFamilies=@();pathEdgeCount=0;next='Stop construction and report the missing evidence. Do not drop node IDs, add random depths or lay another parallel pipe.'}
 try {
  $snapshot=Session
  if($ExpectedSession -and ($snapshot.session -ne $ExpectedSession.session -or $snapshot.citySession -ne $ExpectedSession.citySession)){throw 'City/session changed since construction; inspect the saved operation receipt.'}
  $a=Call inspect_entity @{index=$FromIndex;version=$FromVersion}
  $b=Call inspect_entity @{index=$ToIndex;version=$ToVersion}
  foreach($node in @($a,$b)) {
   if(@($node.components) -notcontains 'Game.Net.Node' -or @($node.components) -contains 'Game.Tools.Temp' -or @($node.components) -contains 'Game.Common.Deleted'){throw 'Endpoint is not a live permanent network node.'}
  }
  if($a.index -ne $FromIndex -or $a.version -ne $FromVersion -or $b.index -ne $ToIndex -or $b.version -ne $ToVersion){throw 'Returned node identity does not match the requested endpoint.'}
  $families=@{water='Game.Simulation.WaterPipeNodeConnection';electricity='Game.Simulation.ElectricityNodeConnection'}
  $shared=@(foreach($family in $families.Keys){if(@($a.components) -contains $families[$family] -and @($b.components) -contains $families[$family]){$family}})
  $report.sharedUtilityFamilies=$shared
  $report.from.position=$a.position;$report.to.position=$b.position
  if($shared.Count -eq 0){throw 'No shared utility connector family. Find the actual water/electricity subnodes; do not use a nearby road node.'}
  $path=Call trace_network @{fromIndex=$FromIndex;fromVersion=$FromVersion;toIndex=$ToIndex;toVersion=$ToVersion}
  $after=Session
  if($snapshot.session -ne $after.session -or $snapshot.citySession -ne $after.citySession){throw 'City/session changed; discard mixed observations.'}
  if($path.connected -isnot [bool]){throw 'Network trace did not return a definite result.'}
  if($path.connected){
   if(@($path.edges).Count -eq 0){throw 'Trace claims a path between distinct nodes without any edges.'}
   $report.status='physical_path_found_supply_unverified';$report.physicalConnection=$true;$report.pathEdgeCount=@($path.edges).Count
   $report.next='Do not add another pipe/cable between these nodes. Physical adjacency is verified only. Check voltage/water/sewage layer, source operation and capacity; settle once, then coach building for an affected consumer. Report demand and fulfilled service.'
  }elseif($null -eq $path.visited -or $path.visited -gt 100000){
   throw 'Trace is incomplete or reached its search bound; absence of a path is not established.'
  }else{
   $report.status='disconnected_stop';$report.physicalConnection=$false
   $report.next='No physical path between these connectors. Stop extending the network. Inspect the last createdRoads receipt and exact endpoints with coach inspect. Repair only the verified missing link within authorized scope; no automatic demolition or new route.'
  }
 }catch{$report.error=$_.Exception.Message}
 return $report
}
