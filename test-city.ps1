#requires -Version 7.5
# Offline checks for city.ps1. No game commands are sent: Bridge is replaced by a fake.
$ErrorActionPreference='Stop'
$passed=0
function Check([bool]$Condition,[string]$Label){ if(!$Condition){throw "FAIL: $Label"}; $script:passed++; "PASS: $Label" }
function Throws([scriptblock]$Block,[string]$Pattern){ try{& $Block; return $false}catch{ return $_.Exception.Message -match $Pattern } }

. (Join-Path $PSScriptRoot 'city.ps1') -LibraryOnly

# --- geometry helpers
$p=ParsePoint '473,1643'; Check ($p.x -eq 473 -and $p.z -eq 1643) 'point "x,z" parses'
$p=ParsePoint ' -700.5 , 1240 '; Check ($p.x -eq -700.5 -and $p.z -eq 1240) 'negative/decimal point with spaces parses'
Check (Throws {ParsePoint '473'} 'must look like') 'malformed point explains the format'

$legs=@(Split-Legs @((ParsePoint '0,0'),(ParsePoint '0,500')))
Check ($legs.Count -eq 1) 'short leg stays one segment'
$legs=@(Split-Legs @((ParsePoint '355,1240'),(ParsePoint '-700,1240')))
Check ($legs.Count -eq 2 -and $legs[0].end.x -eq $legs[1].start.x) '1055 m leg splits into two joined segments'
Check (@($legs|Where-Object {(Dist $_.start $_.end) -gt 1000}).Count -eq 0) 'no split segment exceeds the 1000 m bridge limit'
$legs=@(Split-Legs @((ParsePoint '0,0'),(ParsePoint '0,400'),(ParsePoint '400,400')))
Check ($legs.Count -eq 2 -and $legs[1].start.z -eq 400) 'multi-point path keeps corners'
Check (Throws {Split-Legs @((ParsePoint '0,0'),(ParsePoint '3,0'))} 'at least 8 m') 'too-short leg rejected before sending'

$tiles=@(Zone-Tiles (ParsePoint '280,1395') (ParsePoint '400,1692'))
Check ($tiles.Count -eq 1) 'small rectangle is one tile'
$tiles=@(Zone-Tiles (ParsePoint '-720,995') (ParsePoint '20,1445'))
Check ($tiles.Count -eq 6) '740x450 rectangle tiles into 3x2'
Check (@($tiles|Where-Object {(Dist $_.a $_.b) -gt 500}).Count -eq 0) 'every tile respects the 500 m marquee diagonal'
$area=($tiles|ForEach-Object {($_.b.x-$_.a.x)*($_.b.z-$_.a.z)}|Measure-Object -Sum).Sum
Check ([Math]::Abs($area-740*450) -lt 1) 'tiles cover the whole rectangle exactly'
Check (@(Zone-Tiles (ParsePoint '400,1692') (ParsePoint '280,1395'))[0].a.x -eq 280) 'reversed corners are normalised'

# --- fake bridge
$script:FakeMoney=1000000
$script:Sent=[System.Collections.Generic.List[object]]::new()
function Bridge([string]$Command,$Arguments=@{},[int]$Wait=60){
 $script:Sent.Add([pscustomobject]@{command=$Command;args=$Arguments})
 switch($Command){
  'get_zone_catalog' { return [pscustomobject]@{zones=@(
    [pscustomobject]@{name='NA Residential Low';index=83;version=1;usable=$true;locked=$false;matchingGrowables=88},
    [pscustomobject]@{name='EU Residential Low';index=75;version=1;usable=$true;locked=$false;matchingGrowables=88},
    [pscustomobject]@{name='NA Residential High';index=90;version=1;usable=$false;locked=$true;matchingGrowables=40},
    [pscustomobject]@{name='Industrial Manufacturing';index=79;version=1;usable=$true;locked=$false;matchingGrowables=483})} }
  'get_zone_cells' { $c=$Arguments; return [pscustomobject]@{cells=@([pscustomobject]@{blockIndex=500;blockVersion=3;position=[pscustomobject]@{x=$c.x;z=$c.z}})} }
  'zone_rectangle' { return [pscustomobject]@{status='complete';changedCells=10} }
  'get_build_prefabs' { return [pscustomobject]@{prefabs=@(
    [pscustomobject]@{name='WindTurbine01';index=12694;version=1;kind='building';locked=$false},
    [pscustomobject]@{name='Small Road';index=16048;version=1;kind='network';locked=$false},
    [pscustomobject]@{name='Small Road Oneway';index=16049;version=1;kind='network';locked=$false},
    [pscustomobject]@{name='Hospital01';index=12577;version=1;kind='building';locked=$true})|Where-Object {$_.name -like "*$($Arguments.filter)*"}} }
  'get_tiles' { return [pscustomobject]@{tiles=@([pscustomobject]@{purchased=$true;polygon=@([pscustomobject]@{x=-100;z=-100},[pscustomobject]@{x=100;z=100})})} }
  'find_building_sites' { return [pscustomobject]@{candidates=@(
    [pscustomobject]@{position=[pscustomobject]@{x=500;z=0};rotation=0},   # outside owned tile
    [pscustomobject]@{position=[pscustomobject]@{x=10;z=0};rotation=90},
    [pscustomobject]@{position=[pscustomobject]@{x=20;z=0};rotation=180})} }
  'place_building' {
    if($Arguments.previewOnly -and $Arguments.position.x -eq 10){throw 'place_building failed: game_rejected_placement'+"`n"+'  HINT: The game refused this spot. Reasons: OverlapExisting. OverlapExisting = ...'}
    return [pscustomobject]@{status='complete';previewCost=25000;createdBuildings=@([pscustomobject]@{index=77;version=2})} }
  'sample_terrain' { return [pscustomobject]@{samples=@(@($Arguments.points)|ForEach-Object {[pscustomobject]@{position=[pscustomobject]@{x=$_.x;y=380;z=$_.z};waterDepth=$(if($_.z -gt 5000){12}else{0})}})} }
  'get_status' { return [pscustomobject]@{city=[pscustomobject]@{money=$script:FakeMoney;selectedSpeed=1}} }
  'batch_execute' { return [pscustomobject]@{status='complete';steps=@($Arguments.steps).Count;completed=@($Arguments.steps).Count;moneySpent=100} }
  default { throw "unexpected command $Command" }
 }
}

# --- names instead of IDs
Check ((Resolve-Zone 'residential').name -eq 'NA Residential Low') 'zone word "residential" picks the NA theme first'
$Region='EU'; Check ((Resolve-Zone 'residential').name -eq 'EU Residential Low') '-Region EU picks the EU theme'; $Region=''
Check ((Resolve-Zone 'industrial').index -eq 79) 'zone word "industrial" resolves'
Check (Throws {Resolve-Zone 'residential-high'} 'not usable yet') 'locked zone explains it is not usable yet'
Check ((Resolve-Road 'small').name -eq 'Small Road') 'road alias small -> Small Road (exact name beats prefix matches)'
Check ((Resolve-Prefab 'WindTurbine01' 'building').index -eq 12694) 'building resolved by exact name'
Check (Throws {Resolve-Prefab 'Hospital01' 'building'} 'LOCKED') 'locked building explains the lock'

# --- zone uses a live block anchor and tiles big areas
$script:Sent.Clear(); $Type='industrial'; $From='-720,995'; $To='20,1445'; $Preview=$false; $Json=$false
$out=Do-Zone
$zones=@($script:Sent|Where-Object command -eq 'zone_rectangle')
Check ($zones.Count -eq 6) 'large zoning request sends one zone_rectangle per tile'
Check (@($zones|Where-Object {$_.args.start.index -eq 500 -and $_.args.start.version -eq 3}).Count -eq 6) 'every tile is anchored to a live zone block'
Check (($out -join ' ') -match '60 cells zoned in 6 tiles') 'zone reports the total changed cells'

# --- place skips sites outside owned land and retries rejected ones
$script:Sent.Clear(); $script:OwnedCache=$null; $Name='WindTurbine01'; $At='0,0'; $Rotation=[double]::NaN; $Radius=[double]::NaN
$out=Do-Place
$previews=@($script:Sent|Where-Object {$_.command -eq 'place_building' -and $_.args.previewOnly})
$builds=@($script:Sent|Where-Object {$_.command -eq 'place_building' -and !$_.args.previewOnly})
Check (@($previews|Where-Object {$_.args.position.x -eq 500}).Count -eq 0) 'site outside owned tiles is never previewed'
Check ($previews.Count -eq 2 -and $builds.Count -eq 1 -and $builds[0].args.position.x -eq 20) 'rejected preview falls through to the next site, then builds once'
Check (($out -join ' ') -match 'id: 77:2') 'place reports the created building id'
$script:Sent.Clear(); $script:FakeMoney=60000
Check (Throws {Do-Place} 'less than the -Reserve') 'place refuses a build that would drop money below the reserve'
Check (@($script:Sent|Where-Object {$_.command -eq 'place_building' -and !$_.args.previewOnly}).Count -eq 0) 'nothing is built when the reserve would be broken'
$script:FakeMoney=1000000

# --- road builds one batch with split legs
$script:Sent.Clear(); $Type='small'; $Path=@('355,1240','-700,1240'); $Rest=@(); $From=''; $To=''
$null=Do-Road
$batch=@($script:Sent|Where-Object command -eq 'batch_execute')
Check ($batch.Count -eq 1 -and @($batch[0].args.steps).Count -eq 2) 'road sends a single batch with the split legs'
$script:Sent.Clear(); $Path=@('0,4900','0,5200')
Check (Throws {Do-Road} 'cross water') 'road over water is refused before building'
Check (@($script:Sent|Where-Object command -eq 'batch_execute').Count -eq 0) 'nothing is built when water is found'
$AllowWater=$true; $null=Do-Road; $AllowWater=$false
Check (@($script:Sent|Where-Object command -eq 'batch_execute').Count -eq 1) '-AllowWater builds the bridge anyway'

"$passed city.ps1 checks passed. No game commands sent."
