# Cities: Skylines II Utility Coach

A practical helper kit for AI agents using [Cities II Agent Bridge](https://github.com/FTPAiYT/cities2-agent-bridge-ndc). It turns low-level utility commands into compact diagnostics, checked plans, and clear next steps.

This repository includes the helper kit and an optional patched mod source build. It is not an MCP server. You need your own installed Cities: Skylines II and PowerShell 7.5 or later. See [INSTALL.md](INSTALL.md) for the fixed entry points and mod installation.

## Start

Use [agent.ps1](agent.ps1) to submit once and automatically wait for completion. See [COMMANDS.md](COMMANDS.md) for exact result keys and the whole-map outside-road check. Read [FAST-START.md](FAST-START.md) for bounded steps and recovery. Agents should first read [AGENTS.md](AGENTS.md), then run:

```powershell
pwsh -NoProfile -File ./coach.ps1 brief
```

## Included

- Utility diagnosis that distinguishes capacity, connection, and actual delivery.
- Filtered utility asset discovery and inspection of nearby network nodes.
- Building and node-to-node connection plans with spending limits and reserves.
- Checkpoint creation, operation polling, and durable duplicate-attempt protection.
- [Electricity, water, and sewage recipes](UTILITY-RECIPES.md).
- [Command examples](COMMAND-EXAMPLES.ps1) with explicit placeholders.

The helper never clears STOP or turns game controls on. Plans do not construct anything until explicitly applied within the owner's authorized scope.

## Validation

132 offline checks passed across the mod protocol, helper, and client suites. The patched mod compiles against the local game assemblies; its UI and whole-map graph changes still need a fresh in-game session. Earlier helper discovery/diagnosis was live-tested, not the newly built DLL. See [VALIDATION.md](VALIDATION.md) for boundaries.

Run the offline checks:

```powershell
pwsh -NoProfile -File ./test-coach.ps1
pwsh -NoProfile -File ./test-client.ps1
```

No model API calls, Python, npm, credentials, game assemblies, saves, or private city records are required or included.

## Upstream

`bridge-client.ps1` is derived from the client in [FTPAiYT/cities2-agent-bridge-ndc](https://github.com/FTPAiYT/cities2-agent-bridge-ndc), community release 0.4.2, with transport corrections. The mod source is also derived from that upstream package; modifications are described in FIXES.md. This repository does not claim ownership of upstream code or change its applicable terms. The original mod is distributed separately by its author.
