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

## 0.4.5-coach.1 validation

Compiled against the local game assembly. 137 offline checks passed: 24 helper checks (including consumer electricity and construction/diagnosis preservation), 22 client checks and 91 mailbox/policy/recovery checks. New native inspection fields and non-pausing status are compiled but not live-validated. Game was running during packaging; no DLL replacement or gameplay action performed.

## 0.4.6-coach.1 offline validation

Build succeeded against the installed Game.dll. 154 offline checks passed: 99 native-independent mailbox/policy/recovery checks (including 8 development eligibility cases), 26 coach checks, 22 client checks and 7 response-guidance checks. New cases cover prerequisite/service gating, insufficient points, pending/already-unlocked nodes, invalid cost, all-service catalog and accepted-versus-verified purchase guidance.

Game is running, so the new DLL is staged and not installed. Native development queries/purchases still require live validation after installation. No city points spent during this work.

## Building diagnosis helper

10 focused report tests and 26 existing coach tests pass. Cases cover shortfalls, snapshot fulfillment, no demand, missing rows, older raw fields, uncertain road references, construction presence, exact follow-up identity, read-only query count and cross-session rejection. No live city commands were sent for this helper update.

## 0.4.7-coach.1 validation

Compiled against the installed game assembly. 66 helper checks passed (23 client, 26 coach, 10 building report, 7 response guide), including a fake-mailbox Chirper round trip preserving limit, text and non-pausing metadata. No game commands sent. The new native feed implementation is compiled but not yet live-tested against the sidebar. The game is running, so the DLL remains staged, not installed.

## 0.4.7-coach.2 Chirper hotfix

Confirmed in the installed game assembly: ChirperUISystem.GetMessageID(Entity) is public; GetTicks(uint) is private. Replaced the incorrect non-public reflection lookup with a direct public GetMessageID call. Compilation now checks the method signature/visibility instead of discovering this mismatch at runtime. GetTicks retains its private reflection lookup. Build passed; live Chirper output still needs retesting.

## 0.4.8-coach.1
Compiled against the installed game assemblies. Offline checks: 114 C# checks (including 15 preview policy cases), 27 client checks (including 4 local preview guards), 26 coach, 8 response guidance and 10 building-report checks. Updated client blocks unsupported previews even against an older installed DLL. Native error geometry and owned-subnetwork visibility require live validation after DLL installation. Game was running; no city entities removed or construction attempted. No standalone network dry run or exact collision-cell reporting is claimed.

Utility helper follow-up: 9 connection-report fixtures and 31 coach checks passed, including disconnected post-build results, duplicate-path prevention and receipt persistence. No live city commands were sent; actual utility delivery is not claimed.

## 0.4.9-coach.1
Compiled against the installed game fingerprint and installed with the previous DLL backed up. Offline checks passed: 114 C# checks, 31 coach, 9 connection-report and 27 client checks. Native IL inspection identified FixElevation shifting positions and clearing OriginalEntity when control-point elevation is outside prefab bounds. This patch preserves explicit node anchors with burial metadata; existing native preview and post-apply checks remain enabled. Live baseline: Whinnitsburg, population 0, money 1000000; checkpoint CitiesIIAgentBridge-utility-attachment-test-before-20260927-220828-7893c468 completed. No test pipes built. Live attachment and connector discovery tests are PENDING after reload; user requested immediate push to conserve credits.

### 0.4.9 quick live test — 2026-09-27
Verified loaded 0.4.9-coach.1 in Whinnitsburg with controls enabled. Saved checkpoint CitiesIIAgentBridge-quick-pipe-test-20260927-221131-6bcb4050. A 20m Small Water Pipe built for 24; connector discovery returned both exact node IDs/heights and native freshwater capacity with sewageCapacity 0. Extending from the discovered buried endpoint FAILED before apply with attached_node_not_preserved_in_native_preview_inspect_node_height_and_network_do_not_retry_same_geometry. The elevation metadata change is therefore NOT a verified attachment fix. Inspection showed only the seed pipe remained; removed that exact test-created entity and verified zero local edges afterward. Final money 999976, paused, controls enabled, default tool, no active operation. No supply-flow test performed. Further native attachment debugging is needed.

## 0.5.0-coach.1 (2026-09-28)
Helpers were live-tested on a new city (Klanka Canyon, game 1.3.6f1, DLL 0.4.9 loaded): from an empty map to 1,360 population and a positive budget. The utilities were one wind turbine, then five more; WaterTower01 and SewageOutlet01 were beside roads with **no pipes or cables**, and there were 0 shortages throughout. city.ps1 verbs exercised live: status, overview, map, roads, road, zone (including 6-tile industrial and 2-tile row-house zoning), place (turbines, landfill, clinics, cemetery, school), grow, find, zones, unlocks, buy, budget, tax, chirper. Offline: test-city 27, test-coach 31, test-client 27, building-report 10, connection-report 9, response-guide checks, and the mod suite including 14 new pause-policy checks, all passing.
The 0.5.0 DLL compiles against the installed Game.dll. It is NOT yet live-tested: installing it needs the game saved and closed. After installing, verify that reads keep speed unchanged, and check `get_milestones`, zoning with a plain {x,z} start, `find_building_sites` tile filtering and `get_outside_connections` without a node.

### 0.5.0 live test — 2026-09-28 (Klanka Canyon, pop 1,500 → 1,724)
Installed 0.5.0-coach.1 with the previous DLL backed up; loaded fine, health/status report the version.
- Reads do not pause: `problems`, `milestones`, `status` ran while the in-game date kept advancing at speed 1. Construction still pauses and city.ps1 restores the speed afterwards (verified after road/zone/place).
- get_notifications: listed 12 live icons (Traffic Bottleneck ×10, Powerline Not Connected, Noise Pollution) with positions. Acting on it (east bypass + two west links to the z=1240 avenue) cut bottlenecks 10 → 8 → 2.
- get_milestones: milestone 3 reached, 729/3500 XP to milestone 4, which unlocks Office Low; matches the locked office demand.
- zone_rectangle with a plain {x,z} start (no block id): complete, 180 cells.
- find_building_sites: reports lot size 128×200 m and rejections (38 overlapping, 15 outside owned tiles) with a next hint.
- get_outside_connections without a node: status listed_only, 4 highway entry nodes.
- get_build_prefabs unlockedBy: present on locked rows. PoliceStation01 had unlocked by then, so it showed an empty list.
Found live and fixed in source (needs the next DLL install): traffic icons reported their lane ("Car Drive Lane 3") instead of the road; Notifications now walks lane → road edge. city.ps1 printed a false "left PAUSED" warning after reads on 0.5.0; it now checks the real speed first.
