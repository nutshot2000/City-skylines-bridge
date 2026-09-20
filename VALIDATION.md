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
