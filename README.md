# Cities: Skylines II Agent Bridge kit

A toolkit that lets an AI agent play Cities: Skylines II through [Cities II Agent Bridge](https://github.com/FTPAiYT/cities2-agent-bridge-ndc): a patched mod plus PowerShell helpers. It lays roads, zones districts, places services, grows the city and diagnoses problems.

This repository contains the helpers and an optional patched mod you build yourself. It is not an MCP server. You need your own copy of Cities: Skylines II and PowerShell 7.5 or later. See [INSTALL.md](INSTALL.md).

## Start

Agents: read [AGENTS.md](AGENTS.md), then [START-HERE.md](START-HERE.md), then run:

```powershell
pwsh -NoProfile -File ./city.ps1 status
pwsh -NoProfile -File ./city.ps1 help
```

| Tool | Use it for |
|---|---|
| [city.ps1](city.ps1) | **Playing the game.** Easy verbs (`map`, `road`, `zone`, `place`, `grow`, `overview`, `buy`…) with names instead of IDs and readable output. |
| [COMMAND-REFERENCE.md](COMMAND-REFERENCE.md) | Every raw bridge command and its arguments. `city.ps1 raw` sends them. |
| [agent.ps1](agent.ps1) | Low-level: send one raw command, wait for completion, return JSON. |
| [coach.ps1](coach.ps1) | Careful utility diagnosis and node-to-node connection plans ([UTILITY-COACH.md](UTILITY-COACH.md)). |

## Included

- `city.ps1`, which splits long roads and big zoning rectangles for you, finds zone anchors, and tries road-side sites until the game accepts a building. It also stays inside the land you own and restores the game speed after each call.
- A patched mod (0.5.0-coach.1): reads no longer pause the game, milestones are exposed, zoning needs no block IDs, site search respects your land, locked assets say what unlocks them, and entry points are listed for new maps. See [FIXES.md](FIXES.md).
- Utility diagnosis that separates capacity, connection and actual delivery. Checkpoints, operation polling, and protection against accidentally replaying a command.

## Validation

Run the offline checks (no game needed):

```powershell
pwsh -NoProfile -File ./test-city.ps1
pwsh -NoProfile -File ./test-coach.ps1
pwsh -NoProfile -File ./test-client.ps1
```

The mod's own checks are in `mod/tests` (`dotnet run -p:GamePath=...`). [VALIDATION.md](VALIDATION.md) records what has been tested in-game and what hasn't.

No model API calls, Python, npm, credentials, game assemblies, saves or private city records are required or included.

## Upstream

`bridge-client.ps1` is derived from the client in [FTPAiYT/cities2-agent-bridge-ndc](https://github.com/FTPAiYT/cities2-agent-bridge-ndc), community release 0.4.2, with transport corrections. The mod source is also derived from that upstream package, and FIXES.md describes the changes. This repository does not claim ownership of upstream code or change its terms. The original mod is distributed separately by its author.
