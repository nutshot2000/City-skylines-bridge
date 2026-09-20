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
