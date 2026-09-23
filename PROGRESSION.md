# Progression: XP is not spendable points

Read this before diagnosing a locked building. Do not inspect game assemblies or guess IDs during routine play.

1. Run `pwsh -NoProfile -File ./coach.ps1 unlocks`. This is a non-pausing query on DLL 0.4.6-coach.1 or later. `cityXp` measures milestone progress; `developmentPoints` is the spendable balance. Never substitute one for the other.
2. Find the intended building with `coach.ps1 catalog -All -Filter Cemetery` (or another observed name). The default catalog covers utilities only; empty results there say nothing about other services.
3. Choose the relevant development node by its returned name and eligibility. Copy its index AND version from unlocks. A building prefab index is not a development-node index. If the relation between a node and your building is unclear, inspect the game's progression screen instead of guessing.
4. Only when spending points is within the owner's authorized plan, save a checkpoint and submit `purchase_node` once with the node's index, version and `maxPoints` (your approved cost ceiling). Example shape, with placeholders requiring replacement:

```json
{"index":123,"version":1,"maxPoints":1}
```

5. An accepted response is pending, not proof of an unlock. Read unlocks again: the node must be unlocked and its purchase status unlock_verified. If still pending, run ONE authorized `coach.ps1 settle` interval, then read unlocks again. If the stagnant guard is active, reassess before using `settle -Reassessed`. Do not repeatedly purchase or simulate.
6. Query the exact building again and verify locked:false before placing it. Unlocking a node does not prove every building in its service is available. If blocked, report the specific gate and stop guessing.

## Reading eligibility

- already unlocked: do not buy again.
- insufficient development points: XP does not pay this cost.
- service gate locked: progression/service eligibility must be satisfied first; no bypass is provided.
- prerequisite locked: this installed game's native rule accepts any unlocked non-null listed prerequisite, or none when no prerequisite exists.
- pending purchase: do not replay. The current session retains attempts even if the native call throws; inspect the original response and current locks. After a reload, rediscover all IDs and reconcile points/locks before any new action.

The service field is an eligibility gate. It is not a guaranteed list of buildings unlocked by the node. The bridge does not grant XP, set development points or force unlocks. Purchases may wait for normal game updates; the helper does not automatically run simulation or spend additional points.

## Avoid unsupported diagnoses

A short settle with no population/XP change means no change was observed in that interval. It does not prove a permanent growth block. Zero recognised shortages is not proof of every utility chain. Do not blame death care, happiness or jobs without demand-factor or building evidence. Offices are not guaranteed to add revenue without additional service load. Report what is measured separately from a hypothesis.
