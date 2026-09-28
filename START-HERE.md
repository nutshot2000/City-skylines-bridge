# Start here: play Cities: Skylines II with `city.ps1`

`city.ps1` is the easy front door to the bridge. One verb per call, short readable output, names instead of IDs, and the game clock is put back after every call. You do not need to read the rest of the kit to build a working city.

```powershell
pwsh -NoProfile -File ./city.ps1 help          # all verbs
pwsh -NoProfile -File ./city.ps1 help zone     # one verb, with examples
```

Coordinates are world metres written `x,z`: `x` grows east, `z` grows north. Heights are handled for you.

## Before the first command

- The game is running with a city loaded, and not sitting in a menu.
- The player has ticked **Options → Cities II Agent Bridge → Allow local bridge controls**. This resets every time a city is loaded. `status` shows `controls=ON`.
- `city.ps1 status` answers. If it says the heartbeat is stale, the game is in a menu or loading.

## A first city in ten commands

This is the sequence that built Klanka Canyon, from an empty map to 1,000+ residents with zero shortages:

```powershell
./city.ps1 status                                   # money, population, speed, controls
./city.ps1 map -Radius 900                          # where is land, water, your roads? (# = your land)
./city.ps1 roads                                    # the starter road the map gives you (already joined to the highway)
./city.ps1 powerlink                                # if the map's pylons end on your land: transformer there = import power now, sell surplus later
./city.ps1 road -Path '473,1343' '473,1643' -Type medium            # a spine off the starter road
./city.ps1 road -Path '273,1443' '673,1443' -Type small             # cross streets ~100 m apart
./city.ps1 zone -Type residential -From 280,1395 -To 400,1692       # homes either side of the streets
./city.ps1 zone -Type commercial  -From 408,1346 -To 540,1692       # shops along the spine
./city.ps1 place -Name WindTurbine01  -At 470,1950                  # power
./city.ps1 place -Name WaterTower01   -At 470,1740                  # water (groundwater)
./city.ps1 place -Name SewageOutlet01 -At 515,2140 -Rotation 180    # sewage, on a shoreline
./city.ps1 grow -Seconds 120 -Speed 4                               # let it grow
./city.ps1 overview                                                 # what does the city need next?
./city.ps1 happiness                                                # what citizens like/dislike (crime, entertainment, pollution...) and what to build
./city.ps1 problems                                                 # the warning icons flashing in-game (traffic jams, no water...)
./city.ps1 cleanup                                                  # after a tornado/fire: clear destroyed and abandoned buildings so lots regrow
```

After that, repeat: `overview` → do the top item in NEXT → `grow` → `overview`.

## Rules that save you hours

1. **Roads carry power, water and sewage.** (Exception: big power plants such as SmallCoalPowerPlant01 output HIGH voltage. Place a `TransformerStation01` beside the plant and run `city.ps1 link -From <plant> -To <transformer>`. Keep the plant ~30 m inside your land edge so the line's pylons fit. Wind turbines need nothing extra. The map's pre-built pylons ending near your land are an outside power connection. Place a TransformerStation01 right beside the end pylon (it snaps on) to sell surplus electricity and import when short. Klanka Canyon earned ~$37k/month from this.) A generator, water source and sewage outlet placed beside roads that connect to your streets supply every building on that road network. You do **not** need to lay pipes or cables along streets. Only lay them (`road -Type power|water|sewage`) to reach something that isn't beside a connected road.
2. **Zone, don't place, houses and shops.** Zoning is free. Buildings grow by themselves while the game runs. `place` is for services and utilities only.
3. **Zone cells only exist within ~48 m of a road.** Space parallel streets about 100 m apart so both sides get full-depth lots. `zone` splits big rectangles for you.
4. **Reserve land for services before you zone.** A clinic needs about 88×48 m, a school more, and a cemetery 128×200 m. Once houses fill the road-sides, `place` has nowhere to go. Leave one block unzoned per district, or run a short dead-end road into empty land (`road`, then `place` beside it).
5. **Keep industry away from homes: 500 m or more, and more for coal plants.** Air pollution spreads across the map with the wind. In Klanka Canyon, homes 200 m from an industrial zone ended up with 98 air-pollution warnings and many sick workers once industry and two coal plants had grown. Put industry on the far side of the highway or map edge, keep sewage outlets away from water intakes, and prefer wind power near housing.
6. **Raw sewage outlets are a stopgap.** They dump untreated sewage and leave a brown plume in the lake. Buy WaterTreatmentPlantNode (2 points) early and place `WastewaterTreatmentPlant01` ($400k, 400k capacity, halves pollution). It needs no shoreline, so put it on dry land far from homes, then demolish the raw outlets. **Shoreline buildings sit exactly on the bank.** Sewage outlets and water pumps say `InWater` if they are too far out and `OverlapExisting` if they are on the road. Build a road a few metres from the water, then try `place` a few metres apart, or give an exact `-At` with `-Rotation`.
7. **Demand for locked zones means grow.** `overview` tells you when demand is for medium or high density or for offices that aren't unlocked yet. Keep growing low density until the next milestone (`status`, or `milestones` with DLL 0.5.0+).
8. **Services unlock with milestones and development points.** `find <word> -All` shows what is locked. `unlocks` lists development-tree nodes you can buy now, and `buy <NodeName>` spends the points.
9. **Money:** services are expensive (a post office is $250k, a telecom tower $125k, a hospital $1.9M). Every map tile you buy also adds monthly upkeep (Klanka Canyon paid ~$146k/month for 17 tiles), so buy land when you will use it. `place` and `road` refuse to spend below a cash reserve (`-Reserve`, default 50,000), so the city can always pay upkeep. Early service upkeep makes the budget negative. It turns positive as population grows. Small tax nudges (`tax -Type Residential -Rate 12`) are fine.
10. **Never resend a construction command that reported "still running".** Poll the id it gave you.
11. **Plan for traffic early.** Build the district's main through-roads as `medium` from the start, give every district two ways out (not one spine), and add a second highway link once the city passes ~1,500 people. Join only ONE carriageway (a T-junction onto the one-way side flowing the way you want). Never cross both carriageways at grade: that puts a stop on the highway and jams it. Don't put services right beside a road you may need to widen: `upgrade` fails with `OverlapExisting` when a building is in the way. `problems` shows where "Traffic Bottleneck" icons are; widen with `upgrade -Path x,z -Type medium|large`. Large roads need the LargeRoadsNode development node (`unlocks -Filter LargeRoads`).
12. **Don't build roads over water** unless you want a costly bridge. `road` refuses automatically; pass `-AllowWater` to override. It also refuses to cross a highway at grade (`-AllowHighway` overrides).

## When something fails

`city.ps1` prints `ERROR:` plus a `HINT:` line with the usual fix. The common ones:

| Message | Do this |
|---|---|
| controls OFF / `control_disabled` | Ask the player to tick the option again (it resets on load). |
| heartbeat is stale | The game is in a menu or loading. Ask the player to return to the city. |
| No free road-side site | Build a short dead-end road into empty, unzoned land you own, then `place` next to it. |
| `OverlapExisting` | Move `-At` 10–20 m away from roads and buildings, or let `place` pick (omit `-Rotation`). |
| `InWater` | Move toward land. |
| zone type not usable yet | It's locked. `zones` lists what you can paint. |

## More depth

- `city.ps1 raw <command> -ArgsJson '{...}'` sends any bridge command. See [COMMAND-REFERENCE.md](COMMAND-REFERENCE.md) for every command and argument.
- `coach.ps1` and [UTILITY-COACH.md](UTILITY-COACH.md) are the careful, evidence-first workflow for diagnosing a broken utility chain (connectors, node-to-node pipes, settle and doctor).
- `agent.ps1` is the low-level "send once and wait" wrapper that `city.ps1` uses.
