# Client scripter package (reference only)

Readable copy of the client's "Boomerang! scripter package" (taunts, elimination effects, fan trails, UI). The original `.rbxm` files and source art are in Sol's `Downloads/Boomerang-ScripterPackage`. The package's own README is [PACKAGE_README.md](PACKAGE_README.md), and every image and sound id it uses is in [AssetManifest.csv](AssetManifest.csv).

**This folder is reference only.** Rojo doesn't map it, so nothing here reaches the game. Don't require, edit or "fix" these files. Port what a task needs into `src/`, adapted to our systems (see tasks T-153 to T-160 in TASKS.md). We don't use the package's own data, DataStore, Gems, remotes, quests or install script.

## Layout

One folder per package. Inside it, the instance tree from the `.rbxm`, with the folder names the package used (e.g. `StarterPlayerScripts/Client/...`):
- `Name.luau` = ModuleScript, `Name.client.luau` = LocalScript, `Name.server.luau` = Script.
- A script that has child scripts is a folder with `init.luau` (or `init.client.luau` / `init.server.luau`).
- `_tree.txt` lists every instance in the package with its class, including the non-script ones (models, ScreenGui snapshots, KeyframeSequence clips, whose keyframes aren't listed).

| Folder | What it is |
|---|---|
| `SharedDependencies/` | `Theme`, `Assets` (image and sound ids), `Cosmetics` (catalogue), `Remotes`, `QuestData`, `ShopData`, the server `Inventory`, and an `R15Rig` (with a stock Animate copy) |
| `UI/` | Code-built screens (`LeftHud`, `InventoryScreen`, `ShopScreen`, `QuestsScreen`, `StatsScreen`, `Kit`) and their server modules (`Afk`, `Quests`, `Stats`). Layout reference for the reskins (T-156 to T-160) |
| `Taunts/` | Too Easy, Bonk!, Royal Treatment, Nap Time, with helpers `Pose`, `Props`, `Effects` (T-154) |
| `KillEffects/` | Stone, Ashes, Sakura, Shark, helpers `Fx`, `Rig`, `DefaultDeathSound`, and the runtime shark (`SharkModel`, `SharkKit*`), which we replace with the imported FBX (T-153) |
| `Trails/` | `FanTrails` with `Ribbon`, `Decor` and six `Styles`, plus the disabled `FanTrailsExample` (T-155) |
| `TrailTestBench/` | The package's temporary trail test panel. Testing only |
