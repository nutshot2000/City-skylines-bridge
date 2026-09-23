# Start here: one useful action, then report

Use PowerShell 7.5 or later. Run commands from this kit folder. Prefer the helpers; do not write a new bridge client or scan raw game files.

1. Say what you are checking. Run `pwsh -NoProfile -File ./coach.ps1 brief` once.
2. Choose ONE branch below. Spend at most six helper calls or 45 seconds before giving the user a progress reply. A reply must say what was learned and what is still blocked.
3. Submit at most one planned change, inspect it, then run `settle` once if needed. Report the evidence. Do not keep experimenting silently.

These are agent instructions, not a guarantee that a third-party model will comply. Helpers bound each wait and print progress; they cannot make a model send a chat reply.

| Situation | Next action | Stop condition |
|---|---|---|
| No residents or no buildings grow | `coach.ps1 zones`; use `usable:true`, then verify outside access | Zero matching growables means the zone cannot spawn buildings. Do not diagnose this by building more pipes. |
| Unsure where existing roads/power are | `coach.ps1 nearby -X <current x> -Z <current z>` | This searches the whole map once. Own roads may be listed. Candidates are not proof of ownership or supply. |
| Need outside road access | `coach.ps1 outside -Index <road node> -Version <node version>` | Physical connectivity is not directional routing. No existing path does not mean a nearby highway cannot be connected. |
| Water/power/sewage trouble | `coach.ps1 doctor`, then `inspect` on ONE affected building | Establish source → correct network → consumer. Capacity and proximity are not delivery. |
| Tool refuses new placement | `agent.ps1 -Command get_tool_status` | Poll active work. If stranded, use `cancel_tool` once and inspect; cancellation is not rollback. |
| Work still pending | Follow returned poll command and original ID once | Never resubmit construction. If still pending, tell the user. |
| Same failure twice | Stop and report the error and attempted geometry | No coordinate sweeps, guessing IDs, extra simulation loops or repeated identical commands. |

## Zoning that can grow

Run `coach.ps1 zones`. Copy a usable zone's current index/version, with the intended regional theme. Generic names may have zero growables; the DLL now rejects those zones. Do not manually place growable houses or shops: the game may condemn them. Zone land and let simulation spawn them.

Query `get_zone_cells` for a small area. Copy the relevant block's index/version into the `start` point, together with x/z. A rectangle follows native block/tool geometry, not a guaranteed world-axis rectangle. Send `zone_rectangle` with `previewOnly:true` through agent.ps1 first. Examine `previewCells` before applying the same bounds without previewOnly. Keep the camera and block unchanged. Preview does not reserve cells; inspect changed cells afterward.

## Pipes without blind retries

Existing attached nodes use their own absolute height. Set elevation to zero, but this alone does not guarantee correct native burial: the game can lower a pipe again. The DLL now rejects a preview that loses a requested node identity or moves its endpoint by more than one metre. This prevents that disconnected placement; it does not automatically solve the native snapping fault. Inspect layers and actual building connectors, or ask for a manual connection when blocked twice. Do not strip node IDs just to bypass the check.

`get_network` flags orphan nodes (`liveDegree:0`). Avoid assuming an orphan is a working utility connection. Do not delete arbitrary nodes: inspect live edges and retain the user's city.

Water needs a working pump/tower, sewage needs a working outlet/treatment facility, and both need actual consumer connections. A pipe through a building centre worked in one test; it is not a universal connector rule. Keep polluting plants away from homes and sewage away from drinking-water intakes; inspect native placement and pollution evidence.

## Responses and time budget

`agent.ps1` normally waits ten seconds, polls once per second and prints progress every five seconds while polling. A transport request may separately take up to fifteen seconds, so the total is not a strict ten-second end-to-end deadline. Native menus can suspend processing: return to the city rather than queue more work.

`pending_do_not_resubmit` means poll the supplied ID. `stagnant_no_progress` means stop simulation experiments. `tool_busy` means inspect/cancel the tool. `invalid_zone` means discover usable zones. Null/missing results are errors, never success. Raw responses are saved in records; do not reread all history or dump huge terrain/zoning arrays into chat.

## Housing palette stays open after zoning

The panel with house icons and regional/theme buttons is the zoning palette. In the live reproduction, four cells were successfully assigned NA Residential Low, the operation finished, and the native tool returned to default while this panel remained visible. Simulation advanced 312 frames with it still open. It was not blocking confirmation.

After zoning, inspect changedCells and the actual cell zones. For non-preview completion, run one authorized settle interval instead of waiting for growth while paused. The palette can be closed with its X; selecting another house icon changes the tool choice, not confirmation of the completed zoning. Do not click randomly. This observation does not prove what happened in every older agent session, especially one that selected a generic zone with zero growables.

## Read status without pausing

Use `coach.ps1 status` while observing a running city. It returns city/tool status without changing speed. Doctor and detailed analysis still pause. A missing electricity connection object does not mean a consumer has no power: read electricityDemand wanted/fulfilled values. A missing consumer value means unknown, not zero.

If settle stops after three stagnant steps, reassess the evidence and change the plan if needed. `settle -Reassessed` acknowledges that review for one bounded interval; never automatically loop it. UI warning disagreement remains unresolved until the same building and simulation timing are compared.

Locked clinic/cemetery or progression questions: read PROGRESSION.md. Use coach.ps1 unlocks and catalog -All. A short flat simulation interval does not establish a permanent growth blocker.

For one building's warnings or construction trouble, use coach.ps1 building -Index CURRENT_BUILDING_INDEX -Version CURRENT_VERSION. Read BUILDING-DIAGNOSIS.md; do not start a broad command hunt.

Resident sidebar comments: coach.ps1 chirper -Limit 20, with DLL 0.4.7 or newer. Read CHIRPER.md before acting on posts.
