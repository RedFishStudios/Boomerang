# 02 · Architecture

The conventions (folder layout, naming, module templates, boot order, networking rules) are in [`CLAUDE.md`](../CLAUDE.md), sections "Rojo tree", "Boot / module loading", "Where things go" and "Networking and in-process events". Read those first. This document covers what they don't: how the gameplay actually runs. All paths are relative to `src/`.

## Read these files first

1. `Shared/Constants/GlobalConfig.luau`: tuning values, debug switches and authority flags.
2. `Server/Core/RoundCyclingService.luau` with `Shared/Logics/GamemodeLogics/Classic.luau`: the round loop and the gamemode `setup()` / `teardown()` contract.
3. `Server/Core/WeaponService.luau` with `Client/Core/WeaponController.luau`: the remotes and the throw handshake.
4. `Shared/Logics/WeaponLogics/Boomerang.luau` (about 2400 lines): read its constants block, `throw`, `damagedPlayer` and `fireSnapshot` first.
5. `Client/Core/CharacterRenderController.luau`: the authoritative vs rendered character split.

## 1. Boot in brief

`Server.server.luau` and `Client.client.luau` collect modules **by name** (`Service` on the server, `Controller` / `Screen` on the client, `…Library` in `Shared/Library` on both), call every `init()` in order, then every `start()` in its own thread, then (Studio only) every `test()`. The name filter is case-sensitive: a module named `Shopservice` silently never loads. GUI modules under `Client/UI/Gui` are loaded by `UIController`, and logic modules (`Shared/Logics/*`, `Server/Logics/*`) by the service that owns them.

The usual cause of a client that "hangs on load": a client module `WaitForChild`s a remote the server never creates (because its service didn't load or didn't create it at load time). `SimpleRemotes` waits forever, with no timeout.

## 2. Round loop

- **`RoundCyclingService`** runs a per-frame state machine over `Shared/Constants/Enums/GameplayPhases`:
  `PendingPlayers` → `LobbyVoting` (30 s) → `LobbyEnded` (5 s, "New round in N") → `RoundActive` (5 min) → `RoundEnded` (10 s, still in the arena) → `LobbyVoting`…
  AFK players (the `OptedOut` attribute, set by `PlayerSessionService`) are left out of the player count and the vote.
- **State replication:** `Shared/Library/GameStateLibrary` holds `GameplayPhase`, `CurrentRoundData`, `CurrentTimerEndsAt`, `LivingPlayersInArena`, the vote data and so on as `ReactiveValue`s. The server writes them, and they replicate to every client. GUIs follow the phase by subscribing to `GameStateSnapshotLoadedTasks` (see any GUI's `registerGameplayPhase`).
- **Starting a round:** `setNextRound` writes `CurrentRoundData`, `ArenaService.setArena(map)` clones the map into `workspace.Arena`, `GameStateLibrary.RoundStartingTasks` fires, then the gamemode's `setup()` runs.
- **Gamemodes** (`Shared/Logics/GamemodeLogics/<Id>`): `setup()` sets teams (`GameTeamService.setFreeForAll` / `establishOppositionTeams`), subscribes to elimination tasks and stores its clean-up functions. `teardown()` works out the winner(s) and fires `GameStateLibrary.RoundFinishedTasks(winner, team, isTie, winners)`. A round ends either when the timer runs out (`endActiveRound` → `teardown()`) or when the gamemode fires `RoundFinishedTasks` itself. Per-mode settings (respawn, late join, storm, pickups/dash disabled, duration) are in `Shared/Constants/Gamemodes.luau`.
- **`SpawnService`** sends everyone to the lobby on `LobbyVoting` / `PendingPlayers` / `LobbyEnded`, and into the arena when a character loads mid-round if the mode allows it. **`ArenaService`** owns maps, spawn points, pickup spawn points, map config parts and death height.
- **`RoundResultsService`** works out the placements on the results screen: by eliminations in respawn modes, by survival time in last-one-standing modes. **`PedestalService`** puts the winner on the lobby's winner pedestal.
- **`StormCloseService`** would shrink the arena in modes with `StormClose = true`, but it's **switched off**: `begin()` returns at once with `warn("cancelling storm close service, for testing")`. `Elimination.luau` and `TeamElimination.luau` also call `begin` with the wrong arguments (`begin` takes `(x, y, centerPoint)`). Fix both before turning it back on.
- **`PickupService`** spawns one pickup at round start, then more on an interval up to a cap that scales with player count. Collection is a server-side distance check; the pickup class is rolled on collection (respecting the `NotCompatible` table). Effects replicate through `PickupLibrary`; dying ends every held pickup.
- **`BotService`** runs server-owned invisible rigs (root, Humanoid, Hitbox; collision group `Bots`) with a behaviour module (`start`, `update`, `shouldDespawn`). Clients draw them (`BotController`, `BotAnimator`). The only behaviour is `Server/Logics/BotBehaviors/Decoy.luau`, spawned by the Decoy pickup.

## 3. Characters: one authoritative, one rendered

The place runs with **`Workspace.AuthorityMode = Server`** (Roblox's server-authoritative physics). Every player effectively has two characters:

- **`player.Character`**: the authoritative R6 rig the server simulates. Only the `Torso` collides; there's no jumping in the arena, and `AutoRotate` is off. Clients make it invisible. Set `GlobalConfig.AuthoritativeCharacterDebugVisible = true` to see it at half transparency.
- **The rendered avatar**: `CharacterRenderService` builds a model from each player's HumanoidDescription and copies it into every player's `PlayerGui.CharacterReplication`. `CharacterRenderController` clones it into `workspace.Characters` and, every frame, moves it to the authoritative root and animates it (from the replicated `pose` attribute or by mirroring the authoritative tracks). It also handles ragdolls, elimination effects and disguises.

**Rule of thumb:** use `CharacterRenderController.getCharacterModel` for anything visual, and `player.Character` for physics and hits. Mixing them up (for example reading a tool's pivot from the wrong model) is the most common source of bugs here.

- **Facing:** `CharacterController` works out the player's yaw on the client (mouse ground point or touch angle) and sends it at 12 Hz (unreliable buffer). `CharacterService` rebroadcasts everyone's yaw in bulk at 12 Hz.
- **Dash** is predicted on the client, and the server agrees within limits.
- **`AnticheatService`** (a speed check) is **disabled** (`if 1==1 then return end`).

## 4. The boomerang

**Who owns what**

| Module | Role |
|---|---|
| `Server/Core/WeaponService.luau` | Server entry point. Remotes: `WeaponAim`, `WeaponAimState`, `WeaponAimCancel`, `Weapon` (a RemoteFunction; the throw), `WeaponRecall`, `WeaponEquipState`, `TelekinesisSteer` (unreliable), `RecallCharge`. Picks the tool class from the equipped skin, clamps the charge using its own aim timestamp, accepts the client's start position only within 12 studs of the root, then calls the tool's `LogicClass.throw`. |
| `Shared/Logics/WeaponLogics/Boomerang.luau` | The flight simulation, **run identically on server and clients**: fixed 1/60 s steps (at most 4 per frame), energy, bounces, portals, return, catch, clash/deflect, death, recall. Server-only parts sit behind `isServer` branches. |
| `Shared/Logics/WeaponLogics/Dead.luau` | Takes over when a boomerang runs out of energy out of its player's sight: the dying "ice" slide, the dead state, and the manual-recall charge. Sends its own 20 Hz snapshots. |
| `Shared/Library/ThrowTargetLibrary.luau`, `BoomerangCurveLibrary.luau` | Server only. Picks the enemy a throw curves toward (the clicked target on PC, otherwise a 20° cone) and bends the arc through it. |
| `Shared/Library/CatchLibrary.luau` | Normal vs heavy catch (by closing speed) and the heavy-catch push. |
| `Server/Core/ClashService.luau` | Every Heartbeat: two thrown weapons within 4 studs clash (1 s cooldown per pair). |
| `Server/Core/HitboxService.luau`, `Shared/Library/HitboxLibrary.luau` | A 10-stud-tall hitbox part per player. Immunity (dash, spawn shield) through the replicated `HitImmune` attribute. |
| `Shared/Library/LagCompensationLibrary.luau` | Server only. Remembers every hitbox's position for about 1.5 s; a hit sweep also counts hits where the thrower *saw* the target (ping + 0.1 s, capped at `LagCompensationMilliseconds = 200`). It only ever adds hits. Stab uses it too. |
| `Shared/Library/CombatLibrary.luau`, `Server/Core/CombatService.luau` | `attackHitPlayer` returns `Hit` / `Immune` / `Blocked` (a Shield breaks) / `Interrupted` (a gamemode callback) / `Ignored` (no round, or Hot Potato). On the server a hit eliminates and fires `CombatLibrary.PlayerKilledPlayerTasks`; `CombatService` sends the `ElimMessage` feed entry. Team checks use `Team` plus the `FriendlyFire` attribute. Bots go to `BotService.onWeaponHit`. |
| `Client/Core/WeaponController.luau` | Input and aiming; receives spawn, despawn and snapshot messages and reconciles them (`onSnapshot`). |
| `Client/Core/RecallChargeController.luau`, `DeadWeaponBeamController.luau` | Recall visuals (Summon animation, selection ring) and the beam to a dead boomerang, for every player. |

`Client/Core/BoomerangRenderController.luau` is an empty stub; boomerangs are drawn from `Boomerang.luau`, `ToolController` and `DeadWeaponBeamController`.

**A throw, step by step**

1. The client holds the aim (RMB, or the touch aim stick) and sends `WeaponAim`. On release it calls `Weapon:InvokeServer(toolId, direction, releasePos, aimTarget, clickedTarget)`. It doesn't spawn the boomerang itself; it only hides the held tool while it waits (0.75 s timeout).
2. The server runs `Boomerang.throw` and sends the reliable `ThrownBoomerangSpawned` (a buffer: owner, position, direction, speed, server time, curvature).
3. Every client, the thrower included, runs the same `Boomerang.throw`. A late arrival catches up along the arc (at most 0.35 s).
4. The server streams snapshots on the unreliable `ThrownWeaponReplication` at 30 Hz (code `RemoteCodes.Weapon.Unreliable.BoomerangSnapshot`), plus one immediately on bounces, portals, recalls and clashes. Snapshots re-create a boomerang a client is missing.
5. `ThrownBoomerangDespawned` ends it.

**Authority:** the server decides the curve, hits, energy, death, clashes and catches. The client predicts flight between snapshots, catches (it shows the boomerang again if the server doesn't confirm within 1.5 s) and the heavy-catch push. To see the server's view, run `toggleauthorityview` in Cmdr (a red ball at the server's position). Out-of-order messages and lasting mismatches are the open desync work (T-102, T-103).

**Tuning:** the boomerang's feel is in `GlobalConfig` (energy, recall, dying boomerang, catch, camera). Most of it can be changed live with Cmdr (`tuneboomerang`, `resetboomerang`, `sethitboxradius`, `setlagcompensation`, `setpingcompensation`) to try values. Copy the good ones back into `GlobalConfig`.

## 5. Camera and input

- **`CustomCameraController`:**
  - **Overhead** (the arena default): a scriptable camera tilted 30° with a narrow "fake orthographic" field of view (20°, widening to 60°) that frames the players and the boomerangs on the field. `TopDownCameraLibrary` holds live overrides (Cmdr `topdowncam`).
  - **Over-the-shoulder** (Roblox's standard camera, mouse locked): toggled with **C**, saved as the `OverShoulderCamera` setting.
  - The lobby always uses the standard camera.
- **PC:**
  - RMB: hold to aim, release to throw. The mouse ground point and clicked target are only used in the top-down view.
  - E: recall (hold to charge).
  - LMB: Stab.
  - Space: jump (lobby only).
  - Number keys: use-pickup slots.
  - T: taunt (after a round).
  - P: experimental alternative scheme (T-140).
- **Touch:**
  - `Client/UI/Gui/CustomTouchscreen`: aim thumbstick (it becomes the Recall button while your boomerang is dead), Dash, Slash, and a Taunt button after the round.
  - `HudButtons`, `UsePickupButtons`, and `Screens/InputScreen.luau` (template-era code reading the place's `InputUI`).
  - `TouchControlsSideController`: the left-handed layout.
- **Console:** not supported. `PlatformController` detects gamepads, and the only binding is ButtonY = recall (T-176).

## 6. Cross-cutting pieces worth knowing

- **`Shared/Constants/SharedTasks.luau`**: in-process event lists shared between systems on the same side.
- **`Shared/Utils/BufferUtil` + `Shared/Networking/RemoteCodes`**: compact binary messages for high-frequency remotes.
- **`Shared/Classes`**: `Signal`, `TasksList` (the in-process events), `Spring`, `ObjectPool`, `Scheduler`, `Atom`, `Stack`, `Counter`, `ConnectionsList`.
- **`DynamicCollisionLibrary`**: lets thrown weapons collide with moving objects (platforms, spinners).
- **`Shared/Logics/Environment/*`**: environment objects run on both sides by `EnvironmentService` / `EnvironmentController`, found by tag in the map (`validate` / `onObjectAdded` / `cleanup`).
- **Collision groups:** `Shared/Constants/CollisionGroupConstants.luau`, set up by `CollisionService`.

## 7. Tech debt in these systems

- **Leftover debug output:**
  - `print`s in `WeaponService.throwForPlayer`, `Boomerang.throw` and `CombatService`.
  - `AnimationController.init` binds **F** to a test animation.
- **Copy-pasted headers:** `CombatLibrary` and `CombatService` say "equipping tools". The "teams" TODOs in `GameTeamService` / `HitboxService` / `LobbyService` are stale (T-011).
- **`CombatLibrary` lazy-requires `RoundCyclingService`** to avoid a circular require.
- **Unused:**
  - `RemoteCodes.Weapon.Events.Throw` (the throw uses the `Weapon` RemoteFunction).
  - Several `GlobalConfig` values marked "Unused" / "Old recall only".
  - The commented-out despawn of expired pickups in `PickupService`.
- **`GameTeamService`:** late joiners aren't yet put on the smallest team (TODO).
- **`BotService`:** `HIP_HEIGHT` is `TODO:VITAL`, and decoys' facing can drift.
