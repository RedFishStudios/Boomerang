# Decoy / NPC-Bot system: Tasks

Epic task list. Format and rules: "How to use this board" in [TASKS.md](../../../TASKS.md). Design: [DESIGN.md](DESIGN.md).
Take new IDs from the `Next free ID` line in [TASKS.md](../../../TASKS.md), reserved on `main` first ([GIT_WORKFLOW.md](../../GIT_WORKFLOW.md#2-reserve-a-task-id-before-adding-any-new-task)). Every task here has `Epic: Decoy`.

Implementation tasks are written after Sol approves [DESIGN.md](DESIGN.md). Only the asset dependency below is parked now.

---

## Ready

## In Progress

## Review

### T-081 · Decoy can be hit → eliminate + smoke poof
- **Priority:** P0
- **Owner:** Agent
- **Epic:** Decoy
- **Area:** Server / Shared
- **Files:** `Server/Core/BotService.luau` (hit handling + poof), `Server/Logics/BotBehaviors/Decoy.luau` (hit rules), `Shared/Logics/WeaponLogics/Boomerang.luau` (bot hit routing), `Shared/Utils/RaycastsUtility.luau` (bots never obstruct), `Shared/Constants/CollisionGroupConstants.luau` (new `Bots` group), `Shared/Constants/GlobalConfig.luau` (`CanHitSelfDecoy`)
- **Blocked by:** T-079

**Problem / goal**
An enemy boomerang eliminates the decoy; it poofs into smoke. Only enemies can — the owner can't hit their own decoy unless `GlobalConfig.CanHitSelfDecoy` is on, and teammates follow the team's friendly-fire rule (`GameTeamLibrary.areEnemies`). No stat changes.

**Done when**
- [ ] An enemy boomerang pops the decoy into smoke; the owner and teammates can't hurt it; no stat changes.

**Test in Studio**
- `spawndecoy`, then have an enemy (or a second client) hit it with a boomerang → it poofs (DecoySmokePoof, 1.5 s). With `CanHitSelfDecoy` off, your own boomerang should pass through it (no block, no kill). The decoy should also poof when its 4 s lifetime ends. In a team mode, a teammate can't kill it.

**Notes**
- Implemented on branch `agent/T-081-decoy-hittable` (lane `Boomerang-lanes/T-077-telekinesis`).
- New `Bots` collision group (Sol's call): collides with arena walls/floor/Default like a player and is detectable by `ThrownWeapons`, but NOT with `Players`, so a decoy passes through players. The rig root + hitbox use it; the hitbox is now `CanQuery = true`.
- Boomerang hit path: `spherecastCharacterHitbox` also includes the `Bots` workspace folder; `damagedPlayer` routes a victim carrying a `BotId` attribute to `BotService.onWeaponHit` (server only), which asks the behavior's `onHit` and despawns with reason `eliminated`. No `WeaponKilledPlayer` for bots → no stats.
- `RaycastsUtility.getProjectileObstructionParams` also excludes the `Bots` folder, so a decoy never blocks a boomerang as an obstruction.
- Smoke: `BotService.despawn` plays the behavior's `DespawnParticle` (`DecoySmokePoof`) at the rig position for 1.5 s via `ParticlesLibrary`, on every despawn except round-end teardown. Decoy sets it in `start`.
- **Needs the `DecoySmokePoof` asset present in `Shared/Assets/Particles` — it is not in the repo working copy yet; if it is missing the poof silently no-ops (ParticlesLibrary warns).**

## Backlog

### T-078 · Smoke particle for the decoy poof
- **Priority:** P2
- **Owner:** Sol
- **Epic:** Decoy
- **Area:** GUI / Assets
- **Files:** (particle asset) + wherever bot/decoy despawn VFX are registered

**Problem / goal**
When a decoy is hit/eliminated it poofs into a smoke particle. Sol provides the smoke particle asset; an agent wires it into the decoy's despawn VFX once the bot layer exists.

**Notes**
- Parked during Discovery (Sol, 2026-10-09). Blocked on the asset from Sol and on the bot layer existing.

### T-083 · Enable the Decoy pickup
- **Priority:** P0
- **Owner:** Agent
- **Epic:** Decoy
- **Area:** Shared
- **Files:** `Shared/Logics/PickupLogics/Decoy.luau`
- **Blocked by:** T-079, T-080, T-081

**Problem / goal**
Once T-079–T-081 pass Sol's Studio testing, remove `Disabled` from the Decoy pickup so it enters the spawn pool. Final review pass.

**Done when**
- [ ] Decoy spawns from the normal pickup pool and the whole flow works end to end.

**Notes**

## Done

### T-079 · Bot layer foundation (server entity + client-rendered avatar)
- **Priority:** P0
- **Owner:** Agent
- **Epic:** Decoy
- **Area:** Server / Client / Shared
- **Files:** new `Server/Core/BotService.luau`, `Client/Core/BotController.luau`, a shared bot entity + `BotBehavior` type; reuses `CharacterRenderController`, the Animate pose system, `CollisionService`, `HitboxService`

**Problem / goal**
A thin server-authoritative bot. The server spawns a single **collision part in the player collision group** (physics resolves environment collision), drives its movement, maintains its hitbox, and lets Roblox replicate the part's transform. Each client **clones the character model** (as it builds for players) and renders + animates the avatar following that part. A `BotBehavior` interface (`start` / `update` / `shouldDespawn`). Bots despawn on lifetime end and on round end / owner death / owner leaving. Server stays lightweight (part + hitbox + replication only).

**Done when**
- [x] A bot can be spawned server-side and is seen by every client as a moving, cloned avatar with a walk animation.
- [x] It collides with the environment like a player (shared collision group).
- [x] It despawns cleanly on its lifetime and on round end / owner leave, with no leaks.

**Test in Studio**
- Spawn one via the T-082 command; check another client sees it; walk it into a wall; end the round and confirm it's gone.

**Notes**
- Implemented first pass on branch `agent/T-079-decoy-bot` (shared with T-080/T-082). New `Server/Core/BotService.luau` (minimal Humanoid rig: HumanoidRootPart in the Players group, Humanoid moved with `:Move`, welded Hitbox kept non-queryable until T-081) and `Client/Core/BotController.luau` (clones the owner's rendered model and follows the bot every frame). Cleanup on round end / owner leaving.
- Studio checks: HIP_HEIGHT grounding of a limbless Humanoid, and whether the fixed facing drifts (AutoRotate off). (Walk animation now handled by T-084; the earlier slide was BotController anchoring every clone part, freezing the Animator.)
- Test with `spawndecoy` (see T-082).


### T-080 · Decoy behavior
- **Priority:** P0
- **Owner:** Agent
- **Epic:** Decoy
- **Area:** Shared / Server / Client
- **Files:** `Shared/Logics/PickupLogics/Decoy.luau`, a Decoy `BotBehavior` module
- **Blocked by:** T-079

**Problem / goal**
The first `BotBehavior`. Spawns on the player's boomerang throw (`SharedTasks.WeaponThrownTasks`), **consuming the pickup effect at spawn** (one decoy per pickup). Appearance matches the player. It **faces the player's facing at spawn** and **moves opposite the player's movement at spawn** (a **random** direction if the player is standing still); it strafes; it lives **4 seconds** (a tunable constant). Keep the pickup `Disabled = true` until T-083.

**Done when**
- [x] Picking up Decoy then throwing spawns exactly one player-looking decoy that strafes away as specified and vanishes after 4 s.

**Notes**
- Implemented first pass (same branch). `Server/Logics/BotBehaviors/Decoy.luau` + rewired `Shared/Logics/PickupLogics/Decoy.luau`: spawns on the owner's throw (`WeaponThrownTasks`) and consumes the effect (one decoy per pickup). Faces the owner's spawn facing, moves opposite the owner's movement at spawn (random if standing still), lives 4 s. Pickup stays `Disabled` (T-083 enables).
- Test: `spawndecoy`, then throw.


### T-082 · Cmdr command to spawn a decoy (testing)
- **Priority:** P1
- **Owner:** Agent
- **Epic:** Decoy
- **Area:** Server / Tooling
- **Files:** `Server/Cmdr/Commands/SpawnDecoy.luau` + `SpawnDecoyServer.luau`
- **Blocked by:** T-079

**Problem / goal**
A `DevTesting` Cmdr command to spawn a decoy for a player on demand (it's hard to reach by playing — needs the pickup and a throw).

**Done when**
- [x] `spawndecoy [player]` spawns a decoy for testing.

**Notes**
- Implemented (same branch). `spawndecoy` Cmdr command (`DevTesting`) + `PickupService.forceGrantPickup`, which grants a disabled pickup's effect for testing (plain `getpickup` won't, since Decoy isn't in the pool).



### T-084 · Bot/NPC animation states (pose-driven: idle / walk / fall)
- **Priority:** P0
- **Owner:** Agent
- **Epic:** Decoy
- **Area:** Server / Client
- **Files:** new `Client/Core/BotAnimator.luau`; `Server/Core/BotService.luau`, `Client/Core/BotController.luau`
- **Blocked by:** T-079

**Problem / goal**
Bots animate like players, as a general bot-layer capability (not decoy-specific). Reuses the Server-Authority "pose" contract (T-068): the rig root carries a replicated `pose` attribute (`Standing` / `Running` / `FreeFall`), and each client renders idle / walk / fall from it with the same walk/run speed blend players use. A behavior may override the state via `bot.Pose`.

**Done when**
- [x] A moving bot shows a speed-blended walk, idles when still, and plays the fall pose when airborne.
- [x] Works for the decoy with no decoy-specific animation code; future behaviors get animation for free.

**Test in Studio**
- `spawndecoy`, then throw: the decoy should walk (not slide) as it strafes away and idle if it stops; push it off a ledge for the fall pose.

**Notes**
- Implemented on branch `agent/T-084-bot-animation` (lane `Boomerang-lanes/T-077-telekinesis`).
- Root cause of the earlier slide: `BotController` anchored EVERY clone part, freezing the Animator. Fixed to anchor only the root (mirrors `CharacterRenderController`'s player render model, T-071).
- Server (`BotService`) derives pose from the rig Humanoid state + horizontal speed each step, set on the root (set-on-change); initial `Standing` at spawn; `bot.Pose` overrides.
- Client (`BotAnimator`, new) loads the clone's Animate tracks and drives idle/walk/fall + the walk/run blend from the pose attribute + root velocity; disables a LocalScript `Animate` clone so it can't double-drive. `BotController` owns one per bot.
