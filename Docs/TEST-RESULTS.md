# Verification record

Tested on 2026-09-28 with Warcraft III `3.0.0.24268` on Windows using classic graphics. The game observations below were made by Codex through the running game, unless explicitly identified as file checks.

## Passed

- `Tests/run_standalone.py` executed the fake-native Lua lifecycle suite: simultaneous elimination, timeout, stop/restart, partial creation failure, cleanup isolation, side swaps, duplicate start refusal, and invalid config. It reported `BalanceBench fake-native lifecycle tests passed`.
- The dedicated demo loaded in the game. An overwhelming 10 Footmen versus 1 Footman matchup completed twice: logical A won from both sides (about 7.9 and 7.5 game seconds). Owned units were removed afterward.
- A 20-round, one-second-timeout stress run completed `20/20`. All rounds timed out by design; A alternated left/right, and no owned units remained. This checks lifecycle and cleanup, not 20 normal fights.
- `Map/BalanceBenchDemo.w3x` was rebuilt with its normal 20-round, 60-second, 3 Footmen versus 2 Grunts configuration after the stress run.
- World Editor saved and reopened a scratch copy. Extracted `war3map.lua` still contained the runner, config and map-init trigger. The editor-created ordinary custom unit `hB01` was saved in `war3map.w3u`; its `uhpm` field is 840, versus the stock Footman's 420 HP. These are editor/archive checks; the in-game result is recorded below.
- `Map/BalanceBenchStockTest.w3x` and `Map/BalanceBenchCustomTest.w3x` were packaged with the same two-round, two-versus-one scenario and distinct labels (`stock-420hp` and `custom-840hp`). Archive extraction confirmed their Lua config; the custom archive contains `hB01` and its 840-HP object data.
- The packaged custom comparison map reopened in World Editor and showed its `Bench Footman` custom unit in Object Editor.
- In-game stock comparison: `footman-2v1 / stock-420hp`, A `hfoo` x2 versus B `hfoo` x1, 45-second timeout, run 1 completed 2/2. A won both rounds, including after the side swap, with 2 survivors each time. Round times were 27.6 and 27.7 game seconds; report average 27.6 seconds. `-bb report` repeated the completed summary after cleanup.
- In-game custom comparison: `footman-2v1 / custom-840hp`, A `hB01` x2 versus B `hfoo` x1, 45-second timeout. Run 1 completed 2/2 with A winning from both sides and 2 survivors each round (27.6 and 27.6 seconds; 27.6 average). A second run completed 2/2 with the same winners and survivors (26.4 and 27.5 seconds; 26.9 average). `-bb report` repeated the completed summary. During the second run, a spawned unit was selected in game; its card showed `Bench Footman` and **636 / 840 HP** while fighting.
- The custom comparison map was built from the editor-saved map. It loaded and completed fights in the game after the edited map had reopened in World Editor, establishing that the saved custom unit data and current BalanceBench script run together.

## Comparison and limits

Both labeled runs produced 2/2 A wins in this two-versus-one matchup. The changed HP is demonstrably present in game, but these short runs do not show a meaningful result shift. The map loaded and tested was the packaged copy derived from the editor-saved map; the intermediate scratch map was reopened and inspected in World Editor but was not launched directly.

The results describe only the local map and client. They do not establish multiplayer balance or compatibility across Warcraft versions.
