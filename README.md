# WC3 Balance Bench

Repeat a Warcraft III unit matchup, alternate starting sides, and read the results in game.

WC3 Balance Bench is a Lua tool for mapmakers testing ordinary combat units. Configure one unit type and count per team, start a batch with a chat command, then change an Object Editor stat and run the same scenario again with a new label. Battles use the Warcraft III engine; the tool does not calculate a theoretical winner or recommend balance changes.

## What it does

- Runs an even number of rounds, 20 by default, in a dedicated flat arena.
- Swaps both starting sides and test player slots while scoring by logical team A/B.
- Reports wins, simultaneous eliminations, timeouts, survivors, and game-time duration.
- Supports `-bb start`, `-bb stop`, and `-bb report`; stop and error paths clean up units owned by the tool.
- Includes a playable demo and two labeled comparison maps. The custom `Bench Footman` in the comparison has 840 maximum HP rather than the stock Footman's 420.

## Download and run

Download `WC3-BalanceBench-v1.0.0.zip` from [Releases](https://github.com/KSAGlory/WC3-BalanceBench/releases) and extract it. Run `Map/BalanceBenchDemo.w3x` in Warcraft III. The tested Windows launch method is:

```powershell
& "C:\path\to\Warcraft III.exe" -launch -loadfile "C:\path\to\WC3-BalanceBench-v1.0.0\Map\BalanceBenchDemo.w3x"
```

After the map loads, press Enter and type `-bb start`. Type `-bb report` to display the latest summary again, or `-bb stop` to abort a running batch. A round result appears after each fight; the final summary names the scenario, label, run, completed rounds, and outcome counts.

The default demo is 3 Footmen against 2 Grunts for 20 rounds, with a 60-second timeout per round. For a short stock/custom comparison, load `Map/BalanceBenchStockTest.w3x` and then `Map/BalanceBenchCustomTest.w3x`. Both use two rounds of two Footmen versus one stock Footman. The custom map uses rawcode `hB01` for team A. The two maps are separate Warcraft sessions; write down or screenshot each report before switching.

## Use in a Lua map

1. Work on a development copy of your map. Reserve active player slots 0 and 1, with player 0 issuing the chat commands, and provide a clear arena. Disable melee initialization and other systems that could add units or interfere with the fight.
2. In World Editor's Lua map header custom script, paste `Scripts/BalanceBench.lua`, followed by `Scripts/ExampleConfig.lua`. Keep this order.
3. Edit `BalanceBenchConfig`: choose a scenario and label, set four-character unit rawcodes and counts, and fit the arena coordinates to your map. The demo config accepts up to 24 units per team and up to 100 even-numbered rounds.
4. In a Map Initialization trigger, call `BalanceBenchDemoSetup()` after the script definitions are available. The example setup makes player slots 0 and 1 hostile and calls `BalanceBench.install(BalanceBenchConfig)`. Use that setup only if those slots are dedicated to the test; the runner itself does not change alliances or support different slots in v1.0.0.
5. Save and test the map, then type `-bb start` in game chat. Change the label after editing Object Editor data so the two reports can be distinguished.

The runner removes only units and handles it creates. It does not reset arbitrary map triggers, upgrades, summoned units, or item drops. Existing map systems may affect results. This Lua code is not directly importable into a JASS map.

The script exposes `BalanceBench.install(config)`, `start()`, `stop()`, `report()`, and `uninstall()`. `install` takes the table shape shown in `ExampleConfig.lua` and returns `true` or `false, reason`. `start` and `stop` return the same success/error form. `report` prints the latest summary and returns its round-results table, or `nil` before a run. `uninstall` removes the tool's chat trigger and owned resources. The demo calls `install` during map initialization; gameplay uses the chat commands.

## Interpreting results

`A` and `B` always refer to the configured logical teams, even when sides and player slots swap. `BOTH` means both teams were eliminated in the same observation. `TIMEOUT` means both had survivors at the configured deadline. `ABORTED` and `ERROR` reports are partial; an interrupted fight is not counted as a completed round.

Results describe this map and setup. The tool uses native attack orders without tactical micro or spellcasting. Random rolls, target choice, unit upgrades, and other map systems may affect fights. A 20-round result is not a multiplayer win probability or proof that units are balanced.

## Compatibility and verification

Tested on Windows with Warcraft III client `3.0.0.24268` using classic graphics. The stock demo, side swaps, timeout/cleanup stress run, and a custom-unit comparison ran in game. The `Bench Footman` was selected during combat and displayed 840 maximum HP. The custom map also reopened in World Editor. Older game versions, Reforged HD graphics, arbitrary existing maps, and multiplayer have not been verified. See [TEST-RESULTS.md](Docs/TEST-RESULTS.md) for exact observations.

## Development

`Scripts/BalanceBench.lua` is the self-contained runner; `Scripts/ExampleConfig.lua` is the editable example. The playable map also contains World Editor custom text and a map-init trigger so saving and reopening it preserves the script.

To rebuild the demo from source on Windows, install Python 3 and obtain MPQEditor separately. Close the map in the game and editor, then run:

```powershell
python Tools/build_demo.py --mpq-editor "C:\path\to\MPQEditor.exe"
```

The builder copies `Map/BalanceBenchBase.w3m`, packages the scripts and editor metadata, and writes `Map/BalanceBenchDemo.w3x`. Use `--rounds 2 --timeout 30` for a smoke build, then rebuild without overrides to restore the default. `--source-map`, `--output`, `--team-a-rawcode`, `--team-b-rawcode`, `--team-a-count`, `--team-b-count`, `--scenario`, and `--label` support comparison maps. `--output` must differ from `--source-map`.

The optional fake-native test needs Python with [Lupa](https://pypi.org/project/lupa/) installed:

```powershell
python Tests/run_standalone.py
```

## Contributing

Bug reports and focused improvements are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. For installation help, see [SUPPORT.md](SUPPORT.md); use [SECURITY.md](SECURITY.md) for private vulnerability reports.

## Author and community

- Author: **KSAGlory**
- Community: [discord.gg/ksahub](https://discord.gg/ksahub)

## License

MIT License. See [LICENSE](LICENSE). Copyright (c) 2026 KSAGlory.
