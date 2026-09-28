#requires -Version 7.5
<#
 city.ps1 - the EASY front door to the Cities II Agent Bridge.

 One verb per call, short human-readable output, names instead of raw IDs, and the
 game clock is restored after every call (bridge reads pause the city; this puts it back).

   pwsh -NoProfile -File ./city.ps1 help            # list verbs
   pwsh -NoProfile -File ./city.ps1 help zone       # details + examples for one verb

 Add -Json to any verb for the raw structured result instead of text.
 Everything is also saved under records/ exactly like agent.ps1.
#>
[CmdletBinding(PositionalBinding=$false)]
param(
 [Parameter(Position=0)][string]$Verb='help',
 [Parameter(Position=1,ValueFromRemainingArguments)][string[]]$Rest=@(),
 [string]$Name='', [string]$Type='', [string]$Id='',
 [string]$At='', [string]$From='', [string]$To='', [string[]]$Path=@(),
 [double]$X=[double]::NaN, [double]$Z=[double]::NaN, [double]$Radius=[double]::NaN,
 [double]$Rotation=[double]::NaN, [int]$MaxCost=0, [int]$Reserve=50000,
 [int]$Seconds=60, [int]$Rate=-999, [int]$Speed=2, [int]$Limit=40, [double]$Step=100,
 [string]$Region='', [string]$Filter='', [string]$ArgsJson='{}',
 [switch]$Preview, [switch]$AllowWater, [switch]$AllowHighway, [switch]$All, [switch]$Problems, [switch]$Json, [switch]$KeepPaused, [switch]$LibraryOnly
)
$ErrorActionPreference='Stop'
$Kit=$PSScriptRoot
$Agent=Join-Path $Kit 'agent.ps1'
$Mailbox=Join-Path $env:LOCALAPPDATA 'CitiesIIAgentBridge'

# Commands the mod answers WITHOUT pausing the city (see Mod.cs Dispatch statusOnly list).
$NonPausing=@('get_chirper','get_devtree','get_status','get_tool_status','ping','get_capabilities','get_operation','get_batch','get_simulation_step','set_simulation_speed','set_camera','simulate_step','cancel_simulation_step')
$script:PausedByUs=$false

# ---------------------------------------------------------------- bridge access
function Bridge([string]$Command,$Arguments=@{},[int]$Wait=60) {
 if($Command -notin $NonPausing){$script:PausedByUs=$true}
 $json=if($Arguments -is [string]){$Arguments}else{$Arguments|ConvertTo-Json -Depth 30 -Compress}
 $raw=& $Agent -Command $Command -ArgsJson $json -WaitSeconds ([Math]::Min(60,$Wait)) 2>$null
 $r=($raw -join "`n")|ConvertFrom-Json -DateKind String
 if($r.status -eq 'pending_do_not_resubmit'){throw "STILL RUNNING: $Command is not finished. Do NOT resend it. Check later with: city.ps1 raw get_operation -ArgsJson '{`"id`":`"$($r.operationId)`"}'"}
 if($r.error){throw (Explain $Command $r.error)}
 if($r.status -in @('failed','interrupted')){throw (Explain $Command ($r.result.error ?? $r.status) $r.result)}
 return $r.result
}
function Explain([string]$Command,[string]$Err,$Result=$null) {
 $hint=switch -regex ($Err) {
  'control_disabled' {'Bridge controls are OFF. The player must tick Options > Cities II Agent Bridge > Allow local bridge controls (it resets on every city load).';break}
  'heartbeat is stale' {'The game is not answering: it is in a menu, loading, or closed. Ask the player to return to the city view.';break}
  'finish_or_cancel_current_tool' {'The player (or an earlier command) has a build tool open. Run: city.ps1 raw cancel_tool';break}
  'road_length_must_be_8_to_1000' {'Each road leg must be 8-1000 m. city.ps1 road splits long legs automatically; check for duplicate points.';break}
  'prefab_stale_or_locked' {'That asset is locked (needs a milestone or development point) or the ID is stale. Use: city.ps1 find <name>';break}
  'zone_has_no_growables' {'That zone type has no buildings for this map theme. Use: city.ps1 zones';break}
  'start_requires_zone_block' {'Zoning needs a road nearby: zone cells only exist within ~48 m of a road.';break}
  'no_zone_cells_in_rectangle' {'The rectangle contains no zone cells. Zone cells only exist along roads.';break}
  'game_rejected_placement' {'The game refused this spot. Reasons: ' + ((@($Result.placementErrors.nativeReasons.type)|Sort-Object -Unique) -join ', ') + '. OverlapExisting = hits a road/building; InWater = too far into water; move a few metres or let place pick a site.';break}
  'batch_step_failed' { $i=[int]$Result.failureIndex; $s=@($Result.results)[$i]; $why=((@($s.placementErrors.nativeReasons.type)|Where-Object {$_}|Sort-Object -Unique) -join ', '); "Segment $($i+1) failed: $($s.error)$(if($why){" ($why)"}). Earlier segments WERE built - do not resend them.$(if($s.error -match 'budget|cost'){' Not enough money above the -Reserve cash floor (default 50000): wait for income or pass a lower -Reserve.'}elseif($why -match 'Overlap'){' OverlapExisting on a road usually means it crosses another road at a different height (bridge) or a building.'})";break}
  'budget|insufficient|money' {'Not enough money or maxCost too low. Raise -MaxCost or check city.ps1 status.';break}
  'batch_in_progress' {'A batch is still running. Wait, then run city.ps1 status.';break}
  'no_loaded_city' {'No city is loaded. Ask the player to load a save.';break}
  default {''}
 }
 $msg="$Command failed: $Err"; if($hint){$msg+="`n  HINT: $hint"}; return $msg
}
function Status { (Bridge get_status).city }
function ParsePoint([string]$Text,[string]$Label='point') {
 if($Text -notmatch '^\s*(-?\d+(\.\d+)?)\s*[, ]\s*(-?\d+(\.\d+)?)\s*$'){throw "$Label must look like `"x,z`" (world metres), got '$Text'"}
 return [ordered]@{x=[double]$Matches[1];z=[double]$Matches[3]}
}
function Center {
 if(![double]::IsNaN($X) -and ![double]::IsNaN($Z)){return [ordered]@{x=$X;z=$Z}}
 if($At){return ParsePoint $At '-At'}
 $cam=Bridge get_camera; return [ordered]@{x=[Math]::Round($cam.pivot.x);z=[Math]::Round($cam.pivot.z)}
}
function OwnedBoxes {
 if($null -ne $script:OwnedCache){return $script:OwnedCache}
 $script:OwnedCache=@((Bridge get_tiles).tiles|Where-Object purchased|ForEach-Object {
  $px=@($_.polygon.x);$pz=@($_.polygon.z)
  [pscustomobject]@{x0=($px|Measure-Object -Minimum).Minimum;x1=($px|Measure-Object -Maximum).Maximum;z0=($pz|Measure-Object -Minimum).Minimum;z1=($pz|Measure-Object -Maximum).Maximum} })
 return $script:OwnedCache
}
function DistToLand($Pos){ $own=@(OwnedBoxes); if(!$own.Count){return 0.0}; ($own|ForEach-Object {[Math]::Sqrt([Math]::Pow([Math]::Max(0.0,[double][Math]::Max([double]($_.x0-$Pos.x),[double]($Pos.x-$_.x1))),2)+[Math]::Pow([Math]::Max(0.0,[double][Math]::Max([double]($_.z0-$Pos.z),[double]($Pos.z-$_.z1))),2))}|Measure-Object -Minimum).Minimum }function InOwned($p,$boxes){ foreach($b in $boxes){ if($p.x -ge $b.x0 -and $p.x -le $b.x1 -and $p.z -ge $b.z0 -and $p.z -le $b.z1){return $true} }; return $false }
function Dist($a,$b){[Math]::Sqrt(([double]$a.x-[double]$b.x)*([double]$a.x-[double]$b.x)+([double]$a.z-[double]$b.z)*([double]$a.z-[double]$b.z))}
function Out-Result($Object,[scriptblock]$Text) { if($Json){$Object|ConvertTo-Json -Depth 30}else{& $Text} }

# Pure geometry helpers (unit-tested by test-city.ps1).
# A road path becomes straight legs of at most 900 m (the bridge limit is 1000 m per leg).
function Split-Legs($Points) {
 $legs=@()
 for($i=0;$i -lt $Points.Count-1;$i++){
  $a=$Points[$i];$b=$Points[$i+1];$len=Dist $a $b
  if($len -lt 8){throw "Leg $($i+1) is only $([Math]::Round($len,1)) m; legs must be at least 8 m."}
  $n=[Math]::Ceiling($len/900)
  for($k=0;$k -lt $n;$k++){
   $legs+=[pscustomobject]@{start=[ordered]@{x=[Math]::Round($a.x+($b.x-$a.x)*$k/$n,2);z=[Math]::Round($a.z+($b.z-$a.z)*$k/$n,2)};end=[ordered]@{x=[Math]::Round($a.x+($b.x-$a.x)*($k+1)/$n,2);z=[Math]::Round($a.z+($b.z-$a.z)*($k+1)/$n,2)}}
  }
 }
 if($legs.Count -gt 64){throw 'Too many segments in one call (max 64). Split the path.'}
 return $legs
}
# A zoning rectangle becomes tiles of at most 340 m a side (native marquee: 500 m diagonal).
function Zone-Tiles($A,$B) {
 $w=[Math]::Abs($B.x-$A.x); $h=[Math]::Abs($B.z-$A.z)
 $nx=[Math]::Max(1,[Math]::Ceiling($w/340)); $nz=[Math]::Max(1,[Math]::Ceiling($h/340))
 $x0=[Math]::Min($A.x,$B.x); $z0=[Math]::Min($A.z,$B.z)
 for($i=0;$i -lt $nx;$i++){ for($k=0;$k -lt $nz;$k++){
  [pscustomobject]@{a=[ordered]@{x=$x0+$w*$i/$nx;z=$z0+$h*$k/$nz};b=[ordered]@{x=$x0+$w*($i+1)/$nx;z=$z0+$h*($k+1)/$nz}}
 }}
}
# ---------------------------------------------------------------- name -> prefab
$RoadAliases=@{small='Small Road';medium='Medium Road';large='Large Road';gravel='Gravel Road';oneway='Small Road Oneway';highway='Highway';
 'small-parking'='Small Road - Double Sided Parking';'medium-divided'='Medium Road Divided';'large-divided'='Large Road Divided';
 'power'='Low-voltage Ground Cable';'hv-power'='High-voltage Ground Cable';'water'='Small Water Pipe';'sewage'='Small Sewage Pipe'}
function Prefabs([string]$Text){ @((Bridge get_build_prefabs @{filter=$Text}).prefabs) }
function Resolve-Prefab([string]$Text,[string]$Kind) {
 if(!$Text){throw "Give a name, e.g. -Name 'WindTurbine01'. Search with: city.ps1 find wind"}
 if($Text -match '^(\d+)(v(\d+))?$'){return [pscustomobject]@{index=[int]$Matches[1];version=[int]($Matches[3] ?? 1);name="#$Text";kind=$Kind;locked=$false}}
 $all=Prefabs $Text|Where-Object {!$Kind -or $_.kind -eq $Kind}
 $exact=@($all|Where-Object {$_.name -eq $Text})
 $pick=if($exact.Count){$exact}else{@($all)}
 $unlocked=@($pick|Where-Object {!$_.locked})
 if($unlocked.Count -ge 1 -and ($exact.Count -or $unlocked.Count -eq 1)){return $unlocked[0]}
 if($pick.Count -eq 0){throw "No $Kind asset matches '$Text'. Search with: city.ps1 find $Text"}
 if($unlocked.Count -eq 0){throw "'$Text' matches only LOCKED assets: $((@($pick|Select-Object -First 5).name) -join ', '). Unlock via milestones / city.ps1 unlocks."}
 throw "'$Text' is ambiguous. Use one exact name: $((@($unlocked|Select-Object -First 12).name) -join ' | ')"
}
function Resolve-Road([string]$Text){ $n=if($RoadAliases.ContainsKey($Text.ToLower())){$RoadAliases[$Text.ToLower()]}else{$Text}; Resolve-Prefab $n 'network' }

$ZoneAliases=[ordered]@{
 residential='{R} Residential Low'; 'residential-low'='{R} Residential Low'; houses='{R} Residential Low'
 'residential-row'='{R} Residential Medium Row'; 'residential-medium'='{R} Residential Medium'; 'residential-high'='{R} Residential High'
 'residential-mixed'='{R} Residential Mixed'; mixed='{R} Residential Mixed'; 'residential-lowrent'='Residential LowRent'
 commercial='{R} Commercial Low'; shops='{R} Commercial Low'; 'commercial-low'='{R} Commercial Low'; 'commercial-high'='{R} Commercial High'
 industrial='Industrial Manufacturing'; industry='Industrial Manufacturing'; office='Office Low'; 'office-low'='Office Low'; 'office-high'='Office High'
 agriculture='Industrial Agriculture'; forestry='Industrial Forestry'; ore='Industrial Ore'; oil='Industrial Oil'
}
function Resolve-Zone([string]$Text) {
 $catalog=@((Bridge get_zone_catalog).zones)
 $regions=if($Region){@($Region.ToUpper())}else{@('NA','EU','')}
 $key=$Text.ToLower()
 $candidates=if($ZoneAliases.Contains($key)){ $regions|ForEach-Object { ($ZoneAliases[$key] -replace '\{R\}',$_).Trim() } }else{@($Text)}
 foreach($c in $candidates){ $z=@($catalog|Where-Object {$_.name -eq $c}); if($z.Count -and $z[0].usable){return $z[0]} }
 $near=@($catalog|Where-Object {$_.name -in $candidates})
 if($near.Count){throw "Zone '$($near[0].name)' is not usable yet (locked=$($near[0].locked), growables=$($near[0].matchingGrowables)). See: city.ps1 zones"}
 throw "Unknown zone '$Text'. Use a word like residential, commercial, industrial, office, residential-row, or an exact name from: city.ps1 zones"
}

# ---------------------------------------------------------------- verbs
$Help=[ordered]@{
 help      = "help [verb]  - this list, or details for one verb."
 status    = "status  - money, population, date, speed, tool state. Never pauses the game."
 overview  = "overview  - one-screen city report: demand, budget, utilities, shortages, problems, what to do next."
 speed     = "speed <0|1|2|4>  - set game speed (0 = pause)."
 grow      = "grow [-Seconds 60] [-Speed 2]  - let the city run, then report population/money change."
 find      = "find <text> [-All]  - search buildable assets by name (shows index, kind, locked). -All includes locked."
 zones     = "zones  - zone types you can paint right now."
 map       = "map [-At x,z] [-Radius 600] [-Step 100]  - ASCII terrain: # land, ~ shallow water, W deep water, R road."
 roads     = "roads [-At x,z] [-Radius 400]  - roads near a point: id, type, endpoints."
 road      = "road -Path 'x,z' 'x,z' ... [-Type small|medium|large|<exact name>]  - build a road through the points (long legs auto-split)."
 upgrade   = "upgrade -Path 'x,z' ... -Type large  - upgrade the road segment nearest each point (e.g. a jammed road to Large Road)."
 link      = "link -From index:version -To index:version [-Type hv|lv|water|sewage]  - wire a power plant's high-voltage output to a TransformerStation01 (roads only carry low voltage)."
 zone      = "zone -Type residential|commercial|industrial|office|... -From x,z -To x,z [-Preview] [-Region NA|EU]  - paint zoning in a rectangle along roads."
 place     = "place -Name <asset> -At x,z [-Rotation deg] [-Radius 150]  - place a service/utility building. Without -Rotation it tries road-side sites near -At until the game accepts one. Refuses if it would leave less than -Reserve money (default 50000)."
 problems  = "problems [-At x,z -Radius 500] [-Filter Traffic]  - the warning icons flashing in-game (traffic jams, no water, no workers...) with locations and fixes (DLL 0.5.0+)."
 buildings = "buildings [-Filter text] [-Problems] [-At x,z -Radius 300]  - list your buildings (id, name, position, issues)."
 inspect   = "inspect -Id index:version  - details of one building/road/node."
 demolish  = "demolish -Id index:version  - bulldoze one building or road segment you own."
 unlocks   = "unlocks [-Type Electricity] [-Filter NodeName]  - development points; nodes you can buy now, one tree branch, or the prerequisite chain of a node."
 buy       = "buy <NodeName|index:version>  - spend development points on one tree node (see unlocks)."
 milestones= "milestones  - XP progress and what the next milestones unlock (DLL 0.5.0+)."
 land      = "land  - map tiles you can buy next to your city, with direction and how much is water."
 buyland   = "buyland -At x,z [-MaxCost n]  - buy the map tile containing that point."
 budget    = "budget  - taxes, income and expenses by source."
 tax       = "tax -Type Residential|Commercial|Industrial|Office -Rate n  - set a tax rate (-10..30)."
 chirper   = "chirper [-Limit 20]  - latest citizen posts (clues, not facts)."
 save      = "save [-Name label]  - save a checkpoint (letters, digits, - and _ only)."
 raw       = "raw <command> [-ArgsJson '{...}']  - send any bridge command (see COMMAND-REFERENCE.md)."
}
$Examples=@{
 road = @(
  "city.ps1 road -Path '473,1643' '473,2120' -Type small          # straight road",
  "city.ps1 road -Path '0,1000' '0,1500' '400,1500' -Type medium   # L-shape, two legs",
  'Endpoints within a few metres of an existing road join it automatically. Leave ~100 m between parallel streets so both sides get full-depth lots.')
 zone = @(
  "city.ps1 zone -Type residential -From 280,1395 -To 400,1692 -Preview",
  "city.ps1 zone -Type commercial  -From 408,1346 -To 540,1692",
  'Zone cells only exist up to ~48 m (6 cells) either side of a road, so build roads first. The rectangle covers every road-side cell inside it.',
  'Homes/shops/factories then grow by themselves while the game runs. Never place growable buildings manually.')
 place = @(
  "city.ps1 place -Name WindTurbine01 -At 470,1950",
  "city.ps1 place -Name SewageOutlet01 -At 515,2140 -Rotation 180     # exact spot",
  'Roads already carry electricity, water and sewage. A source placed beside a road that connects to your streets supplies every building on that road network - no pipes or cables needed for road-side buildings.',
  'Sewage outlets and water pumps must touch a shoreline; groundwater towers need groundwater. Keep sewage downstream/away from water intakes.')
 grow = @('city.ps1 grow -Seconds 90 -Speed 4','The game keeps running after this finishes (it is not paused).')
 overview = @('Read NEXT at the bottom: it lists the most useful actions for the current city.')
}

function Do-Help {
 $v=$Rest|Select-Object -First 1
 if($v -and $Help.Contains($v)){ "city.ps1 $($Help[$v])"; if($Examples[$v]){''; $Examples[$v]|ForEach-Object {"  $_"}}; return }
 'city.ps1 - easy commands for Cities: Skylines II. Coordinates are world metres "x,z" (y is height, ignored).'
 'The game clock is restored after each call. Add -Json for machine output.'
 ''
 foreach($k in $Help.Keys){ "  $($Help[$k])" }
 ''
 'Typical start: status -> map -> roads -> road -> zone -> place (power, water, sewage) -> grow -> overview'
}

function Do-Status {
 $s=Bridge get_status; $c=$s.city; $t=$s.tool
 Out-Result $s {
  "$($c.cityName): population $($c.population) (+$([int]$c.populationWithMoveIn-[int]$c.population) moving in), money $([Math]::Round($c.money)), XP $($c.xp), date $($c.date), speed $($c.selectedSpeed)"
  $hb=try{Get-Content (Join-Path $Mailbox 'session.json') -Raw|ConvertFrom-Json}catch{$null}
  "happiness $($c.averageHappiness)  health $($c.averageHealth)  bridge $($hb.modVersion)  controls=$(if($c.controlEnabled){'ON'}else{'OFF (enable in Options)'})$(if($c.stopLatched){'  STOP FILE PRESENT'})"
  if($c.pause.popupHoldingPause){"PAUSED BY A GAME POPUP (usually a milestone/unlock). A player must close it; speed changes snap back to 0 until then."}elseif($c.pause.gameWindowFocused -eq $false -and [double]$c.selectedSpeed -eq 0){"paused - the game window is not focused"}
  if($s.milestone.nextMilestone){"milestone $($s.milestone.achievedMilestone) reached; XP $($s.milestone.currentXP)/$($s.milestone.nextMilestoneXP) toward milestone $($s.milestone.nextMilestone)"}
  "tool: $($t.activeTool)$(if($t.operationId){" operation $($t.operationId)"})$(if($t.batchRunning){' batch running'})  readyForConstruction=$($t.readyForConstruction)"
 }
}

function Do-Speed {
 $v=[int]($Rest|Select-Object -First 1); if($v -notin 0,1,2,4){throw 'speed must be 0, 1, 2 or 4'}
 $r=Bridge set_simulation_speed @{speed=$v}; $script:KeepPaused=$true
 Out-Result $r {"speed $($r.previousSpeed) -> $($r.selectedSpeed)"}
}

function Do-Grow {
 $before=Status; $r=Bridge set_simulation_speed @{speed=$Speed}
 $end=[DateTime]::UtcNow.AddSeconds([Math]::Max(5,[Math]::Min(600,$Seconds)))
 $held=$null; $nudged=$false
 while([DateTime]::UtcNow -lt $end){
  Start-Sleep -Seconds ([Math]::Min(15,[Math]::Max(1,($end-[DateTime]::UtcNow).TotalSeconds)))
  $now=Status
  if([double]$now.selectedSpeed -eq 0){
   # Something paused the game: usually a milestone/unlock popup (a UI pause barrier) or the player.
   if(!$nudged){ $nudged=$true; $null=Bridge set_simulation_speed @{speed=$Speed}; Start-Sleep -Seconds 3; if([double](Status).selectedSpeed -gt 0){continue} }
   $held=$now; break
  }
 }
 $after=Status; $script:KeepPaused=$true
 $o=[ordered]@{before=$before;after=$after}
 Out-Result $o {
  if($held){"STOPPED EARLY: the game keeps pausing itself$(if($held.pause.popupHoldingPause){' - a game popup (usually a milestone or unlock) is open'}elseif($held.pause.gameWindowFocused -eq $false){' - the game window lost focus'}). A player must close the popup / return to the game; speed changes snap back to 0 until then. Nothing else is wrong."}
  else{"ran $Seconds s at speed $Speed  ($($before.date) -> $($after.date)); game is still running."}
  "population $($before.population) -> $($after.population)   moving in: $($after.populationWithMoveIn)"
  "money      $([Math]::Round($before.money)) -> $([Math]::Round($after.money))  ($([Math]::Round($after.money-$before.money)))"
 }
}

function Do-Find {
 $t=($Rest -join ' ').Trim(); if(!$t -and $Name){$t=$Name}; if(!$t){throw 'find <text>, e.g. city.ps1 find water'}
 $rows=@(Prefabs $t|Where-Object {$All -or !$_.locked}|Sort-Object kind,name)
 Out-Result $rows {
  if(!$rows.Count){"nothing unlocked matches '$t' (try -All to include locked)"; return}
  $rows|Select-Object -First $Limit|ForEach-Object {"{0,-9} {1,-9} {2}{3}" -f "$($_.index)v$($_.version)",$_.kind,$_.name,$(if($_.locked){'  [LOCKED]'})}
  if($rows.Count -gt $Limit){"... $($rows.Count-$Limit) more (use -Limit)"}
 }
}

function Do-Zones {
 $z=@((Bridge get_zone_catalog).zones)
 Out-Result $z {
  'usable now (paint with: city.ps1 zone -Type "<name>" ...):'
  $z|Where-Object usable|Sort-Object name|ForEach-Object {"  {0,-38} {1,4} building styles" -f $_.name,$_.matchingGrowables}
  "locked/unusable: $((@($z|Where-Object {!$_.usable}).name|Sort-Object) -join ', ')"
 }
}

function Do-Roads {
 $c=Center; $rad=if([double]::IsNaN($Radius)){400}else{$Radius}
 $e=@((Bridge get_network_edges @{x=$c.x;z=$c.z;radius=$rad}).edges|Where-Object {$_.prefab -notmatch 'Pipe|Cable|Voltage|Line'})
 Out-Result $e {
  "$($e.Count) road segments within $rad m of ($($c.x),$($c.z)):"
  $e|Sort-Object prefab,{$_.start.z},{$_.start.x}|Select-Object -First $Limit|ForEach-Object {
   "  {0,-10} {1,-26} ({2,6:N0},{3,6:N0}) -> ({4,6:N0},{5,6:N0})  {6:N0} m" -f "$($_.index):$($_.version)",$_.prefab,$_.start.x,$_.start.z,$_.end.x,$_.end.z,$_.length }
  if($e.Count -gt $Limit){"  ... $($e.Count-$Limit) more (use -Limit)"}
 }
}

function Do-Map {
 $c=Center; $rad=if([double]::IsNaN($Radius)){600}else{$Radius}
 $step=[Math]::Max(10,$Step); $cells=[Math]::Floor(2*$rad/$step+1); if($cells*$cells -gt 1024){$step=[Math]::Ceiling(2*$rad/31)}; $xs=@(); $zs=@()
 for($v=$c.x-$rad;$v -le $c.x+$rad+0.01;$v+=$step){$xs+=[Math]::Round($v)}
 for($v=$c.z+$rad;$v -ge $c.z-$rad-0.01;$v-=$step){$zs+=[Math]::Round($v)}
 if($xs.Count*$zs.Count -gt 1024){throw "Map too big; use a smaller -Radius."}
 $pts=foreach($zz in $zs){foreach($xx in $xs){@{x=$xx;z=$zz}}}
 $samples=@((Bridge sample_terrain @{points=@($pts)}).samples)
 $edges=@((Bridge get_network_edges @{x=$c.x;z=$c.z;radius=[Math]::Min(2000,$rad*1.5)}).edges|Where-Object {$_.prefab -notmatch 'Pipe|Cable|Voltage|Line'})
 $owned=@((Bridge get_tiles).tiles|Where-Object purchased)
 $rows=@(); $i=0
 foreach($zz in $zs){
  $line=''
  foreach($xx in $xs){
   $s=$samples[$i]; $i++
   $ch=if($s.waterDepth -ge 2){'W'}elseif($s.waterDepth -gt 0.05){'~'}else{'#'}
   foreach($ed in $edges){ # road within half a cell of the segment
    $ax=$ed.start.x;$az=$ed.start.z;$bx=$ed.end.x;$bz=$ed.end.z;$dx=$bx-$ax;$dz=$bz-$az;$l2=$dx*$dx+$dz*$dz
    $t=if($l2 -gt 0){[Math]::Max(0.0,[Math]::Min(1.0,[double]((($xx-$ax)*$dx+($zz-$az)*$dz)/$l2)))}else{0.0}
    if([Math]::Sqrt([Math]::Pow($xx-($ax+$t*$dx),2)+[Math]::Pow($zz-($az+$t*$dz),2)) -le $step/2){$ch=if($ed.prefab -match 'Highway'){'H'}else{'R'};break}
   }
   $inside=$false; foreach($tile in $owned){$px=@($tile.polygon.x);$pz=@($tile.polygon.z); if($xx -ge ($px|Measure-Object -Minimum).Minimum -and $xx -le ($px|Measure-Object -Maximum).Maximum -and $zz -ge ($pz|Measure-Object -Minimum).Minimum -and $zz -le ($pz|Measure-Object -Maximum).Maximum){$inside=$true;break}}
   if(!$inside -and $ch -eq '#'){$ch='.'}
   $line+=$ch
  }
  $rows+=("z={0,6} {1}" -f $zz,$line)
 }
 $heights=@($samples|Where-Object {$_.waterDepth -le 0.05}|ForEach-Object {$_.position.y})
 Out-Result ([ordered]@{x=$xs;z=$zs;rows=$rows}) {
  "map centre ($($c.x),$($c.z)) radius $rad step $step. North (+z) is up, east (+x) is right."
  "x: $($xs[0]) .. $($xs[-1])"
  $rows
  "legend: # your buildable land   . land you don't own   ~ shallow water   W deep water   R road   H highway"
  if($heights.Count){"land height $([Math]::Round(($heights|Measure-Object -Minimum).Minimum))..$([Math]::Round(($heights|Measure-Object -Maximum).Maximum)) m"}
 }
}

function Do-Road {
 $pts=@($Path+$Rest|Where-Object {$_}|ForEach-Object {ParsePoint $_ 'point'})
 if($From -and $To){$pts=@((ParsePoint $From '-From'),(ParsePoint $To '-To'))}
 if($pts.Count -lt 2){throw "Give at least two points: city.ps1 road -Path '0,1000' '0,1400' -Type small"}
 $p=Resolve-Road $(if($Type){$Type}elseif($Name){$Name}else{'small'})
 # Crossing a highway at grade puts a junction (and a stop) on it and jams it; refuse unless asked.
 if(!$AllowHighway){
  foreach($leg in Split-Legs $pts){
   $mid=@{x=($leg.start.x+$leg.end.x)/2;z=($leg.start.z+$leg.end.z)/2}
   $hw=@((Bridge get_network_edges @{x=$mid.x;z=$mid.z;radius=[Math]::Min(2000,(Dist $leg.start $leg.end)/2+50)}).edges|Where-Object {$_.prefab -match 'Highway'})
   foreach($h in $hw){ if(SegCross $leg.start $leg.end $h.start $h.end){ throw "This road would cross the highway at ($([Math]::Round(($h.start.x+$h.end.x)/2)),$([Math]::Round(($h.start.z+$h.end.z)/2))). The game joins it at grade, which stops highway traffic and jams it. End the road before the highway (a T onto one carriageway is OK), or pass -AllowHighway." } }
  }
 } # Roads over water become costly bridges/quays; stop unless the caller really wants that.
 if(!$AllowWater){
  $probe=@(); foreach($leg in Split-Legs $pts){ $n=[Math]::Max(2,[Math]::Ceiling((Dist $leg.start $leg.end)/25)); for($k=0;$k -le $n;$k++){ $probe+=@{x=$leg.start.x+($leg.end.x-$leg.start.x)*$k/$n;z=$leg.start.z+($leg.end.z-$leg.start.z)*$k/$n} } }
  $wet=@((Bridge sample_terrain @{points=@($probe|Select-Object -First 1024)}).samples|Where-Object {$_.waterDepth -gt 0.5})
  if($wet.Count){ $w=$wet[0]; throw "This road would cross water (e.g. $([Math]::Round($wet.Count*25)) m of it; $([Math]::Round($w.waterDepth,1)) m deep at ($([Math]::Round($w.position.x)),$([Math]::Round($w.position.z)))). The game would build a costly bridge. Shorten it (city.ps1 map shows water as ~/W), or add -AllowWater if you really want a bridge." }
 }
 $steps=@(Split-Legs $pts|ForEach-Object {@{command='build_road';args=@{prefabIndex=$p.index;prefabVersion=$p.version;maxCost=$(if($MaxCost){$MaxCost}else{200000});start=$_.start;end=$_.end}}})
 $r=Bridge batch_execute @{reserve=$Reserve;steps=$steps} 60
 Out-Result $r {
  "$($p.name): $($r.completed)/$($r.steps) segments built, cost $($r.moneySpent)."
  if($r.status -ne 'complete'){"FAILED at segment $([int]$r.failureIndex+1): $($r.error). Segments before it WERE built; do not resend them."}
  'Zone along it with: city.ps1 zone -Type residential -From x,z -To x,z'
 }
}

function Do-Upgrade {
 $pts=@($Path+$Rest+$(if($At){$At})|Where-Object {$_}|ForEach-Object {ParsePoint $_ 'point'})
 if(!$pts.Count){throw "upgrade -Path 'x,z' ['x,z' ...] -Type large   (one point on each road segment to upgrade)"}
 $p=Resolve-Road $(if($Type){$Type}elseif($Name){$Name}else{throw 'upgrade needs -Type, e.g. -Type large'})
 $done=@(); $out=@()
 foreach($pt in $pts){
  $edges=@((Bridge get_network_edges @{x=$pt.x;z=$pt.z;radius=80}).edges|Where-Object {$_.prefab -notmatch 'Pipe|Cable|Voltage|Line|Highway'})
  $best=$null;$bd=[double]::MaxValue
  foreach($e in $edges){ $d=SegDist $pt $e.start $e.end; if($d -lt $bd){$bd=$d;$best=$e} }
  if(!$best -or $bd -gt 30){$out+="  ($($pt.x),$($pt.z)): no road within 30 m"; continue}
  $key="$($best.index):$($best.version)"; if($done -contains $key){continue}; $done+=$key
  if($best.prefab -eq $p.name){$out+="  ($($pt.x),$($pt.z)): already $($p.name)"; continue}
  try { $r=Bridge upgrade_network @{index=$best.index;version=$best.version;prefabIndex=$p.index;prefabVersion=$p.version;maxCost=$(if($MaxCost){$MaxCost}else{200000})} 60
        $out+="  ($($pt.x),$($pt.z)): $($best.prefab) -> $($p.name) $(if($r.previewCost){"cost $($r.previewCost)"})" }
  catch { $m=$_.Exception.Message; $why=if($m -match 'Reasons: ([^.]*)\.'){" ($($Matches[1]))"}else{''}; $out+="  ($($pt.x),$($pt.z)): FAILED $(($m -split "`n")[0] -replace '^upgrade_network failed: ','')$why$(if($why -match 'Overlap'){' - a wider road would hit a building beside it'})" }
 }
 Out-Result $out { "upgrade to $($p.name):"; $out }
}
function SegCross($a,$b,$c,$d){ $o={param($p,$q,$r) ($q.x-$p.x)*($r.z-$p.z)-($q.z-$p.z)*($r.x-$p.x)}; $d1=& $o $c $d $a; $d2=& $o $c $d $b; $d3=& $o $a $b $c; $d4=& $o $a $b $d; return (($d1 -gt 0) -ne ($d2 -gt 0)) -and (($d3 -gt 0) -ne ($d4 -gt 0)) -and [Math]::Abs($d1) -gt 1 -and [Math]::Abs($d2) -gt 1 }
function SegDist($p,$a,$b){ $dx=$b.x-$a.x;$dz=$b.z-$a.z;$l2=$dx*$dx+$dz*$dz; $t=if($l2 -gt 0){[Math]::Max(0.0,[Math]::Min(1.0,[double]((($p.x-$a.x)*$dx+($p.z-$a.z)*$dz)/$l2)))}else{0.0}; [Math]::Sqrt([Math]::Pow($p.x-($a.x+$t*$dx),2)+[Math]::Pow($p.z-($a.z+$t*$dz),2)) }

function Do-Link {
 # Wire two buildings together through their free utility connector nodes, e.g. a coal plant's
 # high-voltage output to a transformer. Road-side buildings need no links: roads carry LV power/water/sewage.
 $a=Parse-Id $From; $b=Parse-Id $To
 $kind=if($Type){$Type}else{'hv'}
 $net=switch -regex ($kind){ '^(hv|high)' {'High-voltage Line';break} '^(lv|low)' {'Low-voltage Line';break} '^water' {'Small Water Pipe';break} '^sewage' {'Small Sewage Pipe';break} default {$kind} }
 $p=Resolve-Prefab $net 'network'
 $free={param($id) @((Bridge get_utility_connectors $id).candidates|Where-Object {@($_.incidentEdges).Count -eq 0})}
 $na=@(& $free $a); $nb=@(& $free $b)
 if(!$na.Count -or !$nb.Count){throw "No free connector on $(if(!$na.Count){$From}else{$To}). It may already be linked (check city.ps1 problems), or this building has no $net connector."}
 $best=$null;$bd=[double]::MaxValue; foreach($x in $na){foreach($y in $nb){$d=Dist $x.position $y.position; if($d -lt $bd){$bd=$d;$best=@($x,$y)}}}
 if($bd -gt 1000){throw "Connectors are $([Math]::Round($bd)) m apart; place the buildings closer (max 1000 m per line)."}
 $req=@{prefabIndex=$p.index;prefabVersion=$p.version;maxCost=$(if($MaxCost){$MaxCost}else{100000});elevation=0
  start=@{index=$best[0].index;version=$best[0].version;x=$best[0].position.x;z=$best[0].position.z}
  end=@{index=$best[1].index;version=$best[1].version;x=$best[1].position.x;z=$best[1].position.z}}
 $r=Bridge build_network $req
 Out-Result $r {"$net built between $From and $To ($([Math]::Round($bd)) m, cost $($r.previewCost)). Check city.ps1 problems: the 'not connected' icon should clear within a minute of game time."}
}

function Do-Zone {
 $z=Resolve-Zone $(if($Type){$Type}elseif($Name){$Name}else{throw 'zone needs -Type, e.g. -Type residential'})
 if(!$From -or !$To){throw 'zone needs -From x,z -To x,z (opposite corners of the rectangle).'}
 $a=ParsePoint $From '-From'; $b=ParsePoint $To '-To'
 # The native marquee is limited to a 500 m diagonal: split big rectangles into tiles.
 $total=0; $skipped=0; $results=@(); $sawCells=$false
 foreach($tile in Zone-Tiles $a $b){
  $ta=$tile.a; $tb=$tile.b
  $mid=[ordered]@{x=($ta.x+$tb.x)/2;z=($ta.z+$tb.z)/2}
  # Anchor: any live zone block with a cell inside this tile (nearest to its first corner).
  $cells=@((Bridge get_zone_cells @{x=$mid.x;z=$mid.z;radius=[Math]::Max(20,[Math]::Min(500,(Dist $ta $tb)/2+10));limit=4000}).cells|Where-Object {
   $_.position.x -ge $ta.x-8 -and $_.position.x -le $tb.x+8 -and $_.position.z -ge $ta.z-8 -and $_.position.z -le $tb.z+8 })
  if(!$cells.Count){$skipped++; continue}
  $sawCells=$true
  $anchor=$cells|Sort-Object {Dist $_.position $ta}|Select-Object -First 1
  $req=@{prefabIndex=$z.index;prefabVersion=$z.version;start=@{index=$anchor.blockIndex;version=$anchor.blockVersion;x=$ta.x;z=$ta.z};end=@{x=$tb.x;z=$tb.z}}
  if($Preview){$req.previewOnly=$true}
  try { $r=Bridge zone_rectangle $req } catch { if($_.Exception.Message -match 'no_zone_cells_in_rectangle'){$skipped++;continue}; throw }
  $results+=$r; $total+=if($Preview){@($r.previewCells).Count}else{[int]$r.changedCells}
 }
 if(!$results.Count){ if($sawCells){throw "Nothing left to zone inside $From .. $To`: every road-side cell there is already zoned, built on or blocked. Pick new land (city.ps1 land / map) or build new streets first."}; throw "No zone cells inside $From .. $To. Zone cells exist only within ~48 m of a road; build roads there first."}
 Out-Result $results {
  $tiles=if($results.Count -gt 1){" in $($results.Count) tiles"}else{''}
  if($Preview){"PREVIEW ONLY - nothing changed. $($z.name) would cover $total cells$tiles. Run again without -Preview to apply."}
  else{"$($z.name): $total cells zoned$tiles. Buildings grow on their own while the game runs (try: city.ps1 grow)."}
  if($skipped){"($skipped tile(s) had no road-side cells and were skipped)"}
 }
}

function Do-Place {
 $p=Resolve-Prefab $Name 'building'
 $c=if($At){ParsePoint $At '-At'}else{Center}
 $cost=if($MaxCost){$MaxCost}else{1000000}
 $tries=@()
 if(![double]::IsNaN($Rotation)){ $tries+=[ordered]@{position=$c;rotation=$Rotation} }
 else {
  $rad=if([double]::IsNaN($Radius)){150}else{$Radius}
  $sites=@((Bridge find_building_sites @{prefabIndex=$p.index;prefabVersion=$p.version;x=$c.x;z=$c.z;radius=$rad}).candidates)
  # find_building_sites does not know which map tiles you own; drop sites the game would refuse.
  $owned=@(OwnedBoxes); $outside=0
  foreach($s in $sites){
   if($owned.Count -and !(InOwned $s.position $owned)){$outside++;continue}
   if($tries.Count -lt 8){$tries+=[ordered]@{position=[ordered]@{x=[Math]::Round($s.position.x,2);z=[Math]::Round($s.position.z,2)};rotation=[Math]::Round($s.rotation,1)}}
  }
  if(!$tries.Count){$lot=(Bridge get_prefab_details @{index=$p.index;version=$p.version}).rawData.'Game.Prefabs.BuildingData'.m_LotSize; $size=if($lot){" It needs a $([int]$lot.x*8) m wide (along the road) x $([int]$lot.y*8) m deep lot."}else{''}; throw "No free road-side site for $($p.name) within $rad m of ($($c.x),$($c.z))$(if($outside){" ($outside more were outside land you own)"}). Road sides there are already used by zoned buildings or other services. Build a short dead-end road into EMPTY UNZONED land and place it there, or raise -Radius.$size"}
 }
 $log=@()
 foreach($t in $tries){
  $req=@{prefabIndex=$p.index;prefabVersion=$p.version;position=$t.position;rotation=$t.rotation;maxCost=$cost;previewOnly=$true}
  try { $pv=Bridge place_building $req 30 } catch { $m=$_.Exception.Message; $why=if($m -match 'Reasons: ([^.]*)\.'){$Matches[1]}else{($m -split "`n")[0] -replace '^place_building failed: ',''}; $log+="  ($($t.position.x),$($t.position.z)) rot $($t.rotation): $why"; continue }
  # Spending guard: the preview knows the real price; keep -Reserve cash (default 50000) in the bank.
  if($pv.previewCost){ $money=[double](Status).money; if($money-[double]$pv.previewCost -lt $Reserve){ throw "$($p.name) costs $($pv.previewCost) but you have $([Math]::Round($money)); building it would leave less than the -Reserve of $Reserve. Wait for income (city.ps1 grow) or pass a lower -Reserve." } }  $build=$req.Clone(); $build.Remove('previewOnly')
  $r=Bridge place_building $build 60
  $made=@($r.createdBuildings)|ForEach-Object {"$($_.index):$($_.version)"}
  $o=[ordered]@{prefab=$p.name;position=$t.position;rotation=$t.rotation;created=$made;result=$r}
  Out-Result $o {
   "$($p.name) built at ($($t.position.x),$($t.position.z)) rotation $($t.rotation). id: $($made -join ', ')$(if($pv.previewCost){"  cost $($pv.previewCost)"})"
   if($log.Count){"(skipped $($log.Count) rejected site(s) first)"}
  }
  return
 }
 throw "The game rejected every site tried for $($p.name):`n$($log -join "`n")`n  HINT: OverlapExisting = too close to a road/building, InWater = too far into water (shoreline buildings need the exact bank), ExceedsCityLimits = part of it sticks out of land you own (move inward or buy the tile: city.ps1 land). Try another -At, or -Rotation with a hand-picked spot."
}

function Do-Buildings {
 $req=@{filter=$Filter;problemsOnly=[bool]$Problems;limit=[Math]::Max(1,[Math]::Min(2000,$Limit))}
 if($At){$p=ParsePoint $At '-At'; $req.x=$p.x; $req.z=$p.z; $req.radius=if([double]::IsNaN($Radius)){300}else{$Radius}}
 $r=Bridge get_buildings $req
 $b=@($r.buildings)
 if($At -and $null -eq $r.total){ $b=@($b|Where-Object {(Dist $_.position $p) -le $req.radius}) }  # older DLLs ignore x/z
 Out-Result $r {
  $count=if($null -ne $r.total){$r.total}else{$b.Count}
  "$count buildings$(if($Problems){' with problems'})$(if($Filter){" matching '$Filter'"})$(if($At){" within $($req.radius) m of $At"})$(if($null -eq $r.total -and $r.possiblyTruncated){' (DLL before 0.5.2 stops at 512; use -At to look at one area)'}):"
  $b|Sort-Object prefab|Select-Object -First $Limit|ForEach-Object {
   "  {0,-11} {1,-36} ({2,6:N0},{3,6:N0}){4}{5}" -f "$($_.index):$($_.version)",$_.prefab,$_.position.x,$_.position.z,$(if($_.underConstruction){' [building]'}),$(if(@($_.issues).Count){'  ! '+(@($_.issues) -join ',')}) }
  if($count -gt [Math]::Min($Limit,$b.Count)){"  ... $($count-[Math]::Min($Limit,$b.Count)) more (use -Limit, -Filter or -At)"}
 }
}

function Parse-Id([string]$Text) { if($Text -notmatch '^(\d+)[:v](\d+)$'){throw "Id must look like 12345:6 (index:version), got '$Text'"}; return @{index=[int]$Matches[1];version=[int]$Matches[2]} }
function Do-Inspect { $i=Parse-Id $(if($Id){$Id}else{$Rest|Select-Object -First 1}); $r=Bridge inspect_entity $i; Out-Result $r { $r|Select-Object * -ExcludeProperty components,utilityEvidenceMeaning,rotationQuaternion,curve|ConvertTo-Json -Depth 6 } }
function Do-Demolish { $i=Parse-Id $(if($Id){$Id}else{$Rest|Select-Object -First 1}); $r=Bridge demolish $i; Out-Result $r {"demolish $($i.index):$($i.version): $($r.status)"} }

function Do-Unlocks {
 $d=Bridge get_devtree
 Out-Result $d {
  "development points: $($d.developmentPoints)   city XP: $($d.cityXp)"
  $nodes=@($d.nodes)
  if($Type){
   # One branch of the in-game Development tree, e.g. unlocks -Type Electricity
   $branch=@($nodes|Where-Object {$_.service.name -match $Type})
   if(!$branch.Count){"no branch matches '$Type'. Branches: $((@($nodes.service.name)|Sort-Object -Unique) -join ', ')"; return}
   "$($branch[0].service.name) branch:"
   $branch|Sort-Object cost,name|ForEach-Object {"  {0,-34} cost {1}  {2}" -f $_.name,$_.cost,$(if(!$_.locked){'OWNED'}elseif($_.purchasable){"can buy now (city.ps1 buy $($_.name))"}else{'needs an earlier node first'})}
   return
  }
  if($Filter){
   # Show the prerequisite chain for matching nodes, e.g. unlocks -Filter LargeRoads
   $byId=@{}; foreach($n in $nodes){$byId["$($n.index):$($n.version)"]=$n}
   foreach($n in @($nodes|Where-Object {$_.name -match $Filter})){
    "$($n.name): cost $($n.cost), $(if(!$n.locked){'OWNED'}elseif($n.purchasable){'BUY NOW (city.ps1 buy '+$n.name+')'}else{"blocked: $($n.blocker)"})"
    $seen=@{}; $queue=[System.Collections.Generic.Queue[object]]::new(); $queue.Enqueue(@($n,1))
    while($queue.Count){ $item=$queue.Dequeue(); $cur=$item[0]; $depth=$item[1]
     foreach($req in @($cur.requirements)){ $k="$($req.index):$($req.version)"; if($seen[$k]){continue}; $seen[$k]=1; $r=$byId[$k]; if(!$r){continue}
      "$('  '*$depth)needs $($r.name) (cost $($r.cost), $(if(!$r.locked){'owned'}elseif($r.purchasable){'buy now'}else{$r.blocker}))"
      if($r.locked){$queue.Enqueue(@($r,$depth+1))} } }
    if(@($n.requirements).Count -gt 1 -and $n.requirementRule -match 'any'){"  (any ONE of these prerequisites is enough)"}
   }
   return
  }
  $ok=@($nodes|Where-Object {$_.eligible -eq $true -or $_.purchasable -eq $true})
  if($ok.Count){'can buy now:'; $ok|Select-Object -First $Limit|ForEach-Object {"  {0,-10} {1} (cost {2})" -f "$($_.index):$($_.version)",$_.name,$_.cost}}
  else{"$($nodes.Count) nodes; none purchasable right now."}
  'buy with: city.ps1 buy <NodeName>'
 }
}

function Do-Milestones {
 try { $m=Bridge get_milestones } catch { if($_.Exception.Message -match 'unknown_command|ValidateSet|does not belong'){throw 'get_milestones needs bridge DLL 0.5.0-coach.1 (see INSTALL.md). city.ps1 status still shows XP.'}; throw }
 Out-Result $m {
  "milestone $($m.achievedMilestone) reached; XP $($m.currentXP) / $($m.nextMilestoneXP) for milestone $($m.nextMilestone) ($([Math]::Round(100*[double]$m.progress))%)"
  foreach($s in @($m.milestones|Where-Object {!$_.achieved}|Select-Object -First 3)){
   $names=@($s.unlocks|ForEach-Object name)
   "  #$($s.index) $($s.name) at $($s.xpRequired) XP: +$($s.moneyReward) money, +$($s.developmentPoints) dev points, +$($s.mapTiles) tiles; unlocks $($names.Count): $(($names|Select-Object -First 12) -join ', ')$(if($names.Count -gt 12){' ...'})"
  }
 }
}
function Do-Buy {
 $want=($Rest -join ' ').Trim(); if(!$want -and $Name){$want=$Name}; if(!$want){throw 'buy <NodeName or index:version> - see city.ps1 unlocks'}
 $d=Bridge get_devtree; $nodes=@($d.nodes)
 $node=if($want -match '^\d+[:v]\d+$'){$i=Parse-Id $want; $nodes|Where-Object {$_.index -eq $i.index -and $_.version -eq $i.version}|Select-Object -First 1}else{$nodes|Where-Object {$_.name -eq $want -or $_.name -eq "${want}Node"}|Select-Object -First 1}
 if(!$node){throw "No development node '$want'. See: city.ps1 unlocks"}
 if(!$node.purchasable){throw "$($node.name) cannot be bought now: $($node.blocker) (points $($d.developmentPoints), cost $($node.cost))."}
 $r=Bridge purchase_node @{index=$node.index;version=$node.version;maxPoints=$node.cost}
 Out-Result $r {"bought $($node.name) for $($node.cost) point(s): $($r.status ?? 'submitted'). Verify with city.ps1 unlocks."}
}
# Plain-English fixes for the in-game warning icons (notification prefab names vary; match loosely).
$IconAdvice=[ordered]@{
 'Accident'='usually clears by itself (emergency services tow it); if it keeps happening, simplify that junction'
 'Traffic|Jam'='add a parallel route/second link to the highway, or widen it: city.ps1 upgrade -Path x,z -Type large'
 'Powerline Not Connected'='a power plant''s high-voltage output is not wired: place TransformerStation01 beside it and run city.ps1 link -From <plant id> -To <transformer id> (a lone map power line can be ignored)'
 'Electric|Power'='add generation or connect this area to a powered road'
 'Water|Pipe'='add water capacity or connect this area to a road reached by your water source'
 'Sewage'='add sewage outlet/treatment capacity or connect the area'
 'Garbage|Trash'='build a landfill or more garbage capacity'
 'Worker|Employee'='zone more housing near these jobs'
 'Customer'='zone more housing / lower commercial zoning here'
 'Road|Access'='connect this building to the road network'
 'Abandon'='fix the cause (utilities, taxes, demand) or demolish'
 'Crime'='place a police station nearby (city.ps1 find police)'
 'Fire|Burn'='place a fire station nearby (city.ps1 find fire)'
 'Sick|Health|Hospital'='more clinics/hospitals'
 'Dead|Death|Hearse'='cemetery or crematorium capacity'
 'Pollution|Noise'='move industry/generators away from homes, add parks'
 'Education|School'='schools'
}
function Advice([string]$Type){ foreach($k in $IconAdvice.Keys){ if($Type -match $k){return $IconAdvice[$k]} }; return '' }
function Do-Problems {
 $req=@{examples=[Math]::Max(1,[Math]::Min(50,$Limit))}; if($Filter){$req.filter=$Filter}
 if($At){$c=ParsePoint $At '-At'; $req.x=$c.x; $req.z=$c.z; $req.radius=if([double]::IsNaN($Radius)){500}else{$Radius}}
 try { $r=Bridge get_notifications $req } catch { if($_.Exception.Message -match 'unknown_command|ValidateSet|does not belong'){throw 'get_notifications needs bridge DLL 0.5.0-coach.1 (see INSTALL.md). Until then use: city.ps1 buildings -Problems'}; throw }
 Out-Result $r {
  $types=@($r.types|Where-Object {$_ -and $_.type -ne 'Selected'})
  if(!$types.Count){'no warning icons right now'; return}
  "$($r.total) warning icons on the map:"
  # Where are the problems? Clusters (DLL 0.5.2+) or grouped examples, with distance to your land.
  $cl=@($r.clusters|Where-Object {$_ -and $_.type -ne 'Selected'})
  if(!$cl.Count){ $cl=@($types|ForEach-Object {$ty=$_.type; @($_.examples)|Group-Object {"{0},{1}" -f [Math]::Floor($_.position.x/400),[Math]::Floor($_.position.z/400)}|ForEach-Object {[pscustomobject]@{type=$ty;count=$_.Count;centre=$_.Group[0].position}}}) }
  $own=@(OwnedBoxes)
  $far=@(); $nearby=@()
  foreach($c in ($cl|Sort-Object count -Descending)){ $d=DistToLand $c.centre
   $line="    {0} x{1} around ({2:N0},{3:N0}) - {4}" -f $c.type,$c.count,$c.centre.x,$c.centre.z,$(if($d -lt 1){'INSIDE your land'}else{"$([Math]::Round($d)) m outside your land"})
   if($d -gt 2000){$far+=$line}else{$nearby+=$line} }
  'where (400 m clusters):'; $nearby|Select-Object -First 12
  if($far.Count){"    ($($far.Count) cluster(s) more than 2 km outside your land - usually safe to ignore)"}  foreach($g in $types){
   "  $($g.type) x$($g.count) [$($g.priority)]$(if($a=Advice $g.type){"  -> $a"})"
   foreach($ex in @($g.examples)|Select-Object -First ([Math]::Min(5,$Limit))){ "      at ({0:N0},{1:N0}){2}" -f $ex.position.x,$ex.position.z,$(if($ex.on){" on $($ex.on.kind) $($ex.on.prefab) $($ex.on.index):$($ex.on.version)"}) }
  }
 }
}
function TileBox($t){ $px=@($t.polygon.x);$pz=@($t.polygon.z); [pscustomobject]@{id="$($t.index):$($t.version)";index=$t.index;version=$t.version;owned=[bool]$t.purchased;x0=($px|Measure-Object -Minimum).Minimum;x1=($px|Measure-Object -Maximum).Maximum;z0=($pz|Measure-Object -Minimum).Minimum;z1=($pz|Measure-Object -Maximum).Maximum} }
function Do-Land {
 $r=Bridge get_tiles; $boxes=@($r.tiles|ForEach-Object {TileBox $_}); $own=@($boxes|Where-Object owned)
 $near={param($b) foreach($o in $own){ $dx=[Math]::Max(0,[Math]::Max($o.x0-$b.x1,$b.x0-$o.x1)); $dz=[Math]::Max(0,[Math]::Max($o.z0-$b.z1,$b.z0-$o.z1)); $ox=[Math]::Min($o.x1,$b.x1)-[Math]::Max($o.x0,$b.x0); $oz=[Math]::Min($o.z1,$b.z1)-[Math]::Max($o.z0,$b.z0); if(($dx -lt 2 -and $oz -gt 10) -or ($dz -lt 2 -and $ox -gt 10)){return $true} }; $false}
 $adj=@($boxes|Where-Object {!$_.owned -and (& $near $_)})
 # Sample each candidate's centre and corners for water so the agent doesn't buy a lake.
 $pts=foreach($b in $adj){ foreach($f in @(@(0.5,0.5),@(0.2,0.2),@(0.8,0.2),@(0.2,0.8),@(0.8,0.8))){ @{x=$b.x0+($b.x1-$b.x0)*$f[0];z=$b.z0+($b.z1-$b.z0)*$f[1]} } }
 $s=if($pts){@((Bridge sample_terrain @{points=@($pts)}).samples)}else{@()}
 $ox=($own.x0+$own.x1|Measure-Object -Average).Average; $oz=($own.z0+$own.z1|Measure-Object -Average).Average
 $rows=for($i=0;$i -lt $adj.Count;$i++){ $b=$adj[$i]; $wet=@($s[($i*5)..($i*5+4)]|Where-Object {$_.waterDepth -gt 0.5}).Count; $cx=($b.x0+$b.x1)/2; $cz=($b.z0+$b.z1)/2
  $dir=(@(if($cz -gt $oz+300){'north'}elseif($cz -lt $oz-300){'south'}) + @(if($cx -gt $ox+300){'east'}elseif($cx -lt $ox-300){'west'})) -join '-'
  [pscustomobject]@{id=$b.id;dir=$dir;centre="$([Math]::Round($cx)),$([Math]::Round($cz))";water="$($wet*20)%";box=$b} }
 Out-Result $rows {
  "you own $($own.Count) tiles; $($r.availablePurchases) more may be bought (milestones grant more). Buyable tiles touching your land:"
  $rows|Sort-Object {[int]($_.water -replace '%')}|ForEach-Object {"  {0,-9} {1,-11} centre {2,-12} water {3}" -f $_.id,$_.dir,$_.centre,$_.water}
  'buy with: city.ps1 buyland -At x,z   (any point inside the tile; mostly-dry tiles are best)'
 }
}
function Do-BuyLand {
 $p=if($At){ParsePoint $At '-At'}else{throw 'buyland -At x,z (a point inside the tile, see city.ps1 land)'}
 $t=@((Bridge get_tiles).tiles|ForEach-Object {TileBox $_}|Where-Object {$p.x -ge $_.x0 -and $p.x -le $_.x1 -and $p.z -ge $_.z0 -and $p.z -le $_.z1})|Select-Object -First 1
 if(!$t){throw "No map tile contains ($($p.x),$($p.z))."}; if($t.owned){throw "You already own the tile at ($($p.x),$($p.z))."}
 $r=Bridge purchase_tiles @{tiles=@(@{index=$t.index;version=$t.version});maxCost=$(if($MaxCost){$MaxCost}else{500000})}
 Out-Result $r {"bought tile $($t.id) (x $([Math]::Round($t.x0))..$([Math]::Round($t.x1)), z $([Math]::Round($t.z0))..$([Math]::Round($t.z1))) for $($r.cost)."}
}

function Do-Budget {
 $m=Bridge get_city_management
 Out-Result $m {
  "taxes: $(($m.taxes.PSObject.Properties|ForEach-Object {"$($_.Name) $($_.Value)%"}) -join ', ')"
  "income $($m.budget.incomeRaw)  expenses $($m.budget.expensesRaw)  balance $($m.budget.balanceRaw)  (per month, raw units)"
  'income: '+(($m.budget.incomeBySourceRaw.PSObject.Properties|Where-Object {$_.Value}|Sort-Object Value -Descending|ForEach-Object {"$($_.Name) $($_.Value)"}) -join ', ')
  'expenses: '+(($m.budget.expenseBySourceRaw.PSObject.Properties|Where-Object {$_.Value}|Sort-Object Value -Descending|ForEach-Object {"$($_.Name) $($_.Value)"}) -join ', ')
  "demand: residential $($m.demand.residential -join '/') (low/med/high)  commercial $($m.demand.commercial)  industrial $($m.demand.industrial)  office $($m.demand.office)"
 }
}
function Do-Tax { if($Rate -eq -999 -and $Rest.Count){$Rate=[int]$Rest[0]}; if(!$Type -or $Rate -eq -999){throw 'tax -Type Residential|Commercial|Industrial|Office -Rate n'}; $rate=$Rate; $r=Bridge set_tax @{area=$Type;rate=$rate}; Out-Result $r {"$Type tax $($r.before)% -> $($r.after)%"} }
function Do-Chirper { $r=Bridge get_chirper @{limit=[Math]::Min(100,$Limit)}; Out-Result $r { @($r.posts)|ForEach-Object {"- $($_.text ?? $_.message ?? ($_|ConvertTo-Json -Compress -Depth 3))"} } }
function Do-Save { $label=if($Name){$Name}else{'city'}; $r=Bridge save_checkpoint @{label=$label} 60; Out-Result $r {"saved: $($r.saveName ?? $r.status)"} }
function Do-Raw { $cmd=$Rest|Select-Object -First 1; if(!$cmd){throw 'raw <command> -ArgsJson ''{...}'''}; $r=Bridge $cmd $ArgsJson 60; $r|ConvertTo-Json -Depth 30 }

function Do-Overview {
 $d=Bridge get_city_diagnostics
 $c=$d.city; $u=$d.utilitiesRaw
 $short=@($d.persistentShortages)
 $groups=@($short|Group-Object type)
 $pen=@($d.efficiencyPenalties|ForEach-Object {$b=$_; @($_.penalties)|ForEach-Object {[pscustomobject]@{factor=$_.factor;prefab=$b.prefab}}})
 $next=[System.Collections.Generic.List[string]]::new()
 function Pct($a,$b){ if([double]$b -gt 0){[Math]::Round(100*[double]$a/[double]$b)}else{$null} }
 $ep=Pct $u.electricity.production $u.electricity.capacity; $wp=Pct $u.water.production $u.water.capacity; $sp=Pct $u.sewage.processing $u.sewage.capacity
 if([double]$u.electricity.capacity -eq 0){$next.Add('No power: place a generator beside a connected road (city.ps1 find wind / find power).')}elseif($ep -ge 80){$next.Add("Power $ep% used: add another generator soon.")}
 if([double]$u.water.capacity -eq 0){$next.Add('No water: place WaterTower01 (groundwater) or a pumping station on a shore, beside a connected road.')}elseif($wp -ge 80){$next.Add("Water $wp% used: add another water source.")}
 if([double]$u.sewage.capacity -eq 0){$next.Add('No sewage: place SewageOutlet01 on a shoreline, beside a connected road, away from water intakes.')}elseif($sp -ge 80){$next.Add("Sewage $sp% used: add capacity.")}
 foreach($g in $groups){$next.Add("$($g.Count) buildings short of $($g.Name): check that source's road connects to them, or add capacity.")}
 # Only suggest zones the player can actually paint; locked demand means "reach the next milestone".
 $usable=@((Bridge get_zone_catalog).zones|Where-Object usable|ForEach-Object name)
 $has={param($rx) [bool]@($usable|Where-Object {$_ -match $rx}).Count}
 $res=@($d.demand.residential); $lock=[System.Collections.Generic.List[string]]::new()
 foreach($lvl in @(@(0,'low','Residential Low(?! ?Rent)','residential'),@(1,'medium','Residential (Medium|Row|Mixed)','residential-row'),@(2,'high','Residential High','residential-high'))){
  if($res.Count -gt $lvl[0] -and [double]$res[$lvl[0]] -gt 40){
   if(& $has $lvl[2]){$next.Add("$($lvl[1])-density housing demand $($res[$lvl[0]]): city.ps1 zone -Type $($lvl[3]) ...")}else{$lock.Add("$($lvl[1])-density housing")} } }
 if([double]$d.demand.commercial -gt 40){$next.Add('Commercial demand high: zone more shops (city.ps1 zone -Type commercial).')}
 if([double]$d.demand.industrial -gt 40){$next.Add('Industrial demand high: zone industry away from homes (downwind, near the highway).')}
 if([double]$d.demand.office -gt 40){ if(& $has 'Office'){$next.Add('Office demand high: city.ps1 zone -Type office ...')}else{$lock.Add('offices')} }
 if($lock.Count){$next.Add("Demand for $($lock -join ' and ') is LOCKED: keep growing to the next milestone (city.ps1 status shows XP). Low-density zoning still grows XP.")}
 if([double]$d.budget.balanceRaw -lt 0){$next.Add("Budget negative ($($d.budget.balanceRaw)/month): grow population, raise taxes a little, or trim service budgets.")}
 $top=@($pen|Group-Object factor|Sort-Object Count -Descending|Select-Object -First 4)
 foreach($t in $top){ if($t.Name -eq 'NotEnoughEmployees'){ if((@($d.demand.residential)|Measure-Object -Maximum).Maximum -gt 30){$next.Add("$($t.Count) businesses lack workers: zone more housing.")}else{$next.Add("$($t.Count) businesses lack workers, but housing demand is low: residents are still moving in ($([int]$c.populationWithMoveIn-[int]$c.population)) or commutes are too long. Keep growing; avoid zoning more jobs for now.")} } elseif($t.Name -eq 'WindSpeed'){} else {$next.Add("$($t.Count) buildings penalised by $($t.Name).")} }
 try { $icons=Bridge get_notifications @{examples=20}; foreach($g in @($icons.types|Where-Object {$_ -and $_.type -ne 'Selected'})|Select-Object -First 4){ $near=@($g.examples|Where-Object {(DistToLand $_.position) -lt 2000}); if(!$near.Count){continue}; $ex=$near[0]; $next.Add("$($g.count) '$($g.type)' warning icon(s), e.g. at ($([Math]::Round($ex.position.x)),$([Math]::Round($ex.position.z))). $(Advice $g.type)  (city.ps1 problems)") } } catch {}
 if(!$next.Count){$next.Add('No urgent problems. Grow (city.ps1 grow), then expand roads + zoning as demand rises.')}
 $o=[ordered]@{city=$c;demand=$d.demand;budget=$d.budget;utilities=$u;shortages=$groups|ForEach-Object {@{type=$_.Name;count=$_.Count}};penalties=$top|ForEach-Object {@{factor=$_.Name;count=$_.Count}};buildings=$d.buildingCount;underConstruction=$d.underConstruction;next=$next}
 Out-Result $o {
  "$($c.cityName)  pop $($c.population) (+$([int]$c.populationWithMoveIn-[int]$c.population) moving in)  money $([Math]::Round($c.money))  XP $($c.xp)  happiness $($c.averageHappiness)  date $($c.date)"
  "buildings $($d.buildingCount) ($($d.underConstruction) under construction)   households $($d.households)"
  "demand: residential $(@($d.demand.residential) -join '/')  commercial $($d.demand.commercial)  industrial $($d.demand.industrial)  office $($d.demand.office)   (0-100)"
  "budget per month: income $($d.budget.incomeRaw)  expenses $($d.budget.expensesRaw)  balance $($d.budget.balanceRaw)"
  "power  $($u.electricity.production)/$($u.electricity.capacity)$(if($null -ne $ep){" ($ep%)"})   water $($u.water.production)/$($u.water.capacity)$(if($null -ne $wp){" ($wp%)"})   sewage $($u.sewage.processing)/$($u.sewage.capacity)$(if($null -ne $sp){" ($sp%)"})"
  "shortages: $(if($groups.Count){($groups|ForEach-Object {"$($_.Name) x$($_.Count)"}) -join ', '}else{'none'})"
  if($top.Count){"efficiency penalties: $(($top|ForEach-Object {"$($_.Name) x$($_.Count)"}) -join ', ')"}
  'NEXT:'; $next|ForEach-Object {"  - $_"}
 }
}

# ---------------------------------------------------------------- main
if($LibraryOnly){return}
$restore=$null
try {
 if($Verb -ne 'help'){ try { $restore=[double](Status).selectedSpeed } catch { if($_.Exception.Message -match 'heartbeat'){throw (Explain 'status' $_.Exception.Message)}; throw } }
 switch($Verb){
  'help'{Do-Help} 'status'{Do-Status} 'overview'{Do-Overview} 'speed'{Do-Speed} 'grow'{Do-Grow} 'find'{Do-Find}
  'zones'{Do-Zones} 'map'{Do-Map} 'roads'{Do-Roads} 'road'{Do-Road} 'upgrade'{Do-Upgrade} 'link'{Do-Link} 'zone'{Do-Zone} 'place'{Do-Place}
  'buildings'{Do-Buildings} 'inspect'{Do-Inspect} 'demolish'{Do-Demolish} 'unlocks'{Do-Unlocks} 'budget'{Do-Budget}
  'land'{Do-Land} 'buyland'{Do-BuyLand} 'tax'{Do-Tax} 'problems'{Do-Problems} 'buy'{Do-Buy} 'milestones'{Do-Milestones} 'chirper'{Do-Chirper} 'save'{Do-Save} 'raw'{Do-Raw}
  default {throw "Unknown verb '$Verb'. Run: city.ps1 help"}
 }
} catch {
 [Console]::Out.WriteLine("ERROR: $($_.Exception.Message)")
 $script:failed=$true
} finally {
 # Bridge reads pause the city. Put the clock back unless the caller chose a speed.
 # DLL 0.5.0+ only pauses for construction; check the real speed so we never 'restore' needlessly.
 if($script:PausedByUs -and !$KeepPaused -and $restore -gt 0){ try { if([double](Status).selectedSpeed -gt 0){$script:PausedByUs=$false} } catch {} }
 if($script:PausedByUs -and !$KeepPaused -and $restore -gt 0){
  $why=''
  for($try=0;$try -lt 3;$try++){
   $raw=& $Agent -Command set_simulation_speed -ArgsJson (@{speed=$restore}|ConvertTo-Json -Compress) -WaitSeconds 5 2>$null
   $res=try{($raw -join "`n")|ConvertFrom-Json}catch{$null}
   if($res -and !$res.error){$why='';break}
   $why=if($res.error){$res.error}else{'no response'}; Start-Sleep -Milliseconds 1500  # e.g. construction still finishing
  }
  if($why){[Console]::Out.WriteLine("WARNING: the game was left PAUSED (could not restore speed $restore`: $why). Run: city.ps1 speed $restore")}
 }
}
if($script:failed){exit 1}
