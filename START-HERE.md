# Utility Coach for Cities II Agent Bridge

Give your agent this folder and ask it to read **AGENTS.md**, then run **doctor**. This is a separate helper kit; it does not replace the game mod or alter the original release package.

Requires Windows, PowerShell **7.5+**, and an already-working Cities II Agent Bridge mailbox. No Python, npm, API keys, model calls or extra packages. The supplied client fixes the timestamp parsing error observed with PowerShell 7.6. This does not fix or certify game-version compatibility.

From this folder:

```powershell
pwsh -NoProfile -File ./coach.ps1 doctor
pwsh -NoProfile -File ./coach.ps1 catalog -Filter Water
pwsh -NoProfile -File ./coach.ps1 catalog -Filter Sewage
pwsh -NoProfile -File ./coach.ps1 catalog -Filter Power
```

`doctor` gives a compact summary, issues and next steps. It excludes native map decorations and avoids the broken `get_services` endpoint. `catalog` intentionally lists common utility assets rather than every building containing “water.” It is a name-based convenience filter, not an exhaustive or authoritative capability classifier. If a modded asset is missing, discover it using the original bridge and inspect its details.

| Command | Purpose | Changes the city? |
|---|---|---|
| doctor | Utility evidence and prioritized next steps | May pause through normal bridge analysis behavior |
| catalog | Relevant prefab names, IDs and locks | May pause |
| inspect | Entity plus nearby nodes and named network edges | May pause |
| sites | Building requirements and geometric site candidates | May pause; not a native preview |
| building-plan | Save a proposed building placement | Only writes a local plan; may pause for discovery |
| connection-plan | Save a connection between two live nodes | Only writes a local plan; may pause for discovery |
| apply | Save checkpoint, submit once, wait for result | Yes; requires existing owner authorization and enabled controls |
| wait | Poll the original operation | No construction or retry |
| settle | At most one short simulation interval, then pause | Yes; normal simulation can spend money |

Plans expire after five minutes and belong to one city session. Each plan has a durable attempt record to prevent accidental replay even if its file is renamed. Keep `records/attempts` intact and use only one controlling agent. A plan is **not** a native approval. Native validation still runs when applying it.

## Practical sequence

1. Run `doctor` and identify one missing link.
2. Use `catalog` to copy an exact unlocked prefab name.
3. For a building, use `sites`; check source/shoreline/pollution requirements. For a connection, use `inspect` on the relevant building and match its nearby node IDs to named network edges.
4. Generate one plan with a maximum cost and reserve. Review its endpoint identities and utility layer.
5. If the user has already authorized this construction, run `apply` once. It saves a checkpoint and waits for completion.
6. Inspect the resulting entity and connection. Run `settle` once, then `doctor`. Stop if evidence remains unclear; do not build more speculative pipes.

See **UTILITY-RECIPES.md** for the actual electricity/water/sewage decision tree, and **COMMAND-EXAMPLES.ps1** for commands with explicit placeholders. Do not copy entity IDs from an old test or another save.

## Reading results

- `plan_only_no_construction`: a proposal exists; nothing was built.
- `queued` / `running`: not finished. Poll the same operation ID.
- `complete`: native operation completed. Utility delivery is still unproven.
- `failed` / `interrupted`: inspect before choosing a different action.
- `outcome_unknown`: do not repeat the command or delete its attempt record. Use the original ID and mailbox response.
- `inspection_only_supply_not_certified`: observation, never an all-clear badge.

Raw responses are retained locally under `records/`. They can contain city names and positions; nothing is uploaded. To recover from changes, load a verified checkpoint through the game's normal Load Game menu.

The last test deliberately left STOP latched. Reading a paused city still works. Resuming control requires renewed owner authorization, removal of only the STOP file and re-enabling Options → Cities II Agent Bridge → Allow local bridge controls after loading the city. The helper never does this automatically.
