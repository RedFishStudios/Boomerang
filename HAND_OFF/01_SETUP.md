# 01 · Setup, access, and what lives outside the repo

## 1. Access you need

| What | Why | Where |
|---|---|---|
| **The GitHub repo** `RedFishStudios/Boomerang` | The code. `main` is the only branch you need. | github.com/RedFishStudios/Boomerang |
| **Edit access to the Roblox place** "Boomerang [Development]", **placeId 74945725552268** | The place holds a lot that isn't in the repo: the lobby, the maps, some GUIs (see section 4). **The repo alone can't run the game.** | Owned by the client's Roblox group **293180599** (also `GlobalConfig.GroupId`). Ask the group for Team Create / edit access. |
| **Upload rights for the group** 293180599 | GUI images and decals are uploaded to the group, so the game can use them. | Same group. |
| **The client's "Gamemodes" design doc** | Design intent for each gamemode. | Google Doc linked at the top of `src/Shared/Constants/Gamemodes.luau`. It may not be shared with you; ask the client. |

The other branches on GitHub (`dev-soul`, `dev-lars`, `playtest-stable`, `chickynoid-migration`, `backup`...) are old snapshots or other people's work. Everything finished is on `main`. The previous developer also had many local `agent/T-###-...` branches that were never pushed to GitHub. They aren't needed: their work was merged (or squashed) into `main`.

## 2. Tools

| Tool | Version | Notes |
|---|---|---|
| Roblox Studio | current | Enable **Game Settings → Security → Enable Studio Access to API Services**, or saved data, leaderboards and quests won't load in Studio. |
| [Aftman](https://github.com/LPGhatguy/aftman) | any | Installs the pinned tools in `aftman.toml` (currently only **Rojo 7.7.0**). Run `aftman install` in the repo. |
| Rojo Studio plugin | matching 7.7.x | Install from the Rojo docs, or with `rojo plugin install`. |
| [Wally](https://github.com/UpliftGames/wally) | any | Optional. The packages are already committed (`Packages/`, `ServerPackages/`). Only needed to change package versions. |
| `wally-package-types` | any | Optional, for package type definitions in the LSP. |
| VS Code + **Luau Language Server** extension (JohnnyMorganz.luau-lsp) | | Settings are in `.vscode/settings.json` (new type solver on, Rojo sourcemap). |
| Selene | any | Linter (`selene.toml`, `std = "roblox"`). |
| StyLua extension | | ⚠️ See the warning below. |

> ⚠️ **StyLua and format-on-save.** `.vscode/settings.json` turns on `editor.formatOnSave` with StyLua as the Luau formatter. The project rule is **don't run StyLua on whole files**: many files are still indented with 3 spaces (converting them is task T-005), and StyLua would also rewrite wrapping, quotes and parentheses, burying your real change in a huge diff. Before editing, turn format-on-save off for this workspace (`"editor.formatOnSave": false`), or don't install the StyLua extension. New lines use **tabs**. In a file that's still space-indented, match its style.

The previous developer made GUI art with Blender's bundled Python (no other image tools on that PC). See [06_ART_PIPELINE.md](06_ART_PIPELINE.md). You only need that if you make art the same way.

## 3. Running the game

```bash
aftman install
```

```bash
rojo sourcemap default.project.json --output sourcemap.json
```

```bash
rojo serve
```

1. Open the place in Studio (File → Open from Roblox → the group's "Boomerang [Development]"), click **Connect** in the Rojo plugin.
2. Rojo writes `src/` into `ReplicatedStorage.Shared`, `ReplicatedStorage.Client`, `ServerStorage.Server` and the two boot scripts (table in `CLAUDE.md`, "Rojo tree → DataModel").
3. Press **Play**. One player is enough to start (`GlobalConfig.PlayersRequiredToStart = 1`). Use **Test → Clients and Servers** with 2+ players to test PVP.
4. Press **F2** for the developer console (Cmdr). `help` lists every command. Useful ones: `endround`, `setnextgamemode`, `setnextmap`, `setroundtime`, `getpickup`, `givecurrency`, `grantskin` / `granttaunt` / `grantemote` / `grantelimeffect` / `grantchargeupeffect`, `spawndecoy`, `resetdaily`, `resetquests`, `simulategroupmember`, `printgamestate`, `viewhitbox`, `viewping`, `tuneboomerang`, `topdowncam`.
5. `sourcemap.json` is git-ignored and only used by the language server. Regenerate it when you add or move files.

**Saved data in Studio** goes to separate stores from live servers: ProfileStore key `"Dev"` (live: `"Live"`) and leaderboard stores prefixed `Dev_` (live: `Live_`). Testing in Studio never touches real players' data.

**Never "save" or "publish" carelessly.** Publishing the place pushes whatever Rojo synced into it to the live game. Treat publishing as a release step.

## 4. What lives outside this repo

This is the most important section if you're starting fresh. Every Rojo-mapped service uses `$ignoreUnknownInstances`, so the place contains things the repo doesn't, and some project files were only on the previous developer's PC.

### In the Roblox place (you get these with place access)

| Instance | What it is |
|---|---|
| `ServerStorage.Server.Assets.Maps` | **The arena maps**, as a Roblox **package**. The project file declares `Assets` as an empty folder with `$ignoreUnknownInstances: true` so Rojo never touches it. **Never add files under `src/Server/Assets/`** or remove that setting, or Rojo will delete the maps in Studio. Each map has a `Config` (e.g. `DeathHeight`); `Shared/Constants/Maps.luau` / `MapData.luau` describe them in code. |
| `workspace.Lobby` | The lobby: `LobbySpawnLocation`, `LobbyVolume`, the lobby stations (tagged `LobbyStation`, with a `StationId` attribute: Group Rewards chest, etc.), `Leaderboards` boards, player pedestals. |
| `workspace.Arena`, `workspace.Map`, `workspace.Characters` | Containers the code fills at runtime (the current map is cloned into the arena; characters are parented to `Characters`). |
| `StarterGui` | Some older GUIs still live here as ScreenGuis. The server moves `StarterGui` into `ReplicatedStorage.__INTERFACES` and each client clones it into `PlayerGui`. Most GUIs are now built in code or saved in the repo as `.rbxmx` (see [03_SYSTEMS.md](03_SYSTEMS.md)). |
| Game settings | Developer products, gamepasses, badges and the group link are set up on the Roblox website / Creator Dashboard. Product IDs are in `src/Shared/Referential/MarketplaceItems.luau`. |

If code refers to an instance that isn't in the repo, it's probably one of these. Look in the place before recreating anything.

### Only on the previous developer's PC (ask whoever gave you the repo for these)

| What | Previous path | Needed for | Without it |
|---|---|---|---|
| **GUI art working files**: about 150 PNGs (44 MB) and about 30 Python scripts | `C:\MY FILES\Projects\Boomerang\Assets\ArtPipeline\` (scripts in `_Scripts\`, with a README) | Editing or re-making any of the new-style GUI art | The art already uploaded to Roblox keeps working; its image ids are in the code. You'd re-make art from scratch. See [06_ART_PIPELINE.md](06_ART_PIPELINE.md). |
| **The client's scripter package** (original `.rbxm` files and source art) | `Downloads\Boomerang-ScripterPackage\` | Re-importing models or art from it | A readable copy of all its code, plus its asset manifest, is in `reference/ScripterPackage/` (not synced into the game). |
| **Source images the client sent** (old icons such as `Slash.png`, pickup icons) | `C:\MY FILES\Game Assets\Boomerang\Gui\` | Redrawing pickup icons from the originals | You can screenshot the old icons in Studio instead. |
| `Commits.txt` | repo root, git-ignored | A daily change log written for the client | Not needed. To report changes, `git log` and the `Done` section of `TASKS.md` have the same information. |
| `AgentLog.md` | repo root, git-ignored | A log of agent merges into `main`, with undo steps | Not needed. `git log` has the same merges. |
| A shared `CLAUDE.md` changelog | `C:\MY FILES\SharedDocs\CLAUDE_MD_CHANGES.md` | Syncing agent rules across the previous developer's other repos | Not needed. `docs/CLAUDE_MD_CATCHUP.md` mentions it; you can ignore both. |

### In the repo but not in the game

- `reference/ScripterPackage/`: readable copy of the client's package (taunts, elimination effects, fan trails, UI). Most of it has already been ported into `src/`.
- `backups/manual-recall-rise-then-zoom/`: the old manual-recall code, kept as `.txt` in case the client wants it back. The quicker switch is `GlobalConfig.ManualRecallGroundApproach = false`.
- `docs/research/BLADE_BALL_LOBBY.md`: notes on Blade Ball's lobby, used for the lobby spec.
- `src/ReferencePlayerModule/`, `src/Animate/`, and a few `Old.luau` / `old.luau` / `Animate.luau` files: kept as references, never loaded. The full list is in `CLAUDE.md` ("Leftover and reference modules"). Don't edit or require them.
- `state/`: an empty folder.

## 5. Roblox Studio MCP (optional, for agents)

The previous developer let agents use the **Roblox Studio MCP** server (tools to inspect the place, read the output log, run Luau in Studio and upload images through Open Cloud). If you set it up:
- The repo is the source of truth for code. **Never edit Rojo-synced scripts in Studio**; edit `src/` and let Rojo sync.
- Studio edits are only for place-only content (maps, lobby models, GUI visuals you then save back into `.rbxmx` files).
- Never modify the maps package, and never publish the place from an agent.
- Agents shouldn't play-test by driving the game. When something is hard to reach by playing, add a Cmdr command so a human can trigger it (see `CLAUDE.md`, "Developer commands").
