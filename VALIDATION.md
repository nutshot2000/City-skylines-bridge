# Validation — reliability update

132 offline checks passed:

- 90 mod tests: mailbox dispatch/replay, simulation bounds, geometry, object placement safety, Windows file-lock recovery, and real PowerShell client timeout/polling.
- 22 utility-coach tests: diagnosis, reserves, node validation, plan identity, checkpoint handling, duplicate protection and timeout handling.
- 20 transport/wrapper tests: cultures en-GB/en-US/de-DE, timezone preservation, byte limits, 169-point terrain query chunking, ordering, and one-submit async polling.

The patched 0.4.3-coach.1 DLL compiles against the local installation reporting game version 1.3.6f1. Its build manifest contains the exact Game.dll and output DLL fingerprints, and installer CheckOnly passed.

Runtime validation of the NEW DLL is pending a fresh game session. In particular, native tool panel behavior, granular service errors, native placement reasons, and whole-map outside-road detection are not yet live-verified. The earlier helper kit was live-tested for discovery, diagnosis, proposal creation and STOP refusal; those results do not substitute for new-mod testing. Real utility delivery and actual resident immigration remain unproven.

Test commands:

```powershell
pwsh -NoProfile -File ./test-coach.ps1
pwsh -NoProfile -File ./test-client.ps1
dotnet run --project ./mod/tests/MailboxTests.csproj -p:GamePath='YOUR_ACTUAL_GAME_FOLDER'
```

CIAB_TEST_PWSH may point to a PowerShell executable if pwsh is not on PATH. No game or private city records are included in this repository. Source is derived from FTPAiYT/cities2-agent-bridge-ndc 0.4.2; see FIXES.md for modifications.
