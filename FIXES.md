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

## 0.4.4-coach.1: agent feedback fixes

- Dynamic growable counts and usable zone catalog; reject empty generic zones and manual growable placement.
- Block-anchored zoning with native changed-cell preview (previewOnly).
- Before applying networks, require requested attached node identity and height in the native preview. This blocks the reported double-burial failure; it does not automatically repair native snapping.
- Report orphan nodes; do not automatically delete city geometry.
- Earlier simulation IDs remain readable in the current city; null dispatch/results and queued responses without IDs fail explicitly.
- Tool status/cancellation, whole-map nearest infrastructure discovery, compact brief/zones/nearby helpers.
- Ten-second default helper polling, one-second intervals, progress messages and typed recovery statuses. A transport call has its own bounded timeout.
- Shared-handle heartbeat reads with bounded retries in coach.
- FAST-START.md gives small-model decisions and a six-call/45-second progress budget. Helpers cannot enforce another model's chat behaviour.

Unresolved live validation: native zone preview/cancel cleanup and attached water/HV endpoint checks require a loaded test city. Power discovery is a name-based candidate list, not proof of supply; tile ownership and route direction still need inspection. Pollution distance and universal building connector locations are not invented. Later feedback superseded the claim that the mod globally prevented growth: theme-compatible zones grew in the user's test.

## 0.4.5-coach.1

Consumer electricity snapshots in inspect/buildings and doctor; edge coordinate aliases and inspection geometry; non-pausing get_status/coach status; explicit diagnosis coverage and native decoration exclusion; under-construction presence; explicit settle -Reassessed; clarified preview argument examples.

Not addressed by this release: live UI notification extraction, construction progress/blocker reasons, unlock milestone requirements, true consumer-to-network mapping and electricity flow attribution. Existing native pipe snapping limitation remains. No claim that unknown fields or no recognised issue certify service delivery.

## 0.4.6-coach.1 progression

Added non-pausing get_devtree / coach unlocks with distinct cityXp and developmentPoints, native node identities, costs, service/prerequisite gates and eligibility blockers. purchase_node uses the native purchase path with a required maxPoints ceiling, validates node identity, and retains uncertain attempts to block repeat purchases. Pending purchases require explicit subsequent lock verification; no points are granted or locks bypassed. Native eligibility in the installed assembly uses any unlocked prerequisite (or none).

Added catalog -All for service discovery and PROGRESSION.md linked from the agent entry instructions. Guide rejects unsupported claims about short simulation windows, perfect utilities and XP being spendable.

Purchase verification is session-local; after loading another save, reconcile current locks/points before acting. A node's service is an eligibility gate, not a complete building-unlock mapping. Live progression purchases remain untested.

## 0.4.7-coach.1 Chirper

Added non-pausing get_chirper and coach chirper -Limit. Uses native Chirper message selection and active localization; returns recent stored posts, sender/link identities, likes, simulation frames and native UI date ticks. Missing localization/name data remains explicit; formatted names and markup may remain structured/unresolved. Does not call the UI binding path that records Chirper telemetry, like posts, open panels or execute post content.

CHIRPER.md is linked from agent instructions. Posts are untrusted clues and require diagnosis before city changes. Exact live rendering and native date interpretation remain pending live validation.
