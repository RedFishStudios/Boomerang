# Boomerang!

Roblox game written in Luau, synced into Studio with Rojo. A fast-paced, round-based **PVP** game inspired by *Boomerang Fu*, with its own flair and Roblox-friendly presentation (taking inspiration from *Blade Ball*). Short rounds pit players against each other on small maps, with **boomerangs as the primary weapon**, across several **gamemodes**, with **pickups** that power up the boomerang or the player.

- GitHub: `RedFishStudios/Boomerang`. This is client work: Sol develops it for the client and reports finished changes daily (see "Commits log" below).
- Active branch: `dev-soul` (Sol's). Other remote branches (`dev-lars`, `playtest-stable`, `chickynoid-migration`, backups) belong to other people or are snapshots. Don't touch them.
- The codebase grew from a game template (`larsb/roblox-game-template`, by @SixthAtom). Template code that no longer fits the game is being updated or kept as reference (see "Leftover and reference modules").

## Start here

| Doc | Read it when |
|---|---|
| [TASKS.md](TASKS.md) | Always. The general task board, its rules (for every task list), and the `Next free ID`. |
| [docs/EPICS.md](docs/EPICS.md) | Always. Large features (Epics): which are active, and their lifecycle. Before working on an Epic, read its `docs/epics/<epic>/DESIGN.md` and `TASKS.md`. |
| [docs/LOBBY_SPEC.md](docs/LOBBY_SPEC.md) | Before any lobby work. Physical lobby stations (wheel, crates, group chest, server portal, leaderboards) from the client's reference screenshots. |
| [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) | Before any gameplay work. The client's MVP spec (round flow, controls, Classic, parry/clash, camera) and where the code differs from it. See "How authoritative the docs are" below. |
| [Gamemodes design doc](https://docs.google.com/document/d/15GWFwrjrhytRjPqBhBg-Zhc5YLX9CeWJlt8Q_rMttss/edit?tab=t.d4ujxm3y7eay) | Linked from `Shared/Constants/Gamemodes.luau`. Agents probably can't open it. If you need design intent that isn't in GAME_DESIGN.md, ask Sol. |

### How authoritative the docs are

- The client wrote the game design document (`docs/GAME_DESIGN.md`, from the "Boomerang! Technical Document" PDF) before the ideas were fully thought out. It describes the origins the game concept orbits around, but it's often vague and **isn't always the final authority**. The current code, tasks and Sol's decisions can override it. When the doc and the code disagree, ask Sol instead of "fixing" either.
- **Ignore the sketches in the game design document** (e.g. the recall diagrams and the mobile button layout). Sketches in the GUI documentation or any other documentation are fine to follow.

**What agents can't do:** rely on tools being installed. If a tool you need isn't available, say so; don't work around it. Play-testing and final sign-off are Sol's.

**Roblox Studio MCP:** when the session has the `Roblox_Studio` tools (Sol's place is "Boomerang [Development]", placeId 74945725552268), agents can inspect the place, read the output log and run Luau. Rules:
- Call `list_roblox_studios` and confirm the right place with Sol before changing anything.
- **The repo is the source of truth for code.** Never edit Rojo-synced scripts in Studio; edit the files in `src/` (Rojo syncs them). Studio edits are for place-only content (maps, models, GUI visuals to save back into `.rbxmx`), and only when a task asks for it.
- Never modify the map package (`ServerStorage.Server.Assets.Maps`) or publish/save the place.
- Prefer read-only use (inspecting instances, reading the console) unless the task says otherwise.
- **Use it for building, not for agentic play-testing.** Don't start play sessions or drive the game to test it; Sol play-tests. Instead, when a feature is hard to reach by playing (needs a day to pass, a specific pickup, several players, a certain round state...), add a **Cmdr command** (see "Developer commands") so a human developer can trigger it, and say which command to use in the task Notes.

## Toolchain

- **Rojo** (`default.project.json`, project name `Boomerang!`) maps `src/` into the DataModel. **Wally** manages packages.
- **Tools** are pinned in `aftman.toml` (currently only Rojo).
- **Packages:** `Cmdr` (shared, in `Packages/`) and `ProfileStore` (server, in `ServerPackages/`). ProfileStore is used by `PlayerDataService`; Cmdr is the developer console (see "Developer commands"). **Jecs has been removed and is not to be used.** Don't add or start using a package without asking Sol.
- **Setup / types:** `wally install`, then `rojo sourcemap default.project.json --output sourcemap.json`, then `wally-package-types` (see `.vscode/tasks.json`).
- **Formatting:** indentation is **tabs** (`stylua.toml`, VS Code `insertSpaces: false`). **Don't run StyLua** on whole files: it would also rewrite much more than indentation. Converting the existing space-indented files is task T-005. **Linting:** Selene (`selene.toml`, `std = "roblox"`). The Luau LSP uses the new type solver.
- **Never edit** `Packages/`, `ServerPackages/`, or `sourcemap.json`. These are generated.
- **Testing** happens in Roblox Studio, which agents can't run. Say clearly what needs manual testing in Studio.

## Rojo tree → DataModel

| Source | DataModel location |
|---|---|
| `src/Shared` (+ `Packages`) | `ReplicatedStorage.Shared` (`.Packages`) |
| `src/Client` | `ReplicatedStorage.Client` |
| `src/Server` | `ServerStorage.Server` |
| `ServerPackages` | `ServerStorage.Packages` |
| `src/Server.server.luau` | `ServerScriptService.Server` (server boot) |
| `src/Client.client.luau` | `StarterPlayer.StarterPlayerScripts.Client` (client boot) |

`ServerStorage.Server.Assets` is declared in the project file (not on disk) so that Rojo leaves the map package alone (see below).

**Not mapped by Rojo** (they never reach the game): `src/ReferencePlayerModule/` and `src/Animate/`. `.gitignore` also excludes `/src/PlayerModule/**`.

### Leftover and reference modules: don't touch

These files are outdated or unused, and Sol keeps them **as references only**. Don't edit, delete, rename, reformat, require or "fix" them, and don't count them as live code when you search:

| File | What it is |
|---|---|
| `src/ReferencePlayerModule/` | Reference copy of Roblox's PlayerModule. Not mapped by Rojo. |
| `src/Animate/` | Copy of Roblox's Animate script. Not mapped by Rojo. |
| `src/Server/Core/Animate.luau` | Older Animate copy. Not auto-loaded, not required anywhere. |
| `src/Shared/Networking/Animate.luau` | Older Animate copy. Not required anywhere. |
| `src/Server/Core/CharacterService/Old.luau` | Previous CharacterService. |
| `src/Client/Core/CharacterController/old.luau` | Previous CharacterController. |
| `src/Client/UI/Gui/ItemAcquired/OldTemplate.rbxmx` | Previous ItemAcquired template. |

Add a file to this list only when Sol says so.

When a folder contains an `init.luau`:
- The folder itself becomes a ModuleScript containing the contents of the `init.luau`
- Sibling files of the `init.luau` become children of the ModuleScript that the folder becomes

### The Studio place has more than the repo

Every Rojo-mapped service uses `$ignoreUnknownInstances`, so the place in Studio contains instances that aren't in this repo, e.g.:
- `workspace.Lobby` (with `LobbySpawnLocation`, `LobbyVolume`), `workspace.Arena`, `workspace.Characters`, `workspace.Map`
- **the maps**: `ServerStorage.Server.Assets` (with `Maps`) is **package-only**. The project file declares `Assets` as an empty folder with `$ignoreUnknownInstances: true`, so Rojo creates it but never touches what's inside. **Never add files under `src/Server/Assets/`** or remove that setting: Rojo would start deleting the package's maps in Studio again.
- whatever is in `StarterGui` (the server moves it into `ReplicatedStorage.__INTERFACES`, and each client clones it into its `PlayerGui`)

If code references a module or instance that isn't in the repo, it probably exists only in Studio. Don't recreate or "fix" it from a guess. Ask Sol.

## Boot / module loading

Both boot scripts collect modules **by name**, then call every module's `init()` (in order, blocking), then every `start()` (with `task.spawn`), then, **in Studio only**, every `test()` (with `task.spawn`). `init`/`start`/`test` are optional.

| Side | Loaded automatically |
|---|---|
| Server (`Server.server.luau`) | Every ModuleScript **descendant** of `Server/Core` and `Server/Services` whose name contains `Service` |
| Client (`Client.client.luau`) | Every ModuleScript **descendant** of `Client/Core`, `Client/Controllers`, `Client/UI` whose name contains `Controller` or `Screen` |
| Both | Every **direct child** of `Shared/Library` whose name **ends** in `Library` |

- **The name filter is case-sensitive.** A file named `Shopservice` or `FooLib` is silently not loaded. Name new modules accordingly.
- Modules without the keyword (`Old.luau`, `old.luau`, `Animate.luau`...) are never auto-loaded; they only run if something requires them.
- **Libraries run on both server and client.** Branch on `RunService:IsServer()` and only require server modules inside the server branch.
- **One-time setup** goes in `init()`. Anything that depends on other modules being initialised goes in `start()`.
- **GUI modules** (`Client/UI/Gui/<Name>/init.luau`) are not loaded by the boot script; `UIController` requires every child of `Client/UI/Gui` itself.
- **Logic modules** (`Shared/Logics/*`, `Server/Logics/*`) are loaded by the service/controller that owns them, by folder scan or by `WaitForChild(id)` (see "Logics" below).

## Where things go

```
src/
  Server.server.luau       Server boot
  Client.client.luau       Client boot
  Server/
    Core/                  Server systems (auto-loaded). Folder + init.luau when it owns child modules.
    Services/              More server systems (auto-loaded); currently GlobalInstanceService
    Logics/ProductLogics/  One module per developer product (grant logic), loaded by ProductService
    Cmdr/Commands/         Cmdr developer commands (see "Developer commands"); not auto-loaded
    (Assets/Maps)          Arena maps: a Studio package, deliberately not on disk
  Client/
    Core/                  Client controllers (auto-loaded)
    Controllers/           More controllers (auto-loaded); currently GlobalInstanceController
    UI/UIController.luau   Opens/closes GUIs, HUD vs menu types, superseding
    UI/Gui/<Name>/         One GUI: init.luau + its .rbxmx (ScreenGui) and templates
    UI/Screens/            InputScreen (mobile buttons)
  Shared/
    Library/               Shared systems (auto-loaded on BOTH sides), e.g. GameStateLibrary, PickupLibrary, CombatLibrary
    Logics/                Dual-context behaviour modules (see below)
    Constants/             Config and constant tables: GlobalConfig, Gamemodes, Tools, Sounds, Animations, Enums/...
    Referential/           Data tables: Items, ShopItems, MarketplaceItems, DailyRewards, LootBoxRates, ThrownWeapons...
    Networking/            SimpleRemotes, SimpleRemotesUtil, RemoteCodes, ResponseCodes
    Data/ProfileTemplate   The saved player data shape
    Classes/               Signal, TasksList, Atom, Spring, Stack, ObjectPool, Scheduler...
    Utils/                 Utility modules, incl. ReactiveValue and CreateElement
    Assets/                Particles, tools, the R15 character, GUI assets (.rbxmx)
```

**Always start new modules from the VS Code snippets** in `.vscode/snippets.code-snippets` (`template-module`, `template-class`), or copy the shape of a sibling module. Keep the dashed section headers (`CONSTANTS` / `TYPES` / `PRIVATE VARIABLES` / `PUBLIC VARIABLES` / `PRIVATE FUNCTIONS` / `PUBLIC FUNCTIONS` / `CORE FUNCTIONS`): they're there for human review.

## Networking and in-process events

**Client↔server communication goes only through Roblox remotes, via `SimpleRemotes`:**

```lua
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
SimpleRemotes.getEvent("Name")            -- RemoteEvent
SimpleRemotes.getFunction("Name")         -- RemoteFunction
SimpleRemotes.getUnreliableEvent("Name")  -- UnreliableRemoteEvent
```

The server creates the remote (under `ReplicatedStorage.__SIMPLEREMOTES`) the first time it asks for it; **the client `WaitForChild`s it, with no timeout**. So:
- Both sides only need to use the same name.
- The server must create it at load time (module top level or `init()`). If the server never creates it (e.g. its service isn't loaded), the client module that asks for it hangs forever, and so does every module that requires that one.
- `SimpleRemotesUtil` + `RemoteCodes` handle remotes that carry several actions as small numeric codes in a buffer (`BufferUtil`). `ResponseCodes` holds HTTP-style result codes.

**In-process events** use `TasksList` (`Shared/Classes/TasksList`): `list:Add(fn)` returns a remover function, `list:Execute(mode, ...)` runs the subscribers (e.g. `"parallel"`). Many systems expose them as `XTasks` fields (`PlayerDataService.UpdatedTasks`, `CombatLibrary.PlayerKilledPlayerTasks`, `GameStateLibrary.RoundFinishedTasks`, and the cross-system ones in `Shared/Constants/SharedTasks.luau`). **They never cross the network**: each side has its own copy.

**Replicated state:**
- `GameStateLibrary` holds the round state (`GameplayPhase`, `CurrentRoundData`, timer, intermission/vote data, living players) as `ReactiveValue`s. The server applies changes and they replicate to clients automatically (`GameStateSync`).
- `PlayerDataService.get(player)` returns a **proxy** of the player's saved data. Writing to it replicates the change to that player's client (`PlayerDataController`).
- `PlayerStatsLibrary` replicates per-player stats.

The server is authoritative. The client may predict (e.g. boomerang throws, dashes), but the server's result wins.

## Game structure

- **Round cycle** (`RoundCyclingService`, server): one per-frame state machine over `Enums/GameplayPhases`: `PendingPlayers` → `LobbyVoting` → `LobbyEnded` → `RoundActive` → `PreIntermission` → back to voting. Players vote between gamemodes in the lobby.
- **Gamemodes**: defined in `Shared/Constants/Gamemodes.luau` (respawn, late join, duration, storm close, pickups/dash disabled), each with a logic module in `Shared/Logics/GamemodeLogics/<Id>` exposing `setup()` and `teardown()`; `teardown()` fires `GameStateLibrary.RoundFinishedTasks` with the winner. Current: Classic, TeamClassic, Elimination, TeamElimination, HotPotato, Assassin (ThrowBoomerang is commented out).
- **Weapons**: tools in `Shared/Constants/Tools.luau` (ClassicBoomerang, Shuriken, Fan...) point to a `LogicClass` in `Shared/Logics/WeaponLogics/` (`Boomerang`: throw, recall, clash, remove). `WeaponService` / `WeaponController` / `ClashService` drive them.
- **Pickups**: `Shared/Logics/PickupLogics/<ClassId>`, shape `PickupLibrary.PickupLogic` (`onPickup`, `onEnd`). A module with `Disabled = true` is a stub (marked `-- STUD` / `-- TODO`). Driven by `PickupService` / `PickupController`.
- **Abilities**: `Shared/Logics/AbilityLogics/` (Dash, Stab), via `AbilityService` / `AbilityController`.
- **Environment objects**: `Shared/Logics/Environment/` (MovingPlatform, Spin, Portal, DeadlyPart, Water, PermanentFire...), usually with `validate` / `onObjectAdded` / `cleanup` (optional `init`), run on both sides by `EnvironmentService` / `EnvironmentController`. `DynamicCollisionLibrary` lets thrown weapons collide with moving objects.
- **Storm close**: `StormCloseService` / `StormCloseLibrary` shrink the arena in gamemodes with `StormClose = true`.
- **Teams**: `GameTeamService` (free-for-all or opposing teams per round), `GameTeamLibrary.areEnemies`.
- **Monetisation**: `MarketplaceLibrary` (product/gamepass info, prompts, ownership caching) + `PolicyLibrary` (regional rules such as paid random items). `ProductService` handles `ProcessReceipt` and dispatches to `Server/Logics/ProductLogics/<Product>` (`ProductId`, `grant(player) -> boolean`; `NotActive = true` skips it). Product IDs live in `Shared/Referential/MarketplaceItems.luau`.
- **Config**: `Shared/Constants/GlobalConfig.luau`. It has debug switches (visualisers) and values that must be checked before release (e.g. `PlayersRequiredToStart`).

## Data

- **Currency is a single number:** `Profile.Currency`. There is one currency. Never add several currencies (`Currencies`, `Cash`, `Gems`...) to the profile or to code that reads it.
- **Persistent player data:** `PlayerDataService` (ProfileStore). Store key is `"Dev"` in Studio and `"Live"` in a live server. The shape is `Shared/Data/ProfileTemplate.luau` (`Elims`, `Wins`, `Losses`, `Currency`, `DailyRewards`, `Inventory`, `GiftedPasses`). New fields are filled in by `profile:Reconcile()` on load.
- **Changing the Profile shape:** update the `Profile` type and `ProfileTemplate.get()` together. Never repurpose or rename a field that has shipped to live players. Ask Sol before removing one.
- Read/write through `PlayerDataService.get(player)` (or `getAsync`), never `profile.Data` directly, so changes replicate.
- **Permanent IDs:** anything saved or sent over the network (item ids, product ids, gamemode ids, pickup class ids) is a fixed, hand-written string or number. Never change or reuse one.

### Currency and items

- `EconomyService` (server) / `EconomyController` (client) own `Currency`: use `addCurrency` / `spendCurrency`, not direct writes.
- `ItemService` (server) / `ItemController` (client) own `Inventory` (item id -> amount). Item data is in `Shared/Referential/Items.luau`; shop layout in `ShopItems.luau`.

## Developer commands (Cmdr)

Cmdr is the in-game developer console for testing. Press **F2** to open it.
- `Server/Core/CmdrService` registers Cmdr's built-in commands plus every command in `src/Server/Cmdr/Commands/`, and owns the permission check (a `BeforeRun` hook).
- **Who can use it:** while `GlobalConfig.CmdrOpenToEveryone` is true (client review builds), **every player in every server**. That's a `TODO:RELEASE`: set it to false before public release. Otherwise: everyone in Studio. In live servers, only the players in `CmdrService`'s `ADMIN_USER_IDS`, the game's owner, or (for group games) members at or above `MIN_ADMIN_GROUP_RANK`. The server marks allowed players with the `CmdrAdmin` attribute, and `Client/Core/CmdrController` only loads the console for them.
- **Adding a command:** two ModuleScripts in `src/Server/Cmdr/Commands/`:
  - `<Name>.luau`: the definition (`Name`, `Aliases`, `Description`, `Group`, `Args`). It's replicated to clients, so it must not require server modules.
  - `<Name>Server.luau`: `return function(context, ...args) ... return "result message" end`, runs on the server. It can require server services.
  - Use `Group = "DevTesting"`. See `GiveCurrency` as the example, and Cmdr's built-in types (`players`, `integer`, `string`, ...) for `Args`.
  - `help` is our own (`Server/Cmdr/Commands/Help.luau`, replacing Cmdr's): it lists every registered command automatically, Boomerang (`DevTesting`) commands first.
- **Never** make a command skip the permission hook, and don't require Cmdr from a module that runs on the client.
- The old chat commands (`CommandService`) have all moved to Cmdr and the chat command system is **obsolete**. Its code is deliberately kept, disabled, as a reference: don't delete it, and don't add new chat commands.

## Missing game items and values (important)

If a prompt, task or note mentions a game item or value that doesn't exist in the code yet, and the task can be partly done with a placeholder, **create a placeholder** and mark it `-- TODO:RELEASE placeholder`. This applies to things like a badge, item, gamepass, product, asset/animation/sound ID, price or config value.

- Put the placeholder where that kind of value is normally registered (`MarketplaceItems`, `Items`, `ShopItems`, `Sounds`, `Animations`, `GlobalConfig`...), not inline in the logic that uses it.
- Example: `Wubaboo = 0, -- TODO:RELEASE placeholder`
- Mention every placeholder you added in the task Notes.
- This covers missing *values and IDs* only. Never invent missing *design* (how a gamemode or pickup should behave). Ask.

If a prompt mentions a larger *back-end feature* that doesn't exist yet, that may be a human error. Stop and ask rather than building unrequested architecture.

## Code conventions

- Luau with type annotations. Export types from the module that owns them.
- Naming: modules PascalCase, functions camelCase, constants `UPPER_SNAKE`, config-table keys PascalCase (`GlobalConfig.DefaultWalkSpeed`). Locals holding services/modules are PascalCase.
- Comments: `-- // Description`. Big sections: the long dashed separators from the templates.
- String interpolation is `` `text {value}` ``. **Not** `${value}`: in Luau the `$` is printed literally.
- **Indentation: tabs.** New files and new lines use tabs. Many existing files still use 3 spaces; until T-005 converts them, don't reformat lines you aren't otherwise changing (it makes diffs hard to review). In a file that is still space-indented, match its style so it stays consistent.
- Don't leave debug `print`s in finished work. Use `warn` for real problems.
- TODOs: `-- TODO:` (general), `-- TODO:VITAL` (blocks the current milestone), `-- TODO:RELEASE placeholder` (must be replaced before release).

## Workflow for agents

- **Keep credit usage low.** Do the work well, but leave extensive testing and double-checking to Sol and the client: no play-testing, no throwaway test harnesses unless the logic is risky and hard to check by hand, and one syntax check per batch of changes rather than per file. Read only the parts of files you need (`grep` first), and keep task Notes short.
- **Minimise extra verification layers** unless the prompt asks for them. Sol would rather not spend tokens double-checking a feature that turns out to work fine.
- **Web research:** if online research starts using a lot of tokens, stop, put it on the back burner, and recommend Sol does it elsewhere (another agent/tool). Don't spend paid credits on long web research here.
- **Ask instead of guessing:** it's fine to halt a prompt partway, or not start a task at all, when an important question hasn't been answered. Sol would rather answer than have tokens spent researching something Sol already knows.
- **Never push to GitHub.** Pushing is disabled for safety and isn't part of the agentic workflow. Commit only when a prompt asks; Sol pushes.
- **Player-facing wording:** avoid the word "kill" in stat names, UI text and leaderboard titles (Roblox audience/monetisation safety). Use "eliminations" for kills and "defeats" for deaths.

- **Tasks:** general tasks are in [TASKS.md](TASKS.md); each Epic's tasks are in `docs/epics/<epic>/TASKS.md`. Follow the "How to use this board" rules in TASKS.md for all of them: only pick up `Ready` tasks, never mark a task `Done`, and take new IDs from `Next free ID` in TASKS.md (IDs are global).
- **Epics** (large features): follow [docs/EPICS.md](docs/EPICS.md).
  - A new Epic starts with **Discovery**: copy `docs/epics/_TEMPLATE/` and work through `DESIGN.md` with Sol, one section at a time. The first question is always "full Epic, or general tasks?".
  - Present options and trade-offs; Sol decides. Record decisions in DESIGN.md as they're made.
  - **Never write an Epic's tasks before Sol approves its DESIGN.md**, and never mark an Epic Shipped.
- **When Sol says they're logging off:** summarize the session (focus on Epic progress if that was most of the work), then recommend what Sol can do next.
- **Git: don't commit or push**, and don't switch branches. Leave your changes uncommitted, move the task to `Review`, and fill in its Notes. Sol tests in Studio, then commits and pushes.
- **Renaming a file** whose name only changes in case (e.g. `Shopservice` → `ShopService`): the repo is on Windows with `core.ignorecase = true`, so git may not notice. Do the rename and flag it in the Notes so Sol can run `git mv` properly.
- Before you finish, list anything that needs checking in Studio. This includes all `.rbxmx` changes, which are XML and hard to review as text.
- When a task needs a decision, ask before writing code (see "Open questions" in each task). One clear question beats a guess that has to be undone.
- Don't guess at gameplay intent. Ask Sol, or note the question in the task.

### Agent log (`AgentLog.md`): when you commit or push

`AgentLog.md` in the repo root is a **local, git-ignored** record for undoing agent work. Whenever a prompt has you commit, append one entry per commit: date, commit SHA, task ID, a one-line summary, the files touched, and how to undo it (normally `git revert <sha>`; note anything a revert won't undo, such as data saved in a DataStore or instances changed in Studio). This lets a later prompt ("undo T-027") be handled quickly and safely.

### Commits log (`Commits.txt`)

`Commits.txt` in the repo root is a **local, git-ignored** log of finished changes that Sol reports to the client at the end of each work day.
- When you move a task to `Review`, **append** an entry under today's date heading (create the heading if it's missing; newest day at the bottom).
- One line per change, written for the client: what changed and why, in plain language, no file paths or code. Add the task ID at the end.
- Never delete or rewrite existing entries; Sol curates them.
