# Boomerang: Task Board

The gameplay, code and tooling task board. See [CLAUDE.md](CLAUDE.md) for how the project works.

## How to use this board

- **Status is the section a task sits in.** To change it, move the whole task block to another section.
  `Ready` → `In Progress` → `Review` → `Done`. `Backlog` holds ideas that aren't ready to start.
- **Adding a task:** copy the template below into `Backlog` or `Ready`, and give it the next free ID (`T-###`).
- **Priority:** `P0` breaks the game or blocks the current milestone · `P1` needed for the current milestone · `P2` nice to have.
- **Owner:** `Agent` (an agent can do it), `Sol` (design decisions or assets only Sol can provide), or `Sol → Agent` (Sol decides first, then an agent implements).
- **Agents:**
  - Only pick up tasks in `Ready` whose Owner is `Agent`, or `Sol → Agent` once Sol has answered its questions.
  - If a task has **Open questions**, ask Sol before starting.
  - Move the task to `In Progress` when you start, and to `Review` when you're done.
  - Fill in **Notes** with what changed, what still needs testing in Studio, and any `TODO:RELEASE placeholder` values you added.
  - When moving a task to `Review`, add a client-facing line to `Commits.txt` (see CLAUDE.md).
  - Never move a task to `Done`; Sol does that after testing in Studio.

**Next free ID: T-017**

<details>
<summary><b>Task template</b> (click to expand, then copy)</summary>

```markdown
### T-### · Short title
- **Priority:** P0 / P1 / P2
- **Owner:** Agent / Sol / Sol → Agent
- **Area:** Server / Client / Shared / GUI / Data / Tooling
- **Files:** `path/to/file.luau`

**Problem / goal**
What's wrong, or what should exist.

**Open questions (ask Sol first)**
- (Remove this section if there are none.)

**Done when**
- [ ] Concrete, checkable outcome

**Test in Studio**
- Step to verify it works

**Notes**
(Filled in by whoever works on it.)
```
</details>

---

## Ready

### T-002 · Fix `${...}` in interpolated strings (prints a literal `$`)
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server / Client / Shared
- **Files:** `ProductService/init.luau`, `ProductLogics/Template.luau`, `UI/Gui/ElimMessage/init.luau`, `Library/GameTeamLibrary.luau`, `Library/MarketplaceLibrary.luau`, `Library/ParticlesLibrary.luau`, `Logics/Environment/MovingPlatform.luau`, `Logics/Environment/Portal.luau`

**Problem / goal**
Luau interpolation is `` `text {value}` ``. About 17 warn/error/print strings use JavaScript-style `${value}`, so every message shows a stray `$` (e.g. `Player with userId $123 not found`).

**Done when**
- [ ] No `` ` ``-string in `src/Server`, `src/Client` or `src/Shared` contains `${`.
- [ ] Only the `$` is removed; the messages are otherwise unchanged.

**Test in Studio**
- None needed beyond a normal server start with no new errors.

**Notes**

---

### T-003 · Remove leftover debug output from boot and ProductService
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server
- **Files:** `src/Server.server.luau`, `src/Server/Core/ProductService/init.luau`

**Problem / goal**
- `Server.server.luau` prints `Requiring <Module>` for every module on every server start (and those two lines are space-indented in a tab-indented file).
- `ProductService.init()` prints four `~~~~~` lines plus the module name and product ID for every product logic.

**Done when**
- [ ] The `Requiring` prints and the `~~~~~` / name / ID prints are removed. The warning for a product logic without an ID stays.
- [ ] Nothing else in those files changes.

**Test in Studio**
- Start a server: the output shows the "Server loaded" line and no per-module spam.

**Notes**

---

### T-004 · Clean up the `PickupLogic` type in PickupLibrary
- **Priority:** P2
- **Owner:** Agent
- **Area:** Shared
- **Files:** `src/Shared/Library/PickupLibrary.luau`

**Problem / goal**
`export type PickupLogic` declares `onPickup` twice with two different signatures (the second, `(userId, activationTime)`, is described as the replication/simulation callback) and has a stray `fart: string` field. With duplicate keys only one signature applies, so modules cast to `PickupLibrary.PickupLogic` aren't type-checked as intended.

**Open questions (ask Sol first)**
- What should the replication callback be called (e.g. `onReplicatedPickup`)? Check `PickupController` for what it actually calls before proposing a name.

**Done when**
- [ ] The type has one entry per callback, matching what `PickupService` / `PickupController` really call, with `Disabled: boolean?` included.
- [ ] The stray field is removed. No runtime behaviour changes.

**Test in Studio**
- None needed beyond a normal server start; pick up any pickup to confirm nothing changed.

**Notes**

---

### T-005 · Convert space-indented files to tabs
- **Priority:** P2
- **Owner:** Agent
- **Area:** Tooling
- **Files:** every `.luau` / `.lua` file under `src/` that uses 3-space indentation, **except** the "Leftover and reference modules" listed in CLAUDE.md

**Problem / goal**
Sol decided the standard is **tabs**. Many newer files use 3 spaces, and some mix both. Convert **leading indentation only**: each 3-space step becomes one tab. Mixed lines (tabs and spaces) are normalised to the indentation level they visually sit at.

- **Don't run StyLua**: it would also change call parentheses, line wrapping, quotes, etc. Use a script that only touches leading whitespace.
- Don't touch multi-line strings (`[[ ... ]]`) or block comments whose content alignment matters. Check the diff for these.
- Don't touch `.rbxmx`, `Packages/`, `ServerPackages/`, or the leftover/reference files.
- Do it in batches by folder (e.g. `Server/`, `Client/`, `Shared/`) so each batch is easy to review with `git diff -w` (which should show no changes).

**Done when**
- [ ] No in-scope file has a line whose leading whitespace contains spaces (except alignment inside block comments/strings, listed in Notes).
- [ ] `git diff -w` shows nothing for the converted files.

**Test in Studio**
- Start a server and join: no new errors in the output. (Whitespace-only change; this is just a sanity check.)

**Notes**

---

### T-006 · Port the template-era economy/item modules to the current save format
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server / Client / Data
- **Files:** `Server/Core/EconomyService.luau`, `Server/Core/ItemService.luau`, `Client/Core/EconomyController.luau`, `Client/Core/ItemController.luau`, `Shared/Constants/ItemConstants.luau`, `Shared/Constants/EquipmentConstants.luau`, `Shared/Constants/EconomyConstants.luau`, `Shared/Utils/EconomyUtil.luau`

**Problem / goal**
These came from the game template and use profile fields that don't exist in `ProfileTemplate` (`Currencies`, `ItemInventory`). They're auto-loaded: `ItemService` writes an `ItemInventory` field into every profile on load, and `EconomyService.transact` would error if called. **Sol's decisions:**
- Update them to the current save format (`Currency`, `Inventory` in `ProfileTemplate`; item data in `Shared/Referential/Items.luau` / `ShopItems.luau`).
- **There is only one currency: `Profile.Currency`, a number.** Remove every multi-currency mention (`Currencies`, `Cash`, `Gems`, `liquidCurrencies`, `{ [Currency]: number }` types...). Prices are a plain number (as in `Items`).

**Open questions (ask Sol first)**
- Should `ItemService` (grant/consume/purchase) become the one place that changes `Inventory`, with `ShopService` calling it? Or should `ShopService` keep its own logic?
- Some profiles may already have an `ItemInventory` field saved by `ItemService` (in Studio's `Dev` store, and possibly `Live`). Leave it, or clear it on load?

**Done when**
- [ ] No auto-loaded module reads or writes profile fields that aren't in `ProfileTemplate`.
- [ ] No code mentions more than one currency.
- [ ] `ItemConstants` either reads from `Items` or is no longer used, so there's one item list.
- [ ] Existing shop purchases still work.

**Test in Studio**
- Join, buy a shop item with currency: the balance and inventory update and replicate to the client.
- Rejoin: the purchase was saved. No errors from Economy/Item modules on load.

**Notes**

---

### T-016 · Move the chat commands to Cmdr (they have no permission check)
- **Priority:** P0 *(before release: any player in a live server can currently end rounds and grant themselves pickups)*
- **Owner:** Agent
- **Area:** Server
- **Files:** `src/Server/Core/CommandService.luau`, `src/Server/Core/RoundCyclingService.luau`, `src/Server/Core/PickupService.luau`, `src/Server/Cmdr/Commands/`

**Problem / goal**
`CommandService` creates TextChatCommands with no permission check: `/printgamestate`, `/endround`, `/setnextgamemode`, `/setnextmap` (RoundCyclingService) and `/getpickup` (PickupService) work for every player in live servers. Move them to Cmdr commands, which are permission-checked by `CmdrService` (T-015).

**Open questions (ask Sol first)**
- Remove the chat versions and `CommandService` entirely once the Cmdr versions exist, or keep them (restricted with `CmdrService.isAdmin`) because they're handy in chat?

**Done when**
- [ ] Each command exists in Cmdr with the same behaviour. Gamemode, map and pickup arguments use a custom Cmdr type or autocomplete list, so they can be tab-completed.
- [ ] Logic that needs private state (e.g. `endActiveRound`, `nextGamemode`) is exposed through a small public function on the owning service, not duplicated.
- [ ] No unrestricted chat command remains.

**Test in Studio**
- F2 → `endround`, `setnextgamemode HotPotato`, `setnextmap <map>`, `getpickup FireBoomerang`, `printgamestate`: each behaves as the chat command did.

**Notes**

---

## In Progress

## Review

### T-001 · ShopService never loads (file name casing), so the shop can hang the client
- **Priority:** P0 *(if confirmed: the client waits forever for a remote the server never creates)*
- **Owner:** Agent
- **Area:** Server / Client
- **Files:** `src/Server/Core/Shopservice.luau`

**Problem / goal**
The server boot script only loads modules whose name contains `Service` (case-sensitive). The file is named `Shopservice`, so `ShopService.init()` never runs and the `RequestPurchase` RemoteFunction is never created. `ShopController` calls `SimpleRemotes.getFunction("RequestPurchase")` at the top of the module, which on the client is a `WaitForChild` with no timeout. That would block `ShopController`, and the `Shop` GUI that requires it, forever.

**Done when**
- [x] The file is renamed to `ShopService.luau` (nothing else requires it by path; re-check before renaming).
- [x] Notes tell Sol that this is a case-only rename on Windows (`core.ignorecase = true`), so it must be committed with `git mv` (e.g. via a temporary name).

**Test in Studio**
- After Rojo syncs, check that `ServerStorage.Server.Core.ShopService` exists and the old `Shopservice` ModuleScript is gone.
- Open the shop and buy an item with in-game currency: currency goes down, the item is added, and the "item acquired" popup shows.

**Notes**
- Confirmed by Sol: the client showed `Infinite yield possible on 'ReplicatedStorage.__SIMPLEREMOTES.Functions:WaitForChild("RequestPurchase")'`, which blocked the client boot (UIController requires the Shop GUI, which requires ShopController).
- Renamed with `git mv -f`, so git records it as a rename (already staged). Commit it as is.
- Checked every other remote the client waits for: all are created by a server module that loads. (The shared Logics modules create theirs on the server when their services load them.)

---

### T-015 · Set up Cmdr as the developer console
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server / Client / Tooling
- **Files:** `src/Server/Core/CmdrService.luau`, `src/Client/Core/CmdrController.luau`, `src/Server/Cmdr/Commands/GiveCurrency.luau`, `src/Server/Cmdr/Commands/GiveCurrencyServer.luau`

**Problem / goal**
Sol wants Cmdr (installed through Wally, previously unused) as the in-game command console for developer testing.

**Done when**
- [x] `CmdrService` registers Cmdr's built-in commands and the project's commands in `Server/Cmdr/Commands`.
- [x] A server `BeforeRun` hook only lets admins run commands: everyone in Studio; in live servers the players in `ADMIN_USER_IDS`, the owner of a user-owned game, or group members at or above `MIN_ADMIN_GROUP_RANK`. A matching client hook exists, because Cmdr blocks all commands in live games without one.
- [x] `CmdrController` only loads the console (F2) for players with the server-set `CmdrAdmin` attribute.
- [x] Example command `givecurrency <players> <amount>` (useful for testing the shop).
- [x] CLAUDE.md explains how to add commands.

**Test in Studio**
- Press F2: the console opens. Run `help`, then `givecurrency me 100`, and check the currency updates in the shop.
- Run `kill me` to check a built-in command works.
- After publishing, join a live server with a non-admin account: F2 does nothing.

**Notes**
- Syntax-checked with `luau-compile`; not run in Studio.
- `TODO:RELEASE placeholder` values in `CmdrService`: `ADMIN_USER_IDS` (empty: add the developers' UserIds) and `MIN_ADMIN_GROUP_RANK = 255` (group owner only).
- Cmdr's built-in admin commands (`kick`, `teleport`, `announce`...) are all registered. If some shouldn't be available, `RegisterDefaultCommands` can take a list of groups.

---

### T-013 · Stop Rojo from overwriting the map package
- **Priority:** P1
- **Owner:** Agent
- **Area:** Tooling
- **Files:** `default.project.json`, `src/Server/Assets/Maps/PackageLink.gltf` (deleted)

**Problem / goal**
The maps moved from Rojo-synced `.rbxmx` files to a Studio package (commit 9fd09d6), but `src/Server/Assets/Maps/` stayed on disk holding only `PackageLink.gltf`, a file type Rojo ignores. Rojo therefore saw `Maps` as an empty folder it owns, and because nodes under a `$path` don't keep unknown instances, it deleted the package contents in Studio on every sync.

**Done when**
- [x] `src/Server/Assets/` is removed from disk.
- [x] `default.project.json` declares `ServerStorage.Server.Assets` as a `Folder` with `$ignoreUnknownInstances: true`, so Rojo creates the folder if missing but never touches its contents.
- [x] CLAUDE.md tells agents never to add files under `src/Server/Assets/`.

**Test in Studio**
- Restore the maps package to the correct version once more, then connect Rojo (or restart `rojo serve`): `ServerStorage.Server.Assets.Maps` and its maps stay unchanged.
- Start a round: `ArenaService` finds the maps as before.

**Notes**
- Checked with Rojo 7.7.0 (`rojo build` on a copy of the project tree): the project file is valid and `Assets` is created as an empty Folder.
- Sol: commit the deleted `PackageLink.gltf` along with `default.project.json`.

---

### T-007 · Record the leftover / reference modules
- **Priority:** P2
- **Owner:** Agent
- **Area:** Tooling
- **Files:** `CLAUDE.md`

**Problem / goal**
Several files are backups or references. Sol's decision: keep them all as references, and list them so agents don't touch them.

**Done when**
- [x] CLAUDE.md has a "Leftover and reference modules: don't touch" list: `ReferencePlayerModule/`, `src/Animate/`, `Server/Core/Animate.luau`, `Shared/Networking/Animate.luau`, `CharacterService/Old.luau`, `CharacterController/old.luau`, `ItemAcquired/OldTemplate.rbxmx`.

**Notes**
- `Server/Assets/Maps/PackageLink.gltf` was not kept: it was removed as part of T-013.
- `Server/Core/Animate.luau` and `Shared/Networking/Animate.luau` aren't required by any file in the repo. If something in Studio uses them, it isn't visible here.

---

### T-012 · Agentic setup: design doc, toolchain, package metadata
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Tooling
- **Files:** `docs/GAME_DESIGN.md`, `aftman.toml`, `wally.toml`

**Problem / goal**
Follow-ups to make agents more useful:
- [x] `docs/GAME_DESIGN.md`: transcribed from the client's "Boomerang! Technical Document" PDF (MVP spec), with a table of where the code differs (see T-014). The UI scope-of-work PDF only has a cover page so far.
- [ ] `aftman.toml` only pins Rojo. Add StyLua / Selene / Wally / wally-package-types? Mutatory moved to Rokit; should Boomerang too?
- [ ] `wally.toml` still names the package `larsb/roblox-game-template`.
- [x] Jecs removed (`wally.toml`, `wally.lock`, `Packages/`). Cmdr kept and set up (T-015).

**Done when**
- [ ] Each point is decided, done or dropped, and CLAUDE.md is updated.

**Notes**
- The remaining points need Sol's answers; the task stays in Review until then.

---

## Backlog

### T-014 · Spec vs. code differences: decide which to change
- **Priority:** P1
- **Owner:** Sol → Agent
- **Area:** Shared / Server
- **Files:** `docs/GAME_DESIGN.md` (bottom table), `GlobalConfig.luau`, `Logics/GamemodeLogics/Classic.luau`

**Problem / goal**
The client's MVP spec and the code differ in a few places (minimum players, respawn forcefield length, Classic's winners: top 3 + podium vs a single winner, boomerang bounces). Some may be deliberate.

**Open questions (ask Sol first)**
- For each row in the table: keep the code, or change it to match the spec?

**Done when**
- [ ] Each difference is either accepted (noted in GAME_DESIGN.md) or split into its own implementation task.

**Notes**

---

### T-008 · Release check: GlobalConfig values that are set for testing
- **Priority:** P1 *(before release)*
- **Owner:** Sol
- **Area:** Shared
- **Files:** `src/Shared/Constants/GlobalConfig.luau`

**Problem / goal**
`PlayersRequiredToStart = 1` is hard-set; the commented-out line suggests the intended value is `if isStudio then 1 else 2`. Also review `SkipVoting`, `ForceEquippedTool`, `ForceOverwritePickup` and the debug visualiser switches before release.

**Done when**
- [ ] Each value is confirmed for release, or marked `-- TODO:RELEASE`.

**Notes**

---

### T-009 · Daily rewards: notify the player and grant item rewards
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / GUI
- **Files:** `src/Server/Core/DailyRewardsService.luau`, `src/Shared/Referential/DailyRewards.luau`, `src/Client/UI/Gui/DailyClaims/`

**Problem / goal**
`DailyRewardsService` has two TODOs: "notify player" and "grant player the item".

**Open questions (ask Sol first)**
- What are the rewards per day (currency, items, both)? How should the player be notified (DailyClaims GUI, ItemAcquired popup)?

**Done when**
- [ ] Claiming a reward grants it and the player sees it.

**Notes**

---

### T-010 · Stub pickups (`-- STUD`): design and implement
- **Priority:** P2
- **Owner:** Sol
- **Area:** Shared
- **Files:** `src/Shared/Logics/PickupLogics/` (`BattleRoyale`, `DashNoclip`, `Decoy`, `ExplosiveBoomerang`, `ExtraBoomerang`, `IceBoomerang`, `MultiBoomerang`, `TelekinesisBoomerang`)

**Problem / goal**
These pickups are stubs (`Disabled = true`, marked `-- STUD` / `-- TODO`) with only a one-line description. Each needs its design written before an agent can implement it. Split into one task per pickup when a design is ready.

**Notes**

---

### T-011 · Stale header TODOs in GameTeamService, HitboxService, LobbyService
- **Priority:** P2
- **Owner:** Sol
- **Area:** Server
- **Files:** `src/Server/Core/GameTeamService.luau`, `src/Server/Core/HitboxService.luau`, `src/Server/Core/LobbyService.luau`

**Problem / goal**
The file headers say "TODO: figure out how teams should work" (HitboxService has the same text, probably copy-pasted). Teams now exist (TeamClassic, TeamElimination). Confirm and remove or rewrite the TODOs.

**Notes**

---

## Done
