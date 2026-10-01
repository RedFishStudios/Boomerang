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

**Next free ID: T-052**

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

### T-033 · Boomerang throws faster and further
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Constants/Tools.luau`

**On hold (Sol, 2026-10-01): don't start this yet.**

*Update 2026-10-01: at Sol's request, `ClassicBoomerang.ThrowDistance` was raised 30 → 45 (+50%). Speed and the other tools are unchanged.*

**Problem / goal**
The client says the boomerang needs to move "way faster" and go decently further: **twice the throw distance and about 50% more speed**. `ClassicBoomerang` is currently `Speed = 60`, `ThrowDistance = 30`.

**Open questions (ask Sol first)**
- Apply the same multipliers to the other throwables (`Shuriken` 80/40, the 50/20 one), or only to `ClassicBoomerang`?

**Done when**
- [ ] `ClassicBoomerang` is `Speed = 90`, `ThrowDistance = 60` (and the others as Sol decides).
- [ ] Anything tuned to the old values (hitbox radius, aim arrow length, auto-recall timing) still looks right; list any you changed.

**Test in Studio**
- Throw on a few maps: the boomerang travels about twice as far and noticeably faster; hits, bounces and recall still work.

**Notes**

---

### T-047 · Lobby station framework (labels, glowing pads, proximity prompts)
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client / Server / Shared
- **Files:** New: e.g. `Shared/Library/LobbyStationLibrary.luau` (+ client/server parts); used by T-024, T-042–T-045

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. Every lobby station (pedestals, wheel, crates, group chest, portal) shares the same conventions: a world-space title above it, a glowing activation pad, a proximity prompt or info panel when approached, and locked/unlocked or active visual states. Build this once as a reusable, tag-driven framework (e.g. CollectionService tag `LobbyStation` plus attributes such as `StationId`, `Title`, `ActionText`) so each station only registers its callback. Sol provides the models and art; this task is the behaviour.

**Done when**
- [ ] A tagged part/model in the lobby gets a title label, prompt and pad highlight automatically.
- [ ] Stations register server-side handlers by `StationId`; prompts fire them; per-player visual state (e.g. claimed/locked) can be set from the server.
- [ ] Works with T-024 pedestals; no station-specific code in the framework.

**Notes**
- Ask Sol for the tag/attribute names if a convention already exists in the place.

---

### T-048 · Track more player stats
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server / Data
- **Files:** `Shared/Data/ProfileTemplate.luau`, `Server/Core/PlayerStatService.luau` (or a new `StatsService`), `CombatLibrary`, `AbilityService`, `PickupService`, `RoundCyclingService`

**Problem / goal**
Save these lifetime stats in the profile (only Eliminations exists today):
- times each ability was used (e.g. Stab, Dash) and each pickup was acquired (e.g. FireBoomerang): per id
- time played
- rounds played (only rounds the player was in from start to finish)
- rounds won
- eliminations (already tracked as `Elims`)
- **defeats** (deaths). Never use the word "kill" in stat names or player-facing text (see CLAUDE.md).
Use `EconomyService`-style owner functions so other code doesn't write these fields directly.

**Open questions (ask Sol first)**
- Should the existing `Losses` field stay (round losses), be renamed, or be dropped? (Never repurpose a shipped field.)
- Does "rounds won" count team wins for every team member, and ties?
- Are these shown anywhere yet (leaderboards T-032, a stats panel), or only saved for now?

**Done when**
- [ ] New fields in `ProfileTemplate` (type + `get()`), filled by `Reconcile` for existing profiles.
- [ ] Each stat increments in exactly one place; time played is saved on leave/autosave.
- [ ] A Cmdr command shows a player's stats (for testing).

**Notes**

---

## In Progress

## Review

### T-051 · Touch controls follow the player's current input
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client
- **Files:** `Client/Core/PlatformController.luau`, `Client/UI/Screens/InputScreen.luau`

**Problem / goal**
Players can switch input mid-game. Touching the screen while on keyboard/mouse shows the touchscreen GUI; using keyboard/mouse while on touch hides it.

**Done when**
- [ ] Keyboard/mouse → touch: touchscreen GUI (CustomTouchscreen + mobile buttons) appears.
- [ ] Touch → keyboard/mouse: it disappears.

**Test in Studio**
- Touch-screen laptop (or a phone/tablet with a keyboard/mouse): start on mouse, tap the screen, then move the mouse / press a key. Repeat starting on touch.
- On mobile, typing in chat with the on-screen keyboard must not hide the touch controls.
- Studio's device emulator may not reproduce mixed input well; a real device is the reliable test.

**Notes**
- `PlatformController` is now the single source of truth: `InputScreen` used `PreferredInput` (via `DeviceUtil`) while `CustomTouchscreen` used `PlatformController`, so they could disagree. `InputScreen` now listens to `DominantControlSchemeChanged`. `DeviceUtil` is untouched (now unused).
- Fixes in `PlatformController`: unmapped input types (Focus, TextInput...) no longer flip the scheme to PC (this could hide touch controls on mobile when the window regained focus); mouse buttons/wheel and gamepads 5–8 are now recognised; keyboard input while typing in a TextBox is ignored; the starting scheme uses the last input / `PreferredInput` instead of assuming touch on any touch-capable device (touch laptops started in touch mode).
- Roblox's own thumbstick/jump button (`TouchGui`) is switched by the PlayerModule, not by this code.

---

### T-028 · Water kills the player, with a splash
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Logics/Environment/Water.luau`, `Shared/Library/CombatLibrary.luau`, `Shared/Library/ParticlesLibrary.luau`, `Shared/Assets/Particles/`

**Problem / goal**
Stepping into water kills the player. A splash effect plays on the player and they fall through the water, so it reads as falling in and dying.
- Use the normal death path (`CombatLibrary` / death reason) so death screens, elim messages and gamemode scoring behave like other environmental deaths (see `DeadlyPart`).
- If there's no splash particle yet, add a placeholder entry and mark it `-- TODO:RELEASE placeholder`.

**Done when**
- [ ] Touching water kills the player once, with a splash effect and the character sinking through the water.
- [ ] The death counts the same way as other environment deaths (death screen shows a non-player cause).

**Test in Studio**
- Walk into water in each map that has it: splash, sink, death screen, respawn where the gamemode allows.

**Notes**
- Server-side in `Water.luau`: on touching water, after the `PlayerEnteredWater` listeners run (so electrified water keeps its elim credit), the player is killed via `CombatLibrary.applyDamageToHumanoid` with cause label "Drowned". Only once per life (`Drowned` attribute on the character).
- Sinking: new collision group `SinkingPlayers` (like `Players` but without `WaterParts`). The server puts the dead authoritative character in it; `CharacterRenderController`'s ragdoll uses it when the `Drowned` attribute is set, so the visible body falls through the water.
- Splash: `ParticlesLibrary.emit` at the water's surface. **`TODO:RELEASE placeholder`:** `Shared/Assets/Particles/Splash.rbxmx` is a basic hand-written droplet burst; replace it with a real effect.
- Also removed the two debug `print`s in `Water.onObjectAdded`.
- Water kills in every phase, lobby included, if the lobby has water.
- Water kills through the spawn ForceField: `TakeDamage` ignores damage while a ForceField is present, so drowning sets `Humanoid.Health = 0` directly and calls `CombatLibrary.notifyDeathReason` itself.
- Check in Studio: the `Splash.rbxmx` import (hand-written XML), the drowned ragdoll sinking, and what the body lands on under the water (it still collides with the floor and walls).

---

### T-016 · Move the chat commands to Cmdr (they have no permission check)
- **Priority:** P0 *(before release: any player in a live server can currently end rounds and grant themselves pickups)*
- **Owner:** Agent
- **Area:** Server
- **Files:** `src/Server/Core/CommandService.luau`, `src/Server/Core/RoundCyclingService.luau`, `src/Server/Core/PickupService.luau`, `src/Server/Cmdr/Commands/`

**Problem / goal**
`CommandService` creates TextChatCommands with no permission check: `/printgamestate`, `/endround`, `/setnextgamemode`, `/setnextmap` (RoundCyclingService) and `/getpickup` (PickupService) work for every player in live servers. Move them to Cmdr commands, which are permission-checked by `CmdrService` (T-015).

**Sol's decision:** all chat command functionality moves entirely into Cmdr, and the chat command system becomes obsolete (no chat commands are registered any more). **Don't delete the chat command code yet:** keep `CommandService` and the old `addCommand` blocks in place but disabled (e.g. commented out or behind a clearly named off switch), as a reference in case something goes wrong during the transfer.

**Done when**
- [x] Each command exists in Cmdr with the same behaviour. Gamemode, map and pickup arguments use a custom Cmdr type or autocomplete list, so they can be tab-completed.
- [x] Logic that needs private state (e.g. `endActiveRound`, `nextGamemode`) is exposed through a small public function on the owning service, not duplicated.
- [x] No chat command is registered any more; the old code is kept but disabled, with a comment pointing to the Cmdr replacements.

**Test in Studio**
- F2 → `endround`, `setnextgamemode HotPotato`, `setnextmap <map>`, `getpickup FireBoomerang`, `printgamestate`: each behaves as the chat command did.

**Notes**
- New Cmdr commands in `Server/Cmdr/Commands/`: `endround`, `setnextgamemode` (alias `nextgamemode`), `setnextmap` (`nextmap`), `getpickup` (`grantpickup`, gives the effect to the person running it), `printgamestate` (`gamestate`; shows the state in the Cmdr console instead of printing to the server output).
- New Cmdr types in `Server/Cmdr/Types/` (registered by `CmdrService`): `gamemode` (from `Gamemodes`), `map` (from `MapData`, since the map models are server-only; the server still checks the name against the loaded maps) and `pickup` (module names in `PickupLogics`; disabled stubs are listed but the server refuses them).
- New public functions: `RoundCyclingService.forceEndRound()`, `.setNextGamemode(id)`, `.setNextMap(name)`. `PickupService.grantPickupClassId` now returns `(success, message)` (it already existed with the same logic as `/getpickup`).
- Chat commands disabled with `CHAT_COMMANDS_ENABLED = false` in `CommandService` (`addCommand` does nothing). The old `addCommand` blocks are untouched, with a comment pointing to the Cmdr replacements.
- Not checked with Selene or the LSP (not available to the agent).

---

### T-040 · Research Blade Ball's lobby
- **Priority:** P1
- **Owner:** Agent
- **Area:** Design (research)
- **Files:** `docs/research/BLADE_BALL_LOBBY.md` (new)

**Problem / goal**
The client said: "anything they have in their lobby, we want in our lobby". Research the current Blade Ball lobby (Roblox) and write a list of every lobby feature, with a short description, screenshots/links where possible, and how it might map to Boomerang (existing system, new system, or asset-only).

**Done when**
- [x] `docs/research/BLADE_BALL_LOBBY.md` lists every lobby feature found (shops, pedestals, leaderboards, spin wheels, rewards, quests, social features, etc.), with sources.
- [x] Each feature is tagged: already in Boomerang / planned task (ID) / new.
- [x] No new tasks are created from it without Sol's approval; propose them in the doc instead.

**Notes**
- Written: `docs/research/BLADE_BALL_LOBBY.md`. It covers 11 physical lobby features and 11 lobby UI/meta systems, each tagged existing / planned / new / needs a client decision, plus a suggested order and sources.
- The Blade Ball fan wiki couldn't be read automatically; the doc lists its relevant pages to confirm in a browser. Lobby content changes with seasons, so a walkthrough of the live game is recommended before scoping.
- No tasks were created from it (as the task requires); Sol decides.

---

### T-034 · Projectiles go through portals
- **Priority:** P2
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Logics/Environment/Portal.luau`, `Shared/Logics/WeaponLogics/Boomerang.luau`, `Shared/Library/DynamicCollisionLibrary.luau`

**Problem / goal**
Portals currently teleport players only. A thrown boomerang (any projectile) should pass through a portal and come out of the linked one, keeping its speed and direction relative to the exit portal.

**Done when**
- [x] A thrown boomerang entering a portal continues from the paired portal with the same relative direction and speed.
- [x] Recall (auto and manual) still finds its way back, through the portal or by its normal path; describe which in Notes.
- [x] Clients and server agree on the boomerang's position after it passes through (no visible snapping beyond normal replication).

**Test in Studio**
- On a map with portals: throw through a portal and hit a player on the other side; recall it.

**Notes**
- New `Portal.getProjectileExit(origin, direction, distance, radius, lastExitAt?, lastExitPart?)`. Portal pairs are read from the current arena's `Functional` folder (attribute `ClassName = "Portal"`, the same layout `Portal.validate` expects), so the server and clients find the same portals without extra replication.
- `Boomerang.throw`'s step checks it before hits and obstructions. On entry, the boomerang jumps to the paired portal's Attachment (keeping its height) with its direction mapped through the pair: relative to the entry attachment, turned around, then relative to the exit attachment. If that would point back into the exit portal, it goes straight out along the exit attachment's facing. Speed and remaining throw distance are unchanged. A 0.25 s cooldown stops it from re-entering the portal it just left.
- **Convention it relies on:** each portal's Attachment faces *out* of its portal. This is also the direction players face after teleporting.
- Recall: returning boomerangs do not use portals. They take their normal path back to the player (with collision).
- No map in the place currently has a portal, so it couldn't be tried in a level. The math was tested in Studio with in-memory parts (never added to the place): head-on and angled entries, misses, short steps, the re-entry cooldown, and both directions through the pair.
- Syntax-checked with `luau-compile`; not play-tested.

---

### T-031 · Allow jumping in the lobby (instead of dash)
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server / Client
- **Files:** `Server/Core/CharacterService/init.luau`, `Shared/Logics/AbilityLogics/Dash.luau`, `Client/Core/AbilityController.luau`, `Server/Core/LobbyService.luau`, `Server/Core/SpawnService.luau`

**Problem / goal**
In the lobby, players can jump and can't dash. In the arena it's the reverse (current behaviour). `CharacterService` currently disables jumping for every character (`SetStateEnabled(Jumping, false)`, `JumpHeight = 0`).

**Done when**
- [x] Jumping is enabled while the player is in the lobby and disabled when they're sent to the arena (and re-enabled when they return).
- [x] Dash can't be used in the lobby. The jump input (Space / mobile jump) jumps in the lobby and dashes in the arena.
- [x] Jump height comes from config.

**Test in Studio**
- In the lobby: Space jumps, no dash. Enter a round: Space dashes, no jump. Return to the lobby: jumping works again. Repeat on mobile.

**Notes**
- New `Shared/Library/LobbyLibrary.isCharacterInLobby(character)` (the lobby-volume check `LobbyController` already used), so both sides can check.
- Jumping: `LobbyController` sets the local humanoid's `JumpHeight` to `GlobalConfig.LobbyJumpHeight` (7.2) and enables the Jumping state while in the lobby, and sets them back to 0/disabled in the arena. This is done on the client because the client simulates its own character; the server still disables jumping at spawn (`CharacterService`).
- Dash: `Dash.canActivate` returns false in the lobby (checked on the client and on the server).
- Input: new `AbilityController.useMovementInput()`: jumps in the lobby, dashes in the arena. Space and the mobile Dash buttons (`CustomTouchscreen`, `HudButtons`) now call it.
- Syntax-checked with `luau-compile`; not play-tested. Check that Roblox's default jump button/keys (if the default control scripts are active in the place) behave the same.

---

### T-030 · Make the server-authoritative character invisible
- **Priority:** P2
- **Owner:** Agent
- **Area:** Client
- **Files:** `Client/Core/CharacterRenderController.luau`

**Problem / goal**
Each player has a server-authoritative character (physics/hits) and a client-rendered model. The authoritative character should never be visible. `everyFrame` currently sets it to transparency `0.5` when no rendered model exists (and `1` only during a disguise).

**Done when**
- [ ] The authoritative character is fully invisible (transparency 1) for every player at all times, including before the rendered model loads.
- [x] Hitbox parts keep their current behaviour (they're already skipped).

**Test in Studio**
- Join with 2 players: only the rendered models are visible, including right after spawning and respawning.

**Notes**
- `CharacterRenderController.everyFrame` now keeps the authoritative character fully invisible (transparency 1, including the face decal) while the rendered model exists or is still loading. It was 0.5 before. Hitbox parts are still skipped.
- `GlobalConfig.AuthoritativeCharacterDebugVisible` (default `false`) brings back the 0.5 view for debugging.
- **Fallback (deviation from "invisible at all times", please confirm):** if a player's rendered model **failed to load**, the authoritative character is shown (transparency 0), so the player doesn't become invisible. Controlled by `GlobalConfig.ShowAuthoritativeCharacterOnRenderFailure` (default `true`). This matters right now: the Studio output log is flooded with `recently failed to load replicated model for Soulsplosion`, i.e. rendered models are failing to load in Studio play-tests. That's worth its own investigation.
- Syntax-checked with `luau-compile`; not play-tested.

---

### T-027 · Explosive boomerang: lasts the whole effect and returns 50% faster
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Logics/PickupLogics/ExplosiveBoomerang.luau`, `Shared/Logics/WeaponLogics/Boomerang.luau`

**Problem / goal**
The explosive boomerang currently only explodes once. The effect should stay active after the first explosion (every throw explodes until the pickup effect ends), and while it's active the boomerang returns to the player's hand **50% faster** than now.
- The module is still marked `-- STUD` / `-- TODO`; check what's implemented before changing it.

**Done when**
- [x] Every throw explodes while the effect is active; the effect ends on its normal timer/conditions.
- [x] Return speed while the effect is active is 1.5x the normal return speed, set from a config value, not hard-coded.
- [x] The `-- STUD` / `-- TODO` header is removed if the pickup is now complete, and `Disabled` is removed if set.

**Test in Studio**
- `getpickup ExplosiveBoomerang` (chat) or the Cmdr equivalent: throw several times, each throw explodes; the boomerang comes back visibly faster.

**Notes**
- The effect no longer ends after the first explosion: every throw explodes (at the end of the throw, or on its first kill, once per throw) until the effect times out (`GlobalConfig.GenericEffectTimeout`, 15 s).
- **"Returns 50% faster", two parts (please confirm this matches the client):**
  - After an explosion the boomerang doesn't fly back: it's removed and the weapon is locked, then reappears in hand. That lock is now 3 s / 1.5 = **2 s** (was 3 s).
  - A boomerang that does fly back while the effect is active (e.g. manually recalled before the end of the throw) returns at **1.5x** speed (`Boomerang.recall` checks `PickupLibrary.hasPickupEffectActive`, which is replicated, so client prediction matches).
  - One config value drives both: `GlobalConfig.ExplosiveBoomerangReturnSpeedMultiplier = 1.5`.
- Picking the pickup up again while it's active refreshes its subscriptions instead of doubling them. Removed the `-- STUD` / `-- TODO` header (no `Disabled` flag was set).
- Syntax-checked with `luau-compile`; not play-tested.

---

### T-026 · Menus can lock the screen in the over-the-shoulder camera
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client / GUI
- **Files:** `Client/UI/UIController.luau`, `Client/Core/CustomCameraController.luau`, `Client/UI/Gui/*`

**Problem / goal**
In the in-game over-the-shoulder camera the mouse is locked/hidden, so a clickable GUI that appears during a round (e.g. Shop, Daily Claims, Voting, ItemAcquired with buttons) can't be clicked or closed, and the player is stuck. Audit every GUI that can open during a round and make sure the mouse is freed while it's open (e.g. a `Modal` button or `UserInputService.MouseBehavior`/`MouseIconEnabled` handled centrally in `UIController` for menu-type GUIs), and restored when it closes.

**Done when**
- [x] Opening any menu-type GUI while in the arena camera frees the mouse; closing the last one restores the camera's mouse lock.
- [x] GUIs that shouldn't open during a round are listed in Notes (ask Sol whether to block them).

**Test in Studio**
- During a round, open each menu (shop, daily claims, settings...) with keyboard/HUD buttons and close it with the mouse.
- Repeat on gamepad and on a mobile emulator.

**Notes**
- New `Client/Core/MouseUnlockController`: every frame, if any open gui has `RequiresMouse = true` (`UIController.isMouseRequired()`), it shows an invisible `Modal` button (Roblox's standard way to free a locked mouse) and keeps the cursor visible. When the last one closes, it hides the button and re-hides the cursor if the camera is in the arena's Regular (over-the-shoulder) mode.
- Flagged `RequiresMouse = true`: Shop, DailyClaims, Voting (the guis with clickable buttons that open as menus).
- Not flagged: HudButtons and CustomTouchscreen (always on screen, so flagging them would never re-lock the mouse), and the notification-style HUDs (no buttons). If HudButtons should be clickable in the over-the-shoulder camera, that needs a separate decision (e.g. holding a key to free the mouse).
- No gui is blocked from opening during a round; ask Sol if any should be.
- Syntax-checked with `luau-compile`; not play-tested (Sol declined the Studio play-test).

---

### T-023 · Assassin: let players join mid-round
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared / Server
- **Files:** `Shared/Constants/Gamemodes.luau`, `Shared/Logics/GamemodeLogics/Assassin.luau`, `Server/Core/RoundCyclingService.luau`, `Server/Core/SpawnService.luau`

**Problem / goal**
New players should be able to join an Assassin round in progress. They're immediately given a target, and are added to the loop that fairly assigns assassins and targets for the rest of the round.
- `Gamemodes.Assassin` currently has `LateJoinEnabled = false`.
- `Assassin.luau` already subscribes `addMember` to `GameStateLibrary.PlayerAddedToArenaTasks`, which assigns the newcomer a target and fills in targetless members. Check that this path is complete once late join is on (and that it also works for players who rejoin).

**Done when**
- [x] `LateJoinEnabled = true` for Assassin.
- [x] A player joining mid-round spawns into the arena, gets a target at once, and becomes someone's target as soon as fairly possible.
- [x] Nobody is left without a target or hunted by two assassins because of the join.

**Test in Studio**
- Start Assassin with 2 players, then join a 3rd mid-round (Studio local server, 3 players): the newcomer gets a target and the target arrows/GUI update for everyone.
- Leave and rejoin mid-round: no errors, assignments stay consistent.

**Notes**
- `Gamemodes.Assassin.LateJoinEnabled = true`. Late joiners already reach `Assassin.addMember` through the normal spawn path (`SpawnService` → `LivingPlayersInArena` → `PlayerAddedToArenaTasks`).
- New `giveAssassin()` in `Assassin.luau`: a member nobody is hunting (a late joiner, or a respawning player) gets an assassin right away. A hunter whose target already has several assassins is redirected to them; otherwise they're spliced into the ring (a random hunter now hunts them, and they take over that hunter's old target).
- Checked with a simulation harness running the real target functions (200 random runs of joins, deaths/respawns and leaves): with 2+ members, every member always had a target and an assassin. Not play-tested with real players (needs a multi-client Studio test).

---

### T-009 · Daily rewards: grant item rewards and notify the player
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server / Client / GUI
- **Files:** `Server/Core/DailyRewardsService.luau`, `Shared/Referential/DailyRewards.luau`, `Client/UI/Gui/DailyClaims/`, `Client/UI/Gui/ItemAcquired/`

**Problem / goal**
Claiming a login reward must grant it and tell the player.
- Item rewards: `DailyRewardsService` still has `-- TODO: grant player the item`. Grant them with `ItemService.grantItem` (T-006).
- Notification: show the reward on the client with the ItemAcquired popup (items) and a currency popup/message (currency). Use the existing ItemAcquired GUI; final visuals are Sol's (T-021).
- `DailyRewards` points at the `ExampleItem` placeholders; keep them and mark them `-- TODO:RELEASE placeholder` if they aren't already.

**Done when**
- [x] Item rewards are added to the Inventory; currency rewards keep working.
- [x] The player sees a notification for every claimed reward (item and currency).

**Test in Studio**
- Claim on day 1 (item) and day 2 (currency) (use Cmdr or reset `LastClaim` in Studio data): each grant shows a popup and is saved.

**Notes**
- Server: `DailyRewardsService` grants the reward first (`ItemService.grantItem` / `EconomyService.addCurrency`) and only then advances the streak, so a misconfigured reward doesn't use up the claim. The remote now returns `true, claimedDay`.
- Client: item rewards show the ItemAcquired popup through ShopController's existing Inventory listener; currency rewards show "Daily reward claimed! +N Currency" from `DailyClaims`.
- `TODO:RELEASE placeholder` added to the 4 `ExampleItem`/`ExampleWeapon` rewards in `DailyRewards.luau`.
- Play-tested in Studio: day-1 claim granted ExampleItem1 once and returned day 1; a second claim the same day was refused; the popup GUI was enabled; no client/server errors from these modules. The day-2 currency claim wasn't exercised (needs a day to pass or a reset of `LastClaim`).

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

**Done when**
- [x] No auto-loaded module reads or writes profile fields that aren't in `ProfileTemplate`.
- [x] No code mentions more than one currency.
- [x] `ItemConstants` either reads from `Items` or is no longer used, so there's one item list.
- [ ] Existing shop purchases still work.

**Test in Studio**
- Join, buy a shop item with currency: the balance and inventory update and replicate to the client.
- Rejoin: the purchase was saved. No errors from Economy/Item modules on load.

**Notes**
- Committed in 33a8428 ("Normalized handling of saved player currency values...").
- `EconomyService`: `getBalance`, `canAfford`, `addCurrency`, `spendCurrency`, `CurrencyChangedTasks`. `EconomyController`: `getBalance`, `canAfford`, `CurrencyChangedTasks`. `EconomyUtil.getPriceDisplayString(price: number)`.
- `ItemService`: `getAmount`, `hasItem`, `grantItem`, `consumeItem`, `purchaseItem` (returns a ResponseCode), `getInventory`, all on `Profile.Inventory` with item data from `Items`. `ItemController` reads `Inventory` from `PlayerDataController` and fires `ItemGrantedTasks` / `ItemConsumedTasks`.
- Removed: `EconomyConstants`, `ItemConstants`, `EquipmentConstants`, `RemoteCodes.Item` and the `"Item"` remotes (nothing else used them). `PlayerDataService` no longer lists the stale `BanData` field.
- `ProductLogicsUtil.grantGenericItemToPlayer`, `DailyRewardsService` (currency rewards) and the Cmdr `givecurrency` command now go through `ItemService` / `EconomyService`. `grantGenericItemToPlayer` now refuses item ids that aren't in `Items`.
- Decisions made without asking (say if you want them changed): `ShopService.purchaseItem` was left as is so the tested shop flow doesn't change. It duplicates `ItemService.purchaseItem`; making it delegate is a one-line follow-up. Old `ItemInventory` data already saved in some profiles is left alone (it's ignored, never read).
- Syntax-checked with `luau-compile`; not run in Studio.

---

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
- [x] Roblox Studio MCP: added to the Claude desktop config (`Roblox_Studio`, via `%LOCALAPPDATA%\Roblox\mcp.bat`); confirmed on 2026-10-01 that an agent can list Studio instances and read the place. Usage rules are in CLAUDE.md.
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

### T-017 · Hot Potato "bomb will explode" GUI (replace the placeholder)
- **Priority:** P2
- **Owner:** Sol
- **Area:** GUI
- **Files:** `Shared/Logics/GamemodeLogics/HotPotato/HotPotatoGui.rbxmx`, `HotPotato/init.luau`

**Problem / goal**
The Hot Potato "bomb will explode" GUI is a placeholder. Sol creates the final image assets and layout; an agent can wire up any behaviour changes afterwards.

**Notes**

---

### T-018 · Icons for every pickup effect
- **Priority:** P2
- **Owner:** Sol
- **Area:** GUI
- **Files:** `Client/UI/Gui/ItemAcquired/`, `Client/UI/Gui/Effects/`, `Shared/Constants/Icons.luau`

**Problem / goal**
Every pickup effect needs an icon, shown both in the pickup notification (ItemAcquired) and in the status-effects GUI (Effects). Sol creates the images; an agent registers the IDs in `Icons.luau` and hooks them up if that isn't automatic.

**Notes**

---

### T-020 · ItemAcquired: show 3D models in a ViewportFrame
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** GUI / Client
- **Files:** `Client/UI/Gui/ItemAcquired/` (`init.luau`, `Template.rbxmx`)

**Problem / goal**
ItemAcquired can only show images. When a tool/model is acquired (e.g. a new boomerang), it should show the model in a ViewportFrame instead.
- **Sol:** add a ViewportFrame (and camera framing preferences) to the ItemAcquired template.
- **Agent:** clone the item's model into it, frame it automatically (bounding box), optionally spin it slowly, and clean it up when the popup closes. Images stay supported.

**Open questions (ask Sol first)**
- Where does each item's model come from (e.g. `Shared/Assets/Tools/<ToolId>`)? Should `Items` entries get a `Model` field?

**Notes**

---

### T-021 · Login rewards (Daily Claims) GUI assets
- **Priority:** P2
- **Owner:** Sol
- **Area:** GUI
- **Files:** `Client/UI/Gui/DailyClaims/DailyClaims.rbxmx`

**Problem / goal**
The Daily Claims GUI uses placeholder visuals. Sol creates the final assets.

**Notes**

---

### T-022 · Finish the shop GUI assets
- **Priority:** P2
- **Owner:** Sol
- **Area:** GUI
- **Files:** `Client/UI/Gui/Shop/` (`Shop.rbxmx`, `ItemListingTemplate.rbxmx`, `TabButtonTemplate.rbxmx`)

**Problem / goal**
The shop GUI still has placeholder/progress visuals. Sol finishes the assets.

**Notes**

---

### T-024 · Shop pedestals in the lobby
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Client
- **Files:** New: lobby pedestal logic (e.g. an Environment logic or a `LobbyShopService`); `Shared/Referential/ShopItems.luau` (`CurrentDeal`)

**Problem / goal**
Lobby pedestals show a floating, slowly spinning model of the current sale item. Walking up to one shows a prompt to buy it.
- **Sol:** build the pedestal model(s) in the lobby (Studio) and tag/name them.
- **Agent:** spawn and spin the current deal's model over each pedestal (client-side is fine), add a ProximityPrompt, and buy through the existing purchase flow.
- **Sol: focus on Robux** (`MarketplaceLibrary.promptDeveloperProduct` with the item's `ProductId`), **but keep it scalable** so a Currency purchase option can be added later (e.g. a per-pedestal/per-item payment method, not Robux hard-coded into the prompt logic).

**Open questions (ask Sol first)**
- Is `ShopItems.CurrentDeal` the item to show, and does it rotate (daily/weekly)?
- How should pedestals be marked in the place (tag name / folder)?

**Notes**

---

### T-029 · Electric boomerang rework: chain kills
- **Priority:** P1
- **Owner:** Sol → Agent
- **Area:** Shared
- **Files:** `Shared/Logics/PickupLogics/ElectricBoomerang.luau`, `Shared/Library/CombatLibrary.luau`, `Shared/Assets/Particles/Electric*`

**Problem / goal**
Water now kills (T-028), so electrifying water and "zapping" players no longer make sense. **Remove those concepts entirely** (electrified water state, zapped animation/effect, `PlayZappedAnimation`, the dependency on `Water`).
New behaviour: when an electric boomerang kills a player, every other player within **5 studs** (configurable) of the victim is also killed, with an **electric arc** drawn between the two. The chain continues from each newly killed player to anyone within 5 studs of them. The thrower can never be affected.
- Chain kills should be credited to the thrower and go through the normal kill path (elim messages, scoring).
- **Sol: the chain skips the thrower's teammates** (use `GameTeamLibrary.areEnemies`).

**Open questions (ask Sol first)**
- "Has a chance to chain-kill": is the chain guaranteed for everyone in range, or is there a probability per link? If a chance, what value?
- Should there be a max chain length or a short delay between links (for the arcs to read well)?

**Done when**
- [ ] The old electric/water/zap code and remotes are gone; nothing else references them.
- [ ] Chain kills work as specified, with values (radius, chance, delay, max length) in config.
- [ ] Arcs show on all clients.

**Test in Studio**
- Group 3–4 test players within a few studs and kill one with an electric boomerang: the others die in a chain with arcs; the thrower never dies; players 6+ studs away survive.

**Notes**
- Depends on T-028 (water kills).

---

### T-032 · Lobby leaderboard of top eliminations, with a top-3 podium
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Client
- **Files:** New: e.g. `Server/Core/LeaderboardService.luau`; `Shared/Data/ProfileTemplate.luau` (`Elims`)

**Problem / goal**
Physical leaderboards in the lobby (see `docs/LOBBY_SPEC.md`): **Most Eliminations** (`Profile.Elims`; never title it "Kills") and **Most Wins** (`Profile.Wins`), top 30 each, with a podium where top players stand (as rigs/avatars). More boards may follow from T-048's stats.
- **Sol:** build the board and podium in the lobby.
- **Agent:** keep an OrderedDataStore of lifetime elims (updated on save/leave and periodically), refresh the board on an interval, and load the top 3 players' avatars onto the podium.

**Open questions (ask Sol first)**
- How often should it refresh? (**Sol: show the top 30 players.**)
- Global all-time only, or also weekly?
- Podium: the spec shows a single #1 display; the earlier request was a top-3 podium. Which, and for which board (or rotating)?
- **Sol:** the podium shows each player's currently equipped avatar, fetched once on server startup (no refresh needed).
- Studio data uses the `Dev` key; should the Studio leaderboard use a separate store too?

**Notes**

---

### T-035 · Manual recall to match the design doc
- **Priority:** P1
- **Owner:** Sol → Agent
- **Area:** Client / Server / Shared
- **Files:** `Client/Core/WeaponController.luau`, `Server/Core/WeaponService.luau`, `Shared/Logics/WeaponLogics/Boomerang.luau`, `Client/UI/Gui/HudButtons/`, `Client/UI/Gui/CustomTouchscreen/`

**Client spec (2026-10-01, supersedes the design-doc analysis below):**
- Recall range around the player: `GlobalConfig.BoomerangRecallRange` (30).
- Out of range when it would start returning: no auto-return. It loses momentum and drops into the dead state (as after a clash). Back in range by then: returns as normal (it can leave range, bounce back and still return).
- Once it starts losing momentum it can't resume auto-return, even back in range (`GlobalConfig.DyingBoomerangCanRecoverInRange`, default false).
- Manual recall works on a dying or dead boomerang: it moves toward the player only **while held**; releasing puts it back into the dead state. Tapping on a live boomerang just recalls it. Rapid press/release must be safe.
- **Pass 1 (done, in Review):** out-of-range death via `Boomerang.autoRecallOrDie` (server decides; the client follows the server's Clashed snapshot). **Pass 2 (done, in Review):** recall press/release goes to the server (`WeaponRecall` true/false). Dying/dead boomerang: `Boomerang.recallFromClashed` (returns while held, rises to hand height) and `Boomerang.stopRecallFromDead` on release; clients follow the server's snapshots. HUD Throw/Recall button is press-and-hold in recall mode. `DyingBoomerangCanRecoverInRange` is wired (hook from Boomerang into Clashed). Dead state now waits until the boomerang has landed.

**Problem / goal**
`docs/GAME_DESIGN.md` §2c: **hold** E / the mobile recall button to pull the boomerang back; releasing stops it where it is; it doesn't pass through walls, takes the fastest valid route, and slides along a surface when the shape allows (otherwise it gets stuck and the player must reposition). Today pressing E fires `WeaponRecall` once (a one-shot recall), and `HudButtons` has a "Recall" entry.

**Open questions (ask Sol first)**
- Hold vs. tap: should a tap still start a full recall, or does recall only move while held?
- Recall speed while held (same as auto-recall return speed?).
- When stuck against a wall with no slide, does it stay stuck until the player moves, or eventually give up and drop?
- Does manual recall still kill players it passes through on the way back?
- Mobile: where exactly does the recall button go (the design sketch puts it above Stab, left of Throw)?

**Done when**
- [ ] Recall behaves as described in GAME_DESIGN.md §2c on PC, gamepad and mobile.
- [ ] Server-authoritative: the server moves the boomerang; the client only sends hold start/stop.

**Notes**
**Agent analysis (2026-10-01): design doc vs. current code**

| Design doc (§2b–2c, §5) | Current code | Gap |
|---|---|---|
| Auto-recall after slicing through a player | Passes through players and keeps going; the "recall on hit" code in `Boomerang.throw` is commented out | **Intentional (Sol): keep it off** |
| Auto-recall after one ricochet | After the first bounce, the distance check switches to `ThrowDistance`, which has usually been reached, so it recalls right away | Matches in practice |
| 2+ surface hits: stops where it runs out of energy and waits for manual recall | When `energy` reaches 0 it calls `Boomerang.recall` (auto-returns). The "Exhausted" slow-down branch exists but only runs when recall transitions are off | Differs |
| **Hold** E / button to recall; releasing stops it where it is | E (or the mobile Throw/Recall button) sends one `WeaponRecall` event; the server runs a full recall to the hand. Releasing does nothing | Differs (the main gap) |
| Doesn't pass through walls; slides along a surface if it can, otherwise stuck until the player repositions | `Boomerang.recall` steers toward the player, slides along obstructions (tries both tangents), and holds still if both are blocked, resuming when the player moves | Matches |
| Fastest valid route | Greedy steering + wall sliding (no pathfinding) | Close enough; true pathfinding not recommended |
| Recall kills players on the way back | `damagedPlayer` runs during recall | Matches (doc doesn't say either way) |

**Suggested implementation**
1. **Hold-to-recall (server-authoritative):** `WeaponRecall` carries a boolean (`true` on press, `false` on release). Press: if the boomerang is out and not already returning, `Boomerang.recall(..., { Manual = true })`. Release: new `Boomerang.stopRecall(player, data)` disconnects the recall loop, sets a new `Resting` state (speed 0) and sends a snapshot. Pressing again resumes from there. Release only stops **manual** recalls, never auto-recalls.
2. **Client sync:** `WeaponController.onSnapshot` already starts a local recall when the state changes to `Returning`; add the reverse (`Returning` → `Resting` calls `stopRecall` locally).
3. **Exhaustion:** when `energy` hits 0, switch to `Exhausted` (let the existing slow-down run) and then `Resting`, instead of auto-recalling.
4. **Inputs:** E: `InputBegan` → press, `InputEnded` → release. Mobile/gamepad: a dedicated recall button that uses press/release (`MouseButton1Down` / `MouseButton1Up` + `InputEnded`). Its placement is Sol's call (ignore the game design doc's sketch). The Throw button's "Recall" mode either becomes hold-based too or goes away.
5. Keep the T-027 speed multiplier and the existing kill-on-return behaviour.

Order: (1)+(2) first (they're the core and can ship alone), then (3), then (4)'s mobile button once Sol decides the layout. Add a Cmdr command to put the boomerang in each state for testing (e.g. out of energy / resting).

---

### T-036 · Design: how weapons and skins are equipped and used
- **Priority:** P2
- **Owner:** Sol
- **Area:** Design
- **Files:** `Shared/Referential/Items.luau`, `Shared/Constants/Tools.luau`, `Server/Core/ToolService.luau`

**Problem / goal**
Decide how owned weapons and cosmetic skins are equipped and used (loadout screen? per-round choice? one equipped weapon + one skin?), and how that's saved in the profile. `GlobalConfig.ForceEquippedTool` currently forces `ClassicBoomerang`. Once decided, split into implementation tasks.

**Notes**

---

### T-037 · Player HUD buttons
- **Priority:** P1
- **Owner:** Sol → Agent
- **Area:** GUI / Client
- **Files:** `Client/UI/Gui/HudButtons/`

**Problem / goal**
The player needs a HUD with buttons. Known so far:
- **Currency**: shows the player's Currency; clicking opens a Robux shop tab to buy more Currency.
- **Shop**: opens the shop.
- **Quests**: opens quests (feature: T-038).
- **Achievements**: opens achievements (feature: T-039).
**Sol:** decide the full button list and make the assets. **Agent:** wire each button (Currency display via `EconomyController.CurrencyChangedTasks`, opening GUIs via `UIController`). Buttons for features that don't exist yet stay hidden.

**Open questions (ask Sol first)**
- Full button list and layout (PC and mobile)?
- Robux → Currency: which developer products/amounts? (Add placeholders in `MarketplaceItems` until they exist.)

**Notes**

---

### T-038 · Design: Quests feature
- **Priority:** P2
- **Owner:** Sol
- **Area:** Design
- **Files:** -

**Problem / goal**
"Address the quests feature": decide what quests are (daily/weekly? objectives? rewards?), how they're saved, and the GUI. Split into tasks once designed.

**Notes**

---

### T-039 · Design: Achievements
- **Priority:** P2
- **Owner:** Sol
- **Area:** Design
- **Files:** -

**Problem / goal**
"Figure out achievements": decide the list, rewards, whether they map to Roblox badges, how they're saved, and the GUI. Split into tasks once designed.

**Notes**

---

### T-041 · Lobby hub layout blockout
- **Priority:** P1
- **Owner:** Sol
- **Area:** Build (Studio)
- **Files:** Studio: `workspace.Lobby`

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. Block out a spacious central hub with walking lanes and zones: rewards (wheel, visible from spawn), crates (explosion + sword), social (group rewards), navigation (server portal with open space), competition (leaderboards + podium). Functional parity with the reference, not a copy of its art.

**Open questions (ask Sol first)**
- Functional parity (same kinds of stations) or close visual parity with the reference?
- Art direction, floating vs. grounded lobby, which stations must be visible from spawn?

**Notes**
- 🗣️ **Talk with Sol before starting.** Place-only work; agents can help place tagged stations once T-047 exists.

---

### T-042 · Prize wheel
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Client / Build
- **Files:** New: wheel station (uses T-047); `MarketplaceLibrary`, `PolicyLibrary`

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. A freestanding prize wheel on a pedestal with segmented rewards and a spin animation, used through a station prompt.

**Open questions (ask Sol first)**
- Rewards and their weights; is it cosmetic-only or can it affect gameplay?
- How spins are earned/bought: free per day, Currency, Robux (Robux-first like T-024?), codes (T-049), playtime?
- Spin animation length; is an "instant spin" Robux option wanted?

**Notes**
- 🗣️ **Talk with Sol before starting.**
- A paid random reward: must respect `PolicyLibrary.arePaidRandomItemsRestricted` and Roblox's rules on disclosing odds.

---

### T-043 · Explosion crates (normal + premium) with odds panel
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Client / Build
- **Files:** `Server/Core/LootBoxService.luau` and `Shared/Referential/LootBoxRates.luau` (currently empty stubs); crate stations (T-047)

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. Two crate stations side by side (a normal and a more elaborate premium crate), each with a world-space name and, when approached, a panel showing rarity odds (e.g. Rare / Legendary / a very rare tier). Build the crate logic generically in `LootBoxService` so T-044 reuses it.

**Open questions (ask Sol first)**
- Crate names, prices and currency (Robux-first like T-024? Currency?), reward tables and odds.
- What do "explosion" crates contain in Boomerang (elimination effects?)
- Do crates open in the lobby (animation) or just act as purchase points with the reward shown in the ItemAcquired popup?

**Notes**
- 🗣️ **Talk with Sol before starting.**
- Paid random items: `PolicyLibrary.arePaidRandomItemsRestricted` + odds disclosure required.

---

### T-044 · Sword (boomerang) crate station
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Client / Build
- **Files:** Crate station (T-047), `LootBoxService` (T-043)

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. A separate crate station for weapon cosmetics, visually distinct from the explosion crates. In Boomerang this is presumably a **boomerang skin** crate.

**Open questions (ask Sol first)**
- Is this a loot box, a fixed-item shop, or something else? Cost and contents.
- Depends on how weapons/skins are equipped (T-036).

**Notes**
- 🗣️ **Talk with Sol before starting.** Reuses T-043's crate logic.

---

### T-045 · Group Rewards chest
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Client / Build
- **Files:** New: group rewards station (T-047); profile field for claimed state

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. A large chest on a glowing pad with a "GROUP REWARDS" title. Players in the client's Roblox group can claim a reward; the chest shows locked/unlocked/claimed states.

**Open questions (ask Sol first)**
- The group ID, and is membership required?
- What's the reward, and is it one-time or on a cooldown?

**Notes**
- 🗣️ **Talk with Sol before starting.**

---

### T-046 · Server Selection portal
- **Priority:** P2 *(later: needs destinations first)*
- **Owner:** Sol
- **Area:** Design / Build
- **Files:** -

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. A large portal arch on a glowing ring with a sign, leading to other servers/modes/worlds.

**Open questions (ask Sol first)**
- What does it lead to in Boomerang? (Today there's a single server type; this needs other places or modes first, e.g. duels/ranked from `docs/research/BLADE_BALL_LOBBY.md`.)
- Physical selection (several portals) or a follow-up UI?

**Notes**
- 🗣️ **Talk with Sol before starting.** Probably later; nothing to build until destinations exist.

---

### T-049 · Redeem codes system
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Client / GUI
- **Files:** New: e.g. `Server/Core/CodesService.luau`, a server-only codes list, a client controller; GUI by Sol

**Problem / goal**
Players enter a code to receive a reward. Server: validates the code (case-insensitive), checks expiry and that the player hasn't redeemed it (saved in the profile), grants through `EconomyService` / `ItemService`, rate-limits attempts. Client: sends the code from the GUI and shows the result (ItemAcquired popup / message).

**Open questions (ask Sol first)**
- Reward types (Currency, items, wheel spins later?), expiry dates, limited-use codes?
- Where is the code entry opened (HUD button, settings)? GUI assets are Sol's.

**Done when**
- [ ] Codes live in a server-only module (never replicated).
- [ ] Redeeming works once per player per code and survives rejoin.
- [ ] A Cmdr command lists codes / resets a player's redeemed codes for testing.

**Notes**

---

### T-050 · HUD button for Daily Rewards
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** GUI / Client
- **Files:** `Client/UI/Gui/HudButtons/`, `Client/UI/Gui/DailyClaims/`

**Problem / goal**
Add a HUD button that opens the Daily Rewards (DailyClaims) GUI, ideally with an indicator when a reward is claimable. **Sol:** the button asset and placement. **Agent:** wire it to `DailyClaims.toggle()` and the claimable indicator.

**Notes**
- Part of the HUD button set in T-037.

---

## Done
