# Reliability fixes — 0.4.3-coach.1

## Client fixes available immediately

- Invariant, type-aware heartbeat parsing: strings, UTC/local DateTime and DateTimeOffset retain the correct instant. Ambiguous DateTime values are rejected.
- The familiar bridge.ps1 entry point uses the same corrected transport as bridge-client.ps1.
- Compact UTF-8 requests with a pre-write 16,384-byte check.
- Automatic splitting and ordered recombination of terrain requests into at most 32 points per chunk; no cross-session merging.
- Menu/stale-heartbeat diagnosis and explicit unknown-outcome errors with the original response path. Expired requests are never executed deliberately.
- agent.ps1 submits once and polls construction, batch or simulation completion. Pending results say exactly which ID to poll next.
- health explains the STOP latch without sending a request or clearing it. wait supports operation, batch and simulation IDs.

## Mod source fixes (require installing the newly built DLL)

- Native tool IDs inherited from the game instead of custom IDs with nonexistent UI media. Verified the native getters against the installed assembly. Removes the erroneous custom asset lookup source; does not establish that it was the sole cause of the reported hang.
- Service listing isolates unavailable service aggregates: per-field null values and errors instead of losing the whole response.
- Native error-icon reasons included when available; absence explicitly marked.
- Batch completedCount/failureIndex and prefabName compatibility aliases while keeping the original fields.
- STOP explanation in Options, plus heartbeat stopLatched and maxRequestBytes fields.
- Expired/oversized request errors include serviced time and actionable diagnostics.
- Whole-map outside-road discovery and road-only traversal from a specified current node. Distinguishes no physical path from incomplete evidence; does not certify vehicle routability.
- Correct updater unregister handle for the installed game API.

## Limits

A frozen Unity main thread cannot run its own watchdog; the existing 20-second construction deadline only works while callbacks execute. Missing UI assets, placement rejection and a hard hang are not treated as the same proven cause. No game restart, save load, STOP clearing, or compatibility-check bypass is automated.

Upstream's documented game target and the locally reported game version are different facts. This fork builds against the supplied local Game.dll and records its hash; it does not claim upstream 1.6.0f1 runtime validation for a 1.3.6f1 installation.
