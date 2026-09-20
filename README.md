# Cities: Skylines II Utility Coach

A practical helper kit for AI agents using [Cities II Agent Bridge](https://github.com/FTPAiYT/cities2-agent-bridge-ndc). It turns low-level utility commands into compact diagnostics, checked plans, and clear next steps.

**This is a companion helper, not the game mod or an MCP server.** You need your own installed Cities: Skylines II, a compatible working bridge, and PowerShell 7.5 or later.

## Start

Read [START-HERE.md](START-HERE.md). Agents should first read [AGENTS.md](AGENTS.md), then run:

```powershell
pwsh -NoProfile -File ./coach.ps1 doctor
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

22 offline checks passed, plus live discovery, diagnosis, proposal creation, existing-path detection, and STOP refusal. Successful application through this new wrapper was tested with simulated bridge responses; actual utility delivery remains unverified. See [VALIDATION.md](VALIDATION.md) for boundaries.

Run the offline checks:

```powershell
pwsh -NoProfile -File ./test-coach.ps1
```

No model API calls, Python, npm, credentials, game assemblies, saves, or private city records are required or included.

## Upstream

`bridge-client.ps1` is derived from the client in [FTPAiYT/cities2-agent-bridge-ndc](https://github.com/FTPAiYT/cities2-agent-bridge-ndc), community release 0.4.2, with a local timestamp-parsing correction. This repository does not claim ownership of upstream code or change its applicable terms. The original mod is distributed separately by its author.
