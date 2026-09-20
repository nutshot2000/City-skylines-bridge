# Set up the fixed client and optional patched mod

You must own and install Cities: Skylines II. This repository supplies no game files. Use PowerShell 7.5+ for the coach and agent wrapper; the standalone bridge client also handles DateTime values returned by older/newer JSON parsers.

## Use the client now

Run from this repository, not an old extracted upstream package:

```powershell
pwsh -NoProfile -File ./coach.ps1 health
pwsh -NoProfile -File ./agent.ps1 -Command ping
```

Both `bridge.ps1` and `bridge-client.ps1` are the fixed transport. `agent.ps1` additionally waits for queued operations. `coach.ps1` provides the guided utility workflow. Do not use Windows PowerShell 5.1 as a workaround for the original bug; use these corrected entry points.

Close Options and other native menus before sending commands. A stale heartbeat means the helper sends nothing. If a sent request times out, inspect its original response file; never replay a mutation automatically.

## Build and install the mod patches

The helper scripts alone cannot repair a DLL already loaded by the game. Mod sources are in `mod/src`. Building needs a .NET SDK and your own installed game assemblies. The build records the exact Game.dll fingerprint; no game assemblies are distributed.

```powershell
pwsh -NoProfile -File ./mod/build.ps1 -GamePath 'YOUR_ACTUAL_GAME_FOLDER' -CommunityRelease
pwsh -NoProfile -File ./mod/install-local.ps1 -GamePath 'YOUR_ACTUAL_GAME_FOLDER' -CheckOnly
```

Save and close the game yourself, then:

```powershell
pwsh -NoProfile -File ./mod/install-local.ps1 -GamePath 'YOUR_ACTUAL_GAME_FOLDER'
```

The installer backs up the existing DLL and verifies the replacement. It does not stop, launch, or restart the game, clear STOP, or change a save.

Launch the game and load a test save. Confirm version **0.4.3-coach.1** through `health`. Enable **Options → Cities II Agent Bridge → Allow local bridge controls**, then close Options. If the checkbox reverts, check the STOP status: remove only the STOP file after the owner authorizes resuming, then re-enable the checkbox. City loads reset permission.

This fork compiled against a local installation reporting **1.3.6f1**. Upstream 0.4.2 documents a **1.6.0f1** target. Neither number should be silently rewritten to match the other: runtime version, exact assembly fingerprint and validation status are different facts. A successful build is not in-game validation. Other game builds may require source adaptation.
