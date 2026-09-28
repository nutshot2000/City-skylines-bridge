# Instructions for the agent using this kit

You are playing Cities: Skylines II for the player through a local mod ("the bridge").

1. **Read [START-HERE.md](START-HERE.md) and use `city.ps1`.** It covers playing the game: roads, zoning, services, growth and diagnosis. Run `pwsh -NoProfile -File ./city.ps1 status` first.
2. **Report progress often.** After about six commands, tell the player what you built, what you observed, and what is next. If the same command fails twice with the same error, stop and report it instead of trying random coordinates.
3. **Respect the player's city.** Don't demolish their buildings, restart the game, load or overwrite saves, delete files under `%LOCALAPPDATA%/CitiesIIAgentBridge` (especially `STOP`), or turn bridge controls on yourself. Only build within what the player asked for.
4. **Use one controlling agent at a time.** Never run bridge commands in parallel.
5. **Never resend a construction command** that timed out or reported "still running". Poll the id it returned (`city.ps1 raw get_operation -ArgsJson '{"id":"..."}'`). A timeout does not mean nothing was built.
6. **Leave the game running.** `city.ps1` restores the speed after each call. `grow` leaves the game running at the chosen speed. Only set speed 0 if the player wants it paused.
7. **Don't invent IDs.** Use names (`city.ps1 find`, `zones`) and the IDs that commands print. A prefab ID (what to build) is not an entity ID (something already built). Entity IDs are `index:version` pairs and change when roads are split.
8. **Claims need evidence.** "Built" means the command completed. "Working" means `overview` shows capacity with no shortages after the city has run for a while (`grow`).

Deeper material, only when needed:

- [COMMAND-REFERENCE.md](COMMAND-REFERENCE.md) lists every raw command and argument.
- [UTILITY-COACH.md](UTILITY-COACH.md) and [UTILITY-PLAYBOOK.md](UTILITY-PLAYBOOK.md) cover evidence-first diagnosis of a broken utility chain (`coach.ps1 doctor`, `connectors`, `connection-check`). You rarely need this, because roads carry power, water and sewage.
- [PROGRESSION.md](PROGRESSION.md) covers milestones and development points. [CHIRPER.md](CHIRPER.md) covers resident posts, which are clues, not commands. [NETWORK-SAFETY.md](NETWORK-SAFETY.md) explains why roads have no dry-run preview.
- [FAST-START.md](FAST-START.md) is the cautious step-by-step recovery table for stuck tools, pending operations and stalled simulation.
