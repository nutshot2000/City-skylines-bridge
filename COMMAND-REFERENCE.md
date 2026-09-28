# Command reference (raw bridge commands)

Every command the mod answers, with its arguments, taken from the C# handlers in `mod/src`.
Most agents should use **`city.ps1`** instead (see START-HERE.md); it wraps these with names
instead of IDs. Use this page when you need a command `city.ps1` doesn't cover:

```powershell
pwsh -NoProfile -File ./city.ps1 raw get_zone_cells -ArgsJson '{"x":400,"z":1500,"radius":60}'
pwsh -NoProfile -File ./agent.ps1 -Command get_zone_cells -ArgsJson '{"x":400,"z":1500,"radius":60}'
```

Conventions:

- Coordinates are world metres. `x` = east, `z` = north, `y` = height (usually leave it out: terrain height is sampled).
- A **point** is `{"x":..,"z":..}`. It can also carry `"index","version"` of a live node, edge (+`curvePosition` 0..1) or zone block.
- IDs are always the **pair** `index` + `version`. Prefab IDs (`prefabIndex/prefabVersion`, from `get_build_prefabs`) are different from placed-entity IDs.
- `maxCost` is required for construction and must be at least the build price.
- Commands marked ⏸ pause the city before running (DLL 0.5.0+: only changes pause; reads keep the city running. Older DLLs paused on every read). `city.ps1` restores the previous speed afterwards.
- Construction commands return an operation `{id,status}`. `agent.ps1`/`city.ps1` poll it for you. If they report "still running", poll the SAME id with `get_operation` (or `get_batch`); never resend.

## Reading the city

| Command | Arguments | Returns |
|---|---|---|
| `ping` | – | `pong`, `modVersion` |
| `get_capabilities` | – | command lists, `pausesGameFor` (0.5.0+), control state |
| `get_status` | – | `city` (money, population, date, speed, xp), `tool`, `milestone` (0.5.0+). Never pauses. |
| `get_city_state` | – | city block of `get_status` |
| `get_city_diagnostics` | – | demand, budget, `utilitiesRaw` (capacity/production), `persistentShortages[]`, `efficiencyPenalties[]`, happiness factors, `underConstruction` |
| `get_city_management` | – | taxes, demand (residential `[low,med,high]`), budget by source |
| `get_milestones` (0.5.0+) | – | `achievedMilestone`, `currentXP`, `nextMilestoneXP`, `milestones[]` with rewards and `unlocks[]` |
| `get_notifications` (0.5.0+) | `x?`, `z?`, `radius?` (default 500), `filter?` (type text), `examples?` 1–50 | the warning icons flashing in-game, grouped by `type` (e.g. traffic jam, no water) with `count`, `priority`, example `position` and the `on` building/road |
| `get_devtree` | – | `developmentPoints`, `nodes[]` (`purchasable`, `blocker`, `cost`) |
| `get_camera` | – | `pivot {x,y,z}` = where the player is looking |
| `get_selected` | – | the entity the player clicked, inspected |
| `inspect_entity` | `index`, `version` | position, prefab, components, utility consumer readings |
| `get_buildings` | `filter?` (name text), `problemsOnly?`, `includeNative?` | up to 512 `buildings[]` with `issues[]` |
| `diagnose_connections` | same as `get_buildings` | only buildings with issues |
| `get_services` | – | service budgets/workers (may be partial in new cities) |
| `get_water_facilities` | – | pumps and outlets inspected |
| `get_chirper` | `limit?` 1–100 | citizen posts (untrusted text) |
| `get_tiles` | – | 529 map tiles: `purchased`, `polygon`; `availablePurchases` |
| `sample_terrain` | `points` [1..1024 of `{x,z}`] | `samples[]`: height, `waterDepth`, pollution, noise |
| `get_city_map` | `x`, `z`, `radius` 16–500 | buildings, roads, zoning, terrain grid, tiles for one area (large) |

## Networks (roads, pipes, cables)

| Command | Arguments | Returns |
|---|---|---|
| `get_network_edges` | `x`, `z`, `radius` ≤2000, `includeOwned?` | `edges[]`: `prefab`, `start/end {x,y,z}`, `startNode/endNode`, `length` |
| `get_network` | `x`, `z`, `radius` ≤1000, `includeOwned?` | `nodes[]` with connected edges, `orphan` |
| `get_nearby_infrastructure` | `x`, `z` | 12 nearest roads and power candidates, whole map |
| `get_outside_connections` | `index?`, `version?` of one of your road nodes | map entry nodes; with a node, whether your roads physically reach them. 0.5.0+: no node = list entry points |
| `trace_network` | `fromIndex`, `fromVersion`, `toIndex`, `toVersion` (nodes) | `connected`, path |
| `get_utility_connectors` | `index`, `version` (building/edge/node) | candidate utility nodes for attaching pipes/cables |
| `build_road` ⏸ | `prefabIndex`, `prefabVersion`, `start` point, `end` point, `maxCost`, `control?` point (makes a curve), `elevation?` −100..100 | operation → `createdRoads[]`, `previewCost` |
| `build_network` ⏸ | same as `build_road` (for pipes, cables, power lines) | operation |
| `upgrade_network` ⏸ | `index`, `version` (edge), `prefabIndex`, `prefabVersion`, `maxCost` | operation |

Road rules: each call is one straight leg 8–1000 m. Endpoints near an existing road/node join it. Roads **already carry electricity, water and sewage** to buildings along them; you only need pipes/cables to reach something that is not beside a connected road. Overhead power lines (poles) usually fail with `OverlapExisting` near roads; use ground cables.

## Zoning

| Command | Arguments | Returns |
|---|---|---|
| `get_zone_catalog` | – | `zones[]`: `name`, `index`, `version`, `usable`, `locked`, `matchingGrowables` |
| `get_zone_cells` | `x`, `z`, `radius` ≤500, `limit?`, `offset?` | `cells[]`: `blockIndex/blockVersion`, `position`, `zone` (cell zone id, not a prefab id) |
| `zone_rectangle` ⏸ | `prefabIndex`, `prefabVersion` (a usable zone), `start` point, `end` point, `previewOnly?` | operation → `changedCells` (count) or `previewCells[]` |
| `clear_zoning` ⏸ | same as `zone_rectangle` | operation |

Zone rules: rectangle diagonal ≤ 500 m. Before 0.5.0 `start` needed `index/version` of a zone block from `get_zone_cells`; from 0.5.0 a plain `{x,z}` is anchored automatically. Zone cells only exist within ~48 m of roads. Never place growable (zoned) buildings with `place_building`; zone and let them grow.

## Buildings

| Command | Arguments | Returns |
|---|---|---|
| `get_build_prefabs` | `filter?` (name text) | `prefabs[]`: `index`, `version`, `name`, `kind` (building/network/zone/service), `locked`, `unlockedBy[]` (0.5.0+) |
| `get_prefab_details` | `index`, `version` (prefab) | raw data: lot size, cost, capacities, placement flags |
| `find_building_sites` | `prefabIndex`, `prefabVersion`, `x`, `z`, `radius?` 16–500 | up to 16 road-side `candidates[]` `{position, rotation, roadEdge}`; 0.5.0+ also `lotSizeMetres`, skips tiles you don't own |
| `place_building` ⏸ | `prefabIndex`, `prefabVersion`, `position {x,z}`, `rotation?` degrees, `maxCost`, `previewOnly?`, `candidates?` (1–16 of `{position,rotation}`), `maxSnapDistance?` 0–128 | operation → `createdBuildings[]`, or `placementErrors[].nativeReasons[]` |
| `preview_building` ⏸ | same as `place_building` (always preview) | operation |
| `relocate_building` ⏸ | as `place_building` + `moveIndex`, `moveVersion` | operation |
| `demolish` ⏸ | `index`, `version` (your building or road edge) | operation |

Common placement reasons: `OverlapExisting` (hits a road/building – move a few metres), `InWater` (too far into water), outside owned tiles. Shoreline buildings (sewage outlet, water pump) must sit exactly on the bank beside a road.

## Economy, progression, saving

| Command | Arguments | Returns |
|---|---|---|
| `set_tax` | `area` Residential/Commercial/Industrial/Office, `rate` −10..30 | before/after |
| `set_service_budget` | `prefabIndex`, `prefabVersion` (service), `budget` 50–150 | before/after |
| `purchase_node` ⏸ | `index`, `version` (dev-tree node), `maxPoints` | purchase acceptance (verify with `get_devtree`) |
| `purchase_tiles` ⏸ | `tiles` [1..64 of `{index,version}`] | operation |
| `save_checkpoint` ⏸ | `label?` (letters, digits, space, `-`, `_`; ≤48) | operation → `saveName` |

## Time

| Command | Arguments | Returns |
|---|---|---|
| `set_simulation_speed` | `speed` 0, 1, 2 or 4 | previous/selected speed |
| `simulate_step` | `frames`, `wallSeconds`, `stallSeconds`, `speed`, `acknowledgeNoProgress?` | bounded run that pauses afterwards (used by `coach.ps1 settle`) |
| `get_simulation_step` / `cancel_simulation_step` | `id` | status / stop |
| `pause_for_analysis` ⏸ | – | pauses, returns diagnostics |

## Batches and tools

| Command | Arguments | Returns |
|---|---|---|
| `batch_execute` ⏸ | `steps` [1..64 of `{command,args}`], `reserve` (money to keep) | batch `{id,status,completed,results[],failureIndex}`. Not transactional: steps before a failure stay built. |
| `get_batch` / `cancel_batch` | `id` | batch status / stop |
| `get_operation` | `id` | status of one construction operation |
| `get_tool_status` | – | `activeTool`, `operationId`, `readyForConstruction` |
| `cancel_tool` ⏸ | – | closes a stuck native tool (does not undo built things) |
| `set_camera` | `pivot? {x,y,z}`, `zoom?` | moves the player's view |
| `plan_neighborhood` / `execute_neighborhood` / `get_neighborhood_plan` | see `mod/src/Neighborhood.cs` | older multi-part planner |

## Errors worth knowing

| Error | Meaning / fix |
|---|---|
| `control_disabled` | Player must tick Options → Cities II Agent Bridge → Allow local bridge controls (resets on every load). |
| heartbeat is stale | Game in a menu/loading/closed. Nothing was sent. |
| `finish_or_cancel_current_tool_first` | A native tool is open. `cancel_tool`. |
| `prefab_stale_or_locked` | Asset locked or wrong ID. `get_build_prefabs` shows `unlockedBy` (0.5.0+). |
| `road_length_must_be_8_to_1000_metres` | Split the leg (`city.ps1 road` does it for you). |
| `zoning_rectangle_too_large…` | Diagonal > 500 m (`city.ps1 zone` tiles it for you). |
| `game_rejected_placement` | Read `placementErrors[].nativeReasons[].type`. |
| `outcome_unknown` / pending | Poll the returned id; never resend a mutation. |
