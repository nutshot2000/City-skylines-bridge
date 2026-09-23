# Commands without guesswork

Prefer `agent.ps1 -Command COMMAND -ArgsFile arguments.json` when a command can queue work. It submits once, polls the correct operation/batch/simulation ID, and returns a terminal result or a precise pending-ID instruction. `-WaitSeconds` defaults to 10 and is capped at 60 per invocation; resume waiting on the returned ID, never repeat the initiating command.

The transport's `-TimeoutSeconds` (1–45, default 15) is a **request dispatch/response deadline**, not a construction deadline. A batch may take up to 600 seconds. Expired requests stay rejected, including reads; expiry is not an excuse to execute stale commands later.

## Canonical response keys

Raw `bridge.ps1` responses have `{ok,result,error}`. The convenience `agent.ps1` returns `{status,result,note}` after polling. Failed/interrupted operations are not successful just because the original envelope had `ok:true`.

| Command | Result fields |
|---|---|
| sample_terrain | `samples[]` (input is `points[]`); auto-chunked responses also include `chunked` and `chunks` |
| get_network_edges | `edges[].prefab`, `startNode`, `endNode`, `length`, `curve` |
| get_buildings | `buildings[].prefab`, `index`, `version`, `position`, connections and issues |
| get_batch | `id`, `status`, `completed`, `results[]`, `failedStep` when failed |
| get_operation | `id`, `kind`, `status`, command-specific result/error |
| get_services | Patched mod: `services[]`, with per-row `partial` and `fieldErrors`; unavailable fields are null |
| get_outside_connections | Patched mod: `status`, `outsideRoadNodes[]`, `connectedCount`, `visitedRoadNodes`, `truncated` |

The patched mod adds `prefabName` aliases to entity/edge outputs and `completedCount`/`failureIndex` aliases to batch outputs. Original keys remain intact. A batch failure index is zero-based; it is null when no step failure is recorded. The agent wrapper also adds batch aliases for older binaries.

## Payload size

Each raw UTF-8 request is capped at **16,384 bytes**, including its envelope. The fixed client compresses JSON and checks the byte length BEFORE writing it. Large terrain queries (up to 1,024 points per helper invocation) are automatically split into batches of at most 32 points and recombined in order. Oversized individual packets still fail explicitly. Split other large operations into reviewed sequential steps; never divide mutations and replay them automatically after failure.

## Outside road access

Get a current road node from `coach.ps1 inspect`. With the patched mod:

```powershell
pwsh -NoProfile -File ./coach.ps1 outside -Index LIVE_ROAD_NODE -Version LIVE_VERSION
```

This searches the entire map's outside road nodes and traverses the road graph from the supplied node. It is not limited to the camera. `physical_path_found` does not prove lane direction, vehicle routability or actual immigration. `no_physical_path` is only returned when outside road nodes were found and the traversal was not truncated. `unknown` is not a reason to keep simulating blindly.

## Native placement errors

Patched construction results include `placementErrors[].nativeReasons` from native error-icon data when available, plus `reasonAvailable`. Empty reasons mean the specific cause is unavailable; do not label the rejection a terrain, shoreline or UI-assets fault without evidence. The watchdog already bounds responsive native construction, but no main-thread callback can recover a completely hung game thread.

## Coach 0.4.4 additions

- get_zone_catalog: zones with current index/version, matchingGrowables, locked and usable. A usable asset is not a growth guarantee.
- zone_rectangle: start must include current zone block index/version. previewOnly:true returns native previewCells without applying. Generic zones without matching growables are rejected.
- get_tool_status: activeTool, operationId, simulationRunning, batchRunning, readyForConstruction. Does not interrupt simulation.
- cancel_tool: requires controls; cancels the native tool, not already applied city changes. Running simulation/batch must use their own cancellation commands.
- get_nearby_infrastructure: x,z required; up to 12 nearest road and 12 power-name candidates across the map, ranked by endpoint distance. Does not prove tile ownership, external supply, or connectivity.
- get_network: liveDegree and orphan supplement node edges.
- get_simulation_step: retains earlier step IDs for the current city session.

Use FAST-START.md for the bounded workflow and recovery table.

## 0.4.5 diagnostic improvements

Use `pwsh -NoProfile -File ./coach.ps1 status` for one non-pausing city/tool snapshot (`get_status`). It does not collect detailed shortages; use doctor for that, which still pauses analysis. No automatic resume occurs.

Consumer electricity appears as `electricityConsumer` in inspect/get_buildings, and `electricityDemand` in doctor: wantedConsumption, fulfilledConsumption, cooldown and snapshot status. Null is unavailable data, not proof of disconnection. Water remains waterConsumer/waterDemand. underConstruction indicates presence, not progress percentage.

Network edges now expose `start` and `end` coordinates as well as the original four-point `curve`. inspect_entity exposes edge geometry and endpoint node IDs. The nearest node is still not proof of a building's actual utility connection.

get_buildings/diagnose_connections exclude native map decorations by default; use includeNative:true if required. diagnose remains problems-only. `no_recognised_issue_not_certified` and response meaning explain its limited checks. UI notification reasons are not yet captured.

After reassessing a stagnant simulation, `coach.ps1 settle -Reassessed` explicitly acknowledges that review and runs one bounded interval. Do not use it in an automatic retry loop.

preview_building takes the same arguments as place_building, with a `position` object (not `point`) and maxCost. Replace the placeholder IDs/coordinates with discovered values:

```json
{"prefabIndex":123,"prefabVersion":1,"position":{"x":100,"z":200},"rotation":0,"maxCost":10000}
```

Zoning catalog uses index/version as prefab identity; it has no zoneId field. Cell zone values are a different namespace. Use matchingGrowables and usable when choosing the prefab.

## Consistent helper guidance

agent.ps1 and coach.ps1 add a guidance object while preserving existing result/status fields. guidance.outcome is completed, still_running, needs_input, failed or unknown. Completed means the request completed, not verified gameplay success. Unmapped states remain unknown.

guidance.nextAction explains what to inspect or supply. When a concrete next read is known, nextCommand includes script, command and args; pending operations retain their original ID. Suggestions are not executed automatically. retryOriginal is always false: fix preconditions and inspect evidence before choosing a new action. Errors after application or missing results remain uncertain.

Keep response-guide.ps1 beside the helper scripts. This helper-only update requires no game restart; the separate 0.4.5 DLL upgrade still requires installation while the game is closed.
