# Validation — reliability update

132 offline checks passed:

- 90 mod tests: mailbox dispatch/replay, simulation bounds, geometry, object placement safety, Windows file-lock recovery, and real PowerShell client timeout/polling.
- 22 utility-coach tests: diagnosis, reserves, node validation, plan identity, checkpoint handling, duplicate protection and timeout handling.
- 20 transport/wrapper tests: cultures en-GB/en-US/de-DE, timezone preservation, byte limits, 169-point terrain query chunking, ordering, and one-submit async polling.

The patched 0.4.3-coach.1 DLL compiles against the local installation reporting game version 1.3.6f1. Its build manifest contains the exact Game.dll and output DLL fingerprints, and installer CheckOnly passed.

The new DLL was installed with a backup, loaded successfully after restart, and answered live ping through both PowerShell 7 and Windows PowerShell. Further inspection was correctly rejected while the city was unpaused and controls disabled. In particular, native tool panel behavior, granular service errors, native placement reasons, and whole-map outside-road detection are not yet live-verified. The earlier helper kit was live-tested for discovery, diagnosis, proposal creation and STOP refusal; those results do not substitute for new-mod testing. Real utility delivery and actual resident immigration remain unproven.

Test commands:

```powershell
pwsh -NoProfile -File ./test-coach.ps1
pwsh -NoProfile -File ./test-client.ps1
dotnet run --project ./mod/tests/MailboxTests.csproj -p:GamePath='YOUR_ACTUAL_GAME_FOLDER'
```

CIAB_TEST_PWSH may point to a PowerShell executable if pwsh is not on PATH. No game or private city records are included in this repository. Source is derived from FTPAiYT/cities2-agent-bridge-ndc 0.4.2; see FIXES.md for modifications.


Live follow-up: whole-map outside-road traversal returned a complete disconnected result from a populated road graph. Service listing still failed in coach.1; coach.2 adds a missing null-prefab guard and compiles, but requires another load before it can be verified. No claim of a fully fixed service listing is made.

## 0.4.4-coach.1 offline validation

Compiled against the installed Game.dll. 135 checks passed: 91 native-independent mailbox/policy/recovery checks, 22 helper checks, 22 client checks. New regressions cover null dispatch, null client result, and queued result without an operation ID. Existing checks cover retry behaviour, one-submit polling, timestamp cultures and request chunking.

These tests do not exercise Unity's live tools. New native preview geometry, zone catalog and tool cancellation are compiled but still need in-game validation. Installation checks the exact game assembly and DLL fingerprints and refuses replacement while Cities II is running.

## Live test: 0.4.4-coach.1

Passed in a loaded city: compact brief; dynamic zone catalog; services query; nearby road/power discovery; whole-map outside-road graph; checkpoint save; four-cell zoning preview with all four cells unchanged afterward; default-tool restoration; one bounded simulation interval and pause; consumer water/sewage observations.

FAILED: a node-attached water-pipe extension reported complete despite a 10-metre depth mismatch and new endpoint identity. Preview validation accepted a different temporary edge. Both newly created test segments were removed and their absence verified. No repeated placement attempt was made.

0.4.4-coach.2 now limits preview evidence to new created edges (excluding modifications/deletions), checks curve endpoint height as well as node identity, and verifies actual created-edge attachment before reporting completion. Compiled against the installed game assembly. This correction is NOT yet live-tested or installed; replacing the running DLL requires closing the game. Earlier offline checks do not certify this native behaviour.

## Live retest: 0.4.4-coach.2

Confirmed loaded version and fresh session. Saved a checkpoint, then submitted one 20-metre extension from a rediscovered live Small Water Pipe endpoint at elevation zero. The operation failed before apply with attached_node_not_preserved_in_native_preview_inspect_node_height_and_network_do_not_retry_same_geometry. The same three nearby water edges, endpoint identities and lengths remained; money was unchanged. The tool returned to DefaultToolSystem with no active operation.

This verifies rejection of the reproduced double-burial case, not successful native pipe attachment in general. The underlying native depth/snap issue remains unresolved. No second speculative placement was attempted.

## Housing palette live reproduction

User identified the residential icon/theme palette left open after a four-cell zone_rectangle operation. All four cells were read back as the selected residential zone and the tool returned to default. A bounded simulation step advanced 312 frames with the palette still open. Therefore the reproduced panel did not require a confirmation click or block simulation. Closed its X afterward. The helper now adds explicit zoning nextAction guidance distinguishing preview from applied zoning and prompting one bounded simulation step when authorized. No claim of new house growth is made from this test.
