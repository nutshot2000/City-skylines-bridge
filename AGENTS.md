# Instructions for the agent using this kit

Your job is to establish and verify one utility chain at a time. Do not invent prefab IDs, entity IDs, coordinates, unlocks, available funds or a successful result.

1. Read FAST-START.md. Run `coach.ps1 brief` first. Use at most six helper calls or 45 seconds before replying with progress. Stop after two identical failures; do not silently loop. Read UTILITY-RECIPES.md only for the relevant utility chain.
2. Preserve the owner's city and scope. Helpers do not authorize gameplay. Never restart the game, bypass compatibility checks, clear STOP, demolish existing assets or import a new save without the appropriate user authorization. Do not repeatedly ask when the owner has already authorized the scoped work.
3. Use exactly one controlling agent. Run no other bridge mutations concurrently.
4. Work paused. Queries may pause the game. During `settle`, let its status polling finish; do not run other analysis commands.
5. A building ID is NOT a pipe node ID. A prefab ID is NOT a placed building ID. Match the current index AND version. Inspect connection edge/node references and nearby named networks.
6. Do not treat a transformer's existence, a road connection, a pipe's visual proximity, aggregate capacity, empty shortage lists or zero demand as proof of delivery.
7. Prepare one bounded plan. If scope permits, apply once and wait for the result. Then inspect the result before any further construction. Use positive maxCost and a meaningful reserve.
8. If a request times out, do not repeat it. Keep the attempt record. Recover the original response/operation ID. `coach.ps1 wait -OperationId ...` polls construction without resubmitting.
9. Never delete or relocate attempt records to bypass replay protection. An attempt blocked before construction is still inspect-first, not permission to blindly regenerate and apply a duplicate.
10. If get_services fails, use doctor/get_city_diagnostics/get_buildings; do not keep retrying it. If diagnostics is unavailable, explicitly report incomplete evidence.
11. After one successful change, settle once and inspect. If no demand or too little time elapsed, say “supply not yet proven.” Do not loop simulation or random placement automatically.
12. Report four facts: what was built, what connection was verified, whether actual supply was observed, and the next unresolved issue. Keep infrastructure claims separate from simulation success.

Original package rules still apply. This kit is an optional convenience layer, not an autonomous city builder.
