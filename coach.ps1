#requires -Version 7.5
[CmdletBinding()]
param(
 [ValidateSet('chirper','building','unlocks','status','brief','zones','nearby','health','outside','doctor','catalog','inspect','sites','connection-plan','building-plan','apply','wait','settle')][string]$Action='doctor',
 [ValidateRange(1,100)][int]$Limit=20, [string]$Filter='', [int]$Index=0, [int]$Version=0,
 [double]$X=0, [double]$Z=0, [int]$Radius=120,
 [int]$FromIndex=0,[int]$FromVersion=0,[int]$ToIndex=0,[int]$ToVersion=0,
 [double]$Elevation=0,[double]$Rotation=0,[int]$MaxCost=0,[int]$Reserve=100000,
 [string]$PlanPath='', [string]$OperationId='', [ValidateSet('operation','batch','simulation')][string]$Kind='operation',
 [string]$MailboxPath=(Join-Path $env:LOCALAPPDATA 'CitiesIIAgentBridge'),
 [string]$RecordPath=(Join-Path $PSScriptRoot 'records'),
 [switch]$All, [switch]$Reassessed, [switch]$LibraryOnly
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'response-guide.ps1')
. (Join-Path $PSScriptRoot 'building-report.ps1')


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
function Session {
 $s=$null
 for($attempt=0;$attempt -lt 4;$attempt++){
  try {$s=Read-MailboxText (Join-Path $MailboxPath 'session.json')|ConvertFrom-Json -DateKind String;break}
  catch {if($attempt -eq 3){throw};Start-Sleep -Milliseconds 75}
 }
 $age=([DateTimeOffset]::UtcNow-[DateTimeOffset]::Parse($s.heartbeatUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal)).TotalSeconds
 if($s.status -ne 'ready' -or $age -gt 10 -or $age -lt -5){throw 'Bridge heartbeat is stale. Do not send or repeat construction. Load the city and check the mod.'}
 return $s
}
function Control {
 $s=Session
 if((Test-Path (Join-Path $MailboxPath 'STOP')) -or !$s.controlEnabled){throw 'Controls are disabled or STOP is latched. Ask the owner to authorize resuming and enable the in-city option. This helper never clears STOP.'}
 return $s
}
function Call([string]$Command,[hashtable]$Data=@{}) {
 $text=& (Join-Path $PSScriptRoot 'bridge-client.ps1') $Command -ArgsJson ($Data|ConvertTo-Json -Depth 30 -Compress) -MailboxPath $MailboxPath
 $r=($text -join "`n")|ConvertFrom-Json -DateKind String
 New-Item -ItemType Directory -Force $RecordPath|Out-Null
 $r|ConvertTo-Json -Depth 60|Set-Content (Join-Path $RecordPath (([guid]::NewGuid().ToString('N'))+'-'+$Command+'.json'))
 if($r.ok -and $null -eq $r.result){throw "result_missing_outcome_unknown_do_not_repeat"}; if(!$r.ok){throw "$Command failed: $($r.error). Do not blindly retry a mutation."}
 return $r.result
}
function Await([string]$Id,[string]$Kind='get_operation',[int]$Seconds=10) {
 $s=Session; $end=[DateTime]::UtcNow.AddSeconds($Seconds);$progressAt=[DateTime]::UtcNow.AddSeconds(5)
 do {
  if((Session).citySession -ne $s.citySession){throw 'City changed while waiting. Outcome unknown; inspect instead of replaying.'}
  $r=Call $Kind @{id=$Id}
  if($r.status -in @('complete','failed','interrupted')){return $r}
  if([DateTime]::UtcNow -ge $progressAt){[Console]::Error.WriteLine("Waiting for $Kind $Id ($($r.status)); do not repeat the original action.");$progressAt=[DateTime]::UtcNow.AddSeconds(5)}
  Start-Sleep -Milliseconds 1000
 } while([DateTime]::UtcNow -lt $end)
 return @{status='pending_do_not_resubmit';id=$Id;next="Poll this same operation ID. Never resend construction: $Id"}
}
function CompactBuilding($b) {
 $roles=@(); $components=@($b.components)
 if($components -contains 'Game.Buildings.ElectricityProducer'){$roles+='electricity_source'}
 if($components -contains 'Game.Buildings.Transformer'){$roles+='transformer_not_generator'}
 if($null -ne $b.waterProducer){$roles+='fresh_water_source'}
 if($null -ne $b.sewageOutlet){$roles+='sewage_processor'}
 if($null -ne $b.waterConsumer){$roles+='water_consumer'}
 [ordered]@{id="$($b.index):$($b.version)";name=$b.prefab;roles=$roles;position=$b.position;road=$b.roadEdge;electricity=$b.electricityConnections;electricityDemand=$b.electricityConsumer;underConstruction=$b.underConstruction;diagnosisStatus=$b.diagnosisStatus;water=$b.waterConnections;waterDemand=$b.waterConsumer;waterProduction=$b.waterProducer;sewageProcessing=$b.sewageOutlet;issues=@($b.issues)}
}
function Diagnose($City,$Buildings,$Diagnostics) {
 $rows=@($Buildings.buildings|Where-Object { @($_.components) -notcontains 'Game.Common.Native' })
 $cards=@($rows|ForEach-Object {CompactBuilding $_})
 $actions=[System.Collections.Generic.List[string]]::new()
 $utility=$Diagnostics.utilitiesRaw
 $partial=($null -eq $Diagnostics.utilitiesRaw -or $Buildings.buildings.Count -ge 512)
 if($partial){$actions.Add('Observation is incomplete. Treat absent assets/capacity as unknown, not proof that none exist.')}
 if(!$partial -and $utility.electricity.capacity -eq 0){$actions.Add('No local electricity capacity reported. Discover an unlocked generator, or inspect a real external power connection; a transformer alone does not generate power.')}
 if($utility.electricity.capacity -gt 0 -and $utility.electricity.production -eq 0){$actions.Add('Electricity capacity exists but reported production is zero. Check demand, generator state and actual network paths; this is not proof of either successful supply or a fault while paused.')}
 if(!$partial -and $utility.water.capacity -eq 0){$actions.Add('No local freshwater capacity reported. Discover an unlocked water source; preview its site and check pollution. A pipe alone cannot produce water. External imports, if any, need separate verification.')}
 if(!$partial -and $utility.sewage.capacity -eq 0){$actions.Add('No local sewage processing capacity reported. Discover an unlocked sewage outlet/treatment facility and preview a suitable site. External export requires separate verification.')}
 $issueRows=@($cards|Where-Object {$_.issues.Count -gt 0})
 if($issueRows.Count){$actions.Add('Inspect the listed affected building and its nearby network. Use real connector/node IDs; visual proximity and road access do not prove utility connectivity.')}
 $actions.Add('After one connection change, run settle once, then doctor. Confirm production/processing and consumer fulfillment; no demand means supply remains unproven.')
 if($City.population -eq 0){$actions.Insert(0,'Population is zero: verify outside road access before adding more utilities or zoning. Use outside with a current city-road node; a camera-radius query cannot check the map boundary.')}
 [ordered]@{city=$City.cityName;money=$City.money;paused=($City.selectedSpeed -eq 0);controlEnabled=$City.controlEnabled;status='inspection_only_supply_not_certified';partial=$partial;utilityTotalsRaw=$utility;persistentShortages=@($Diagnostics.persistentShortages);buildings=$cards;next=$actions.ToArray();notes=@('Uses building-level evidence alongside city diagnostics.','Raw totals are not MW or m3 without a verified conversion. Capacity is not delivery.','A transformer node alone is not evidence of an external power feed.','A disconnected test pipe/road is not a working network. Native map ruins are excluded.')}
}
function Catalog([string]$Text) {
 $p=Call get_build_prefabs @{filter=$Text}
 if($All){return @($p.prefabs|Select-Object index,version,name,kind,locked)}
 @($p.prefabs|Where-Object { $_.kind -in @('building','network') -and $_.name -match 'WaterTower|WaterPumping|GroundwaterPumping|WastewaterTreatment|SewageOutlet|Water Pipe|Sewage Pipe|WindTurbine|PowerStation|PowerPlant|TransformerStation|Electricity Cable|Power Line|Voltage' -and $_.name -notmatch 'Additional|Extra|Advanced|Upgrade' }|Select-Object index,version,name,kind,locked)
}
function ResolvePrefab([string]$Name,[string]$Kind) {
 if(!$Name){throw 'Supply -Filter with an exact name from catalog. Never guess a prefab ID.'}
 $matches=@((Call get_build_prefabs @{filter=$Name}).prefabs|Where-Object {$_.name -eq $Name -and $_.kind -eq $Kind})
 if($matches.Count -ne 1){throw 'Exact prefab name is missing or ambiguous. Run catalog and copy one exact name.'}
 if($matches[0].locked){throw 'Prefab is locked. Choose an unlocked asset; do not override unlocks.'}
 return $matches[0]
}
function WritePlan($p) {
 if(!$PlanPath){throw 'Supply -PlanPath for the proposed plan file.'}
 if(Test-Path -LiteralPath $PlanPath){throw 'Plan file already exists. Use a new filename; never overwrite an attempted plan.'}
 $parent=Split-Path -Parent ([IO.Path]::GetFullPath($PlanPath)); New-Item -ItemType Directory -Force $parent|Out-Null
 $p|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $PlanPath
 return @{status='plan_only_no_construction';path=[IO.Path]::GetFullPath($PlanPath);plan=$p;next='Review the plan and its limits. Apply once only if it fits the owner-authorized scope.'}
}
function BasePlan([string]$Command,$Payload,$Prefab) {
 $s=Session
 if($MaxCost -le 0 -or $Reserve -lt 0){throw 'Supply a positive -MaxCost and nonnegative -Reserve.'}
 [ordered]@{schema=1;id=[guid]::NewGuid().ToString('N');session=$s.session;citySession=$s.citySession;expiresUtc=[DateTimeOffset]::UtcNow.AddMinutes(5).ToString('O');command=$Command;prefabName=$Prefab.name;reserve=$Reserve;args=$Payload}
}
function ValidatePlan($p,$s,$city) {
 if($p.schema -ne 1 -or $p.command -notin @('place_building','build_network')){throw 'Unsupported plan format/command.'}
 if($p.session -ne $s.session -or $p.citySession -ne $s.citySession){throw 'Plan belongs to another city/session. Discover again.'}
 if([DateTimeOffset]::Parse($p.expiresUtc) -le [DateTimeOffset]::UtcNow){throw 'Plan expired. Create a new plan from live state.'}
 if($p.args.maxCost -le 0 -or $p.reserve -lt 0 -or ($city.money-$p.args.maxCost) -lt $p.reserve){throw 'Spending limit/reserve check failed.'}
 if($p.args.allowDemolition){throw 'This helper does not authorize collateral demolition.'}
 if($p.args.moveIndex){throw 'Creation plans cannot relocate existing buildings.'}
 if($p.id -notmatch '^[a-fA-F0-9]{32}$'){throw 'Invalid plan identifier.'}
 if($p.command -eq 'build_network' -and $p.args.elevation -ne 0){throw 'Node-to-node plans must preserve absolute heights with elevation 0.'}
}
function CheckNodes($Prefab,$A,$B) {
 $required=if($Prefab.name -match 'Water|Sewage'){'Game.Simulation.WaterPipeNodeConnection'}elseif($Prefab.name -match 'Electric|Power|Voltage'){'Game.Simulation.ElectricityNodeConnection'}else{throw 'This connection helper only supports recognizable utility pipe/cable prefabs. Inspect other networks manually.'}
 foreach($e in @($A,$B)){
  if(@($e.components) -notcontains 'Game.Net.Node' -or !$e.position){throw 'Endpoints must be current network NODES, not buildings or edges.'}
  if(@($e.components) -notcontains $required){throw "Node $($e.index):$($e.version) does not expose $required. Do not connect to a road/building by proximity. Find the real utility subnode."}
 }
 $length=[Math]::Sqrt([Math]::Pow($A.position.x-$B.position.x,2)+[Math]::Pow($A.position.y-$B.position.y,2)+[Math]::Pow($A.position.z-$B.position.z,2))
 if($length -lt 8 -or $length -gt 1000){throw 'Connection length must be between 8 and 1000 metres. Plan a checked route, not an arbitrary long segment.'}
}
function ApplyPlan {
 $s=Control
 $p=Get-Content -LiteralPath $PlanPath -Raw|ConvertFrom-Json -AsHashtable -DateKind String
 ValidatePlan $p $s (Call get_city_state)
 # An exclusive attempt marker prevents a weaker agent or concurrent helper replaying the same plan.
 $attemptDir=Join-Path $RecordPath 'attempts'; New-Item -ItemType Directory -Force $attemptDir|Out-Null
 $marker=Join-Path $attemptDir ($p.id+'.json')
 $stream=[IO.File]::Open($marker,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 $stream.Dispose()
 $record=@{planId=$p.id;status='started_outcome_unknown';note='Never delete this marker to retry. Inspect saved request/operation IDs.'}
 $record|ConvertTo-Json|Set-Content $marker
 $save=Call save_checkpoint @{label='utility-coach-before'}
 $done=Await $save.id
 if($done.status -ne 'complete'){throw 'Checkpoint did not complete. Plan was not submitted. Inspect the attempt record.'}
 $record.checkpoint=$done.saveName
 ValidatePlan $p (Control) (Call get_city_state)
 $prefab=Call get_prefab_details @{index=$p.args.prefabIndex;version=$p.args.prefabVersion}
 if($prefab.locked -or $prefab.name -ne $p.prefabName){throw 'Prefab identity or unlock changed. No construction submitted.'}
 if($p.command -eq 'build_network'){
  $a=Call inspect_entity @{index=$p.args.start.index;version=$p.args.start.version};$b=Call inspect_entity @{index=$p.args.end.index;version=$p.args.end.version}
  CheckNodes $prefab $a $b
 }
 $op=Call $p.command $p.args
 $record.operationId=$op.id; $record|ConvertTo-Json -Depth 10|Set-Content $marker
 $done=Await $op.id
 $record.status=$done.status;$record.result=$done;$record|ConvertTo-Json -Depth 30|Set-Content $marker
 return @{status=$done.status;operation=$done;checkpoint=$record.checkpoint;next='Run inspect/doctor to verify entities. Then settle once to check actual supply. Complete means native operation completed, not that utilities work.'}
}
if($LibraryOnly){return}
try {
 $result=switch($Action) {
  'chirper' {Call get_chirper @{limit=$Limit}}
  'building' {DiagnoseOneBuilding $Index $Version}
  'unlocks' {Call get_devtree}
  'status' {Call get_status}
  'zones' {Call get_zone_catalog}
  'nearby' {if(!$PSBoundParameters.ContainsKey('X') -or !$PSBoundParameters.ContainsKey('Z')){throw 'Supply -X and -Z from current city observations.'};Call get_nearby_infrastructure @{x=$X;z=$Z}}
  'brief' {
   $s=Session;$t=Call get_tool_status
   if($t.simulationRunning -or $t.batchRunning -or $t.operationId){@{status='pending_do_not_resubmit';tool=$t;next='Poll the original operation or batch. Do not run analysis or repeat construction.'};break}
   $city=Call get_city_state
   if((Session).citySession -ne $s.citySession){throw 'City changed; discard snapshot.'}
   @{city=$city.cityName;population=$city.population;money=$city.money;tool=$t;next=if(!$s.controlEnabled){'Enable authorized controls in Options and close the menu.'}elseif(!$t.readyForConstruction){'Poll the original operation. For a stranded native tool use cancel_tool once, then inspect.'}elseif($city.population -eq 0){'Check zones (usable=true) and outside road access before adding utilities. Read FAST-START.md.'}else{'Choose one issue; doctor gives utility evidence. One change, one settle, then report.'}}
  }
  'health' {
   $exists=Test-Path (Join-Path $MailboxPath 'session.json');$stopped=Test-Path (Join-Path $MailboxPath 'STOP');$s=$null;$problem=$null
   try{$s=Session}catch{$problem=$_.Exception.Message}
   @{ready=($null -ne $s);stopLatched=$stopped;bridgeVersion=$s.modVersion;gameVersion=$s.gameVersion;controls=$s.controlEnabled;problem=$problem;next=if($stopped){'STOP latch is holding the checkbox off. Resume only with owner authorization; never clear it automatically.'}elseif(!$s){'Return from Options to the loaded city. Check game responsiveness and mod loading before sending requests.'}else{'Heartbeat is current. Queued responses still require completion polling.'};compatibility='A ready heartbeat is not build compatibility certification. Installation uses the exact Game.dll fingerprint.'}
  }
  'outside' {
   if($Index -le 0 -or $Version -le 0){throw 'Supply a city-road node -Index and -Version from inspect. Building and prefab IDs are not road nodes.'}
   $s=Session
   if((Call get_capabilities).read -notcontains 'get_outside_connections'){throw 'Whole-map outside-road diagnosis needs the patched mod 0.4.3-coach.1. A camera-radius search cannot establish outside connectivity on this older mod.'}
   Call get_outside_connections @{index=$Index;version=$Version}
  }
  'doctor' {
   $s=Session; $city=Call get_city_state; $buildings=Call get_buildings
   $diag=$null; $diagnosticError=$null
   try{$diag=Call get_city_diagnostics}catch{$diagnosticError=$_.Exception.Message}
   if((Session).citySession -ne $s.citySession){throw 'City changed during inspection. Discard mixed observations.'}
   $r=Diagnose $city $buildings $diag; $r.diagnosticError=$diagnosticError; $r.stopLatched=Test-Path (Join-Path $MailboxPath 'STOP'); $r
  }
  'catalog' { @{assets=@(Catalog $Filter);scope=if($All){'all_prefab_kinds'}else{'utilities_only'};next='For clinics, cemeteries or other services use catalog -All -Filter NAME. An empty utility catalog does not mean a service is absent or locked. Copy current index/version; building, node and development-tree IDs are different.'} }
  'inspect' {
   if($Index -le 0 -or $Version -le 0){throw 'Supply -Index and -Version from current observations.'}
   $entity=Call inspect_entity @{index=$Index;version=$Version}
   $network=$null;$edges=$null
   if($entity.position){$network=Call get_network @{x=$entity.position.x;z=$entity.position.z;radius=$Radius};$edges=Call get_network_edges @{x=$entity.position.x;z=$entity.position.z;radius=$Radius}}
   @{entity=$entity;nearbyNetwork=$network;edges=@($edges.edges|Select-Object index,version,prefab,startNode,endNode,length);next='Match node IDs to the listed edges and utility types. Do not attach a pipe to a building entity ID. The nearest node is not necessarily the right utility layer.'}
  }
  'sites' {
   if(!$PSBoundParameters.ContainsKey('X') -or !$PSBoundParameters.ContainsKey('Z')){throw 'Supply explicit -X and -Z from the loaded city.'}
   $p=ResolvePrefab $Filter 'building'
   @{prefab=$p;details=(Call get_prefab_details @{index=$p.index;version=$p.version});sites=(Call find_building_sites @{prefabIndex=$p.index;prefabVersion=$p.version;x=$X;z=$Z;radius=$Radius});next='Geometric candidates only. Shoreline/source requirements, pollution and native preview still apply.'}
  }
  'connection-plan' {
   $p=ResolvePrefab $Filter 'network'
   $a=Call inspect_entity @{index=$FromIndex;version=$FromVersion}; $b=Call inspect_entity @{index=$ToIndex;version=$ToVersion}
   CheckNodes $p $a $b
   if($FromIndex -eq $ToIndex -and $FromVersion -eq $ToVersion){throw 'Choose two different nodes.'}
   $details=Call get_prefab_details @{index=$p.index;version=$p.version}
   if($Elevation -ne 0){throw 'Existing node endpoints already have absolute heights. This bridge adds elevation after resolving nodes, so a nonzero offset would shift them again. Use -Elevation 0 for node-to-node plans; native validation remains authoritative.'}
   $trace=Call trace_network @{fromIndex=$FromIndex;fromVersion=$FromVersion;toIndex=$ToIndex;toVersion=$ToVersion}
   if($trace.connected){@{status='existing_physical_path_do_not_duplicate';trace=$trace;next='A physical path already exists. Investigate layer, source operation, capacity and consumer readings instead of placing a duplicate segment. This does not prove actual supply.'};break}
   $args=@{prefabIndex=$p.index;prefabVersion=$p.version;start=@{x=$a.position.x;y=$a.position.y;z=$a.position.z;index=$FromIndex;version=$FromVersion};end=@{x=$b.position.x;y=$b.position.y;z=$b.position.z;index=$ToIndex;version=$ToVersion};elevation=$Elevation;maxCost=$MaxCost}
   $plan=BasePlan 'build_network' $args $p
   $plan.endpoints=@($a,$b);$plan.prefabDetails=$details;$plan.warning='Node attachment is proposed, not proven. Existing node heights are preserved with offset 0. Check compatible utility layers, native snapping, and final delivery. This helper cannot infer a suitable external connection.'
   WritePlan $plan
  }
  'building-plan' {
   if(!$PSBoundParameters.ContainsKey('X') -or !$PSBoundParameters.ContainsKey('Z')){throw 'Supply explicit -X and -Z from the loaded city.'}
   $p=ResolvePrefab $Filter 'building'
   $args=@{prefabIndex=$p.index;prefabVersion=$p.version;position=@{x=$X;z=$Z};rotation=$Rotation;maxCost=$MaxCost;allowDemolition=$false}
   $plan=BasePlan 'place_building' $args $p
   $plan.warning='No native preview performed yet. Apply uses native validation. Check sites, terrain/pollution, source access and connection requirements before applying.'
   WritePlan $plan
  }
  'apply' {ApplyPlan}
  'wait' {if(!$OperationId){throw 'Supply the original -OperationId.'};$poll=@{operation='get_operation';batch='get_batch';simulation='get_simulation_step'}[$Kind];Await $OperationId $poll}
  'settle' {
   $null=Control
   $op=Call simulate_step @{frames=512;wallSeconds=5;stallSeconds=3;speed=1;cashFloor=$Reserve;stopOnNewShortage=$true;acknowledgeNoProgress=[bool]$Reassessed}
   $done=Await $op.id 'get_simulation_step' 12
   if($done.status -eq 'pending_do_not_resubmit'){ $cancel=Call cancel_simulation_step; return @{status='review_needed';cancellation=$cancel;operationId=$op.id;next='Inspect pause state; do not run another interval automatically.'} }
   @{status=$done.status;reason=$done.reason;paused=$done.paused;advancedFrames=$done.advancedFrames;delta=$done.delta;next='Run doctor. This short interval may be insufficient; unchanged readings are inconclusive, not proof of success.'}
  }
 }
 if($result -is [System.Collections.IDictionary]){$result['guidance']=Get-AgentGuidance $result.status $result.error $result.id}else{$result|Add-Member -NotePropertyName guidance -NotePropertyValue (Get-AgentGuidance $result.status $result.error $result.id) -Force}
 $result|ConvertTo-Json -Depth 40
} catch {
 @{guidance=(Get-AgentGuidance 'unknown' $_.Exception.Message);status=if($_.Exception.Message -match 'stagnant|reassess_required'){'stagnant_no_progress'}elseif($_.Exception.Message -match 'zone_has_no_growables|use_zoning_for_growables'){'invalid_zone'}elseif($_.Exception.Message -match 'finish_or_cancel|construction_busy|tool_operation'){'tool_busy'}else{'blocked_or_unknown'};error=$_.Exception.Message;next='Fix the stated precondition. If a request may have been sent, inspect its response/operation before doing anything again.'}|ConvertTo-Json -Depth 5
 exit 1
}
