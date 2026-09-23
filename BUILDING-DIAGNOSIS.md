# Diagnose one building

Run this when one building has a warning or seems stalled. Copy its current placed-building index AND version from get_buildings or a previous inspection:

```powershell
pwsh -NoProfile -File ./coach.ps1 building -Index 123 -Version 1
```

123/1 is an example, not a usable ID. Do not pass a prefab, zoning block, or network node.

The helper makes at most three read requests: inspect the building, find its exact detailed row, and verify its road edge if one is reported. Existing bridge analysis may pause simulation. It does not construct, resume simulation, spend money, or retry a mutation.

Read the compact report in this order:

1. findings: measured shortfalls, recognised component issues, or construction presence.
2. utilities: wanted and delivered values. demand_fulfilled_at_snapshot describes only the sampled state; no_demand_unproven and unknown are not healthy badges.
3. road and connectionReferences: a live road reference does not prove a usable route or utility flow. A nearby node is not necessarily a connection.
4. unknown: missing row data, warning icons, construction progress and actual flow attribution remain explicit gaps.
5. nextAction and nextCommand: the next command is a read suggestion with this building's current IDs. It is never automatically executed.

Electricity falls back to serviceDataRaw on older bridge versions. If the matching detailed row is absent from the capped response, it reports partial evidence instead of picking another building. Session changes invalidate the combined report. Null consumer data can mean the component is absent or not exposed; it must not be called disconnected.

If the player's warning disagrees, inspect the same building and its visible notification. Do not invent a cause, claim perfect utilities, build speculative pipes or repeatedly advance simulation.
