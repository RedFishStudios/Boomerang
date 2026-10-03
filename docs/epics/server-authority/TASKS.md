# Finalize Conversion to Server Authority: Tasks

Epic task list. Format and rules: "How to use this board" in [TASKS.md](../../../TASKS.md). Design: [DESIGN.md](DESIGN.md).
Take new IDs from the `Next free ID` line in [TASKS.md](../../../TASKS.md), reserved on `main` first ([GIT_WORKFLOW.md](../../GIT_WORKFLOW.md#2-reserve-a-task-id-before-adding-any-new-task)). Every task here has `Epic: Finalize Conversion to Server Authority`.

---

## Ready

## In Progress

## Review

### T-069 · Walk/run animations far too fast under Server authority
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client
- **Epic:** Finalize Conversion to Server Authority
- **Files:** `Client/Core/CharacterRenderController.luau`
- **Follow-up to T-068**, approved by Sol (2026-10-03).

**Problem / goal**
After T-068, rendered models animate in Server mode, but walking/running plays far too fast. Cause: T-068's walk/run blend fed the speed in studs/s straight into the Animate's blend formula. The Animate first divides by `WALK_SPEED_SCALE` (16 for R15), so at WalkSpeed 16 the tracks played about 16x too fast. Idle was fine (speed 1, checked in Studio).

**Done when**
- [ ] Walking and running play at a natural speed in Server mode, for your own and other players' models.
- [ ] Idle, jump and fall are unchanged.

**Test in Studio**
- Server mode, 2 players: walk and run (including any sprint or speed boosts) and watch both models' feet against the ground.

**Notes**
- Branch `agent/T-069-sa-walk-anim-speed`, lane `Github/Boomerang-lanes/docs-server-authority`.
- `syncPoseAnimations` now divides the horizontal speed by `R15_WALK_SPEED_SCALE` (16) before the blend, matching the Animate's `onRunning`.
- Not play-tested in motion: the agent's `Humanoid:Move` didn't move the character (the game's own movement controller likely overrides it), so the fix comes from the formula. Compiled with `luau-compile`.

## Backlog

## Done

### T-068 · Rendered character animations under Server authority
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client
- **Epic:** Finalize Conversion to Server Authority
- **Files:** `Client/Core/CharacterRenderController.luau`
- **Approved early** by Sol (2026-10-03), before the rest of DESIGN.md. See DESIGN.md "Known problems: P1".

**Problem / goal**
With `Workspace.AuthorityMode = Server`, the client-rendered character models don't animate. Confirmed in Studio (2026-10-03): the authoritative character's `Animate` is a ModuleScript (with `RunAnimate.Client` / `RunAnimate.Server`), so `extractAnimations` (which only looked for a `LocalScript`) never built the track map, and the output repeated `No synced animation tracks for player …` every frame. The Animate's HumanoidRootPart attributes (`pose`, `currentAnimId`, …) are set on the server and on the owning client.

**Done when**
- [x] In Server mode, every player's rendered model plays idle, walk/run (blended by speed), jump, fall, climb, sit and swim, and the tool-hold pose while a tool is equipped.
- [x] In Automatic mode, animations still work as before.
- [x] Custom game animations (`AnimationController`: throws etc.) still play on top.

**Test in Studio**
- Server mode, 2 players: watch your own model and the other player's: standing, walking slowly, running, jumping, falling off a ledge, with and without the boomerang equipped. Check the output has no `No synced animation tracks` spam.
- Same check once in Automatic mode.
- Die and respawn: animations come back on the new model.

**Notes**
- Branch `agent/T-068-sa-animation-sync`, lane `Github/Boomerang-lanes/T-068-sa-animation-sync`.
- `extractAnimations` now accepts an `Animate` that's a LocalScript or a ModuleScript.
- New: when the authoritative HumanoidRootPart has a `pose` attribute (Server authority), `sync()` drives the rendered model from it (`syncPoseAnimations`): pose → Animate folder (same map as the Animate's `POSE_TO_ANIM_NAME`, emotes as `EMOTE_<name>`), R15 walk/run blend from the authoritative root's horizontal velocity (same formula as the Animate), and `toolnone` while a Tool is equipped. Tracks are loaded once per rendered model and cleaned up on death/clear. Without the attribute (Automatic), the old track mirroring runs unchanged.
- **Unsure (please check):** other players' walk/run speed relies on the authoritative root's `AssemblyLinearVelocity` replicating; only testable with 2 players. Jump plays once per jump; the old mirroring's `AdjustSpeed(speed * 2)` isn't used in the new path.
- Not done here (follow-ups for the Epic): removing the `AnimateReplication` remote and the three unused Animate forks.
- Compiled with `luau-compile`; the change itself wasn't play-tested (the Studio checks above were read-only diagnosis).
- Passed Sol's Studio test (2026-10-03).
