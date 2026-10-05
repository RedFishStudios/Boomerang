# Finalize Conversion to Server Authority: Tasks

Epic task list. Format and rules: "How to use this board" in [TASKS.md](../../../TASKS.md). Design: [DESIGN.md](DESIGN.md).
Take new IDs from the `Next free ID` line in [TASKS.md](../../../TASKS.md), reserved on `main` first ([GIT_WORKFLOW.md](../../GIT_WORKFLOW.md#2-reserve-a-task-id-before-adding-any-new-task)). Every task here has `Epic: Finalize Conversion to Server Authority`.

---

## Ready

## In Progress

## Review

### T-071 · Throw direction wrong under Server authority
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client, Server
- **Epic:** Finalize Conversion to Server Authority
- **Files:** `Client/Core/WeaponController.luau`, `Client/Core/CharacterController/init.luau`, `Client/Core/CharacterRenderController.luau`
- **Approved early** by Sol (2026-10-03). DESIGN.md "Known problems: P4".

**Problem / goal**
In Server mode the aim direction shows correctly on the player's own screen, but the thrown boomerang doesn't go where they aimed.

**Done when**
- [ ] In Server mode, the boomerang flies exactly where the player aimed (mouse, locked mouse, touch thumbstick), on their screen and on other players' screens.
- [ ] Automatic mode unchanged.

**Notes**
- Branch `agent/T-071-sa-throw-direction`, lane `Github/Boomerang-lanes/docs-server-authority`.
- Cause (confirmed in Studio by logging what the server receives): the client measured the mouse aim from the held tool's pivot, which under Server authority reported a stale spot ~40 studs from the character, so every throw went roughly the same way. The server already uses the client's direction as-is.
- Fix: `WeaponController.throwEquippedTool` aims from the rendered character's root (same origin as the aim arrow), and ignores the tool pivot as release position when it's more than 6 studs from the character.
- Also guarded the per-frame `CharacterController:197` nil error (DESIGN.md P2) in the same file area.
- Round 2 (Sol, 2026-10-05: still wrong, plus the character's facing jumps while aiming). Logged in Studio: while charging, the rendered model's facing alternated every frame between the aim and a drift toward +Z, and every throw reached the server at ~180°. Cause: the rendered model is unanchored with Humanoid AutoRotate on, so its physics (animation constraints) turned it while `CharacterController` re-pivoted it each frame; the throw read that rotation.
- Fix 2: the rendered model's HumanoidRootPart is anchored and its AutoRotate is off (ragdoll still unanchors it); throws use `CharacterController.LastCFrame` (exactly what the aim arrow shows) unless a touch direction is given. Removed the now-unused requires in WeaponController.
- Not lint-checked.

---

## Backlog

## Done

### T-070 · Lobby jumping is buggy under Server authority
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server, Client, Shared
- **Epic:** Finalize Conversion to Server Authority
- **Files:** `Shared/Library/LobbyLibrary.luau`, `Client/Core/LobbyController.luau`, `Server/Core/CharacterService/init.luau`
- **Approved early** by Sol (2026-10-03). DESIGN.md "Known problems: P3".

**Problem / goal**
In Server mode, jumping in the lobby is buggy. Cause (Sol's guess, confirmed in code): jumping was only enabled on the client. `CharacterService.onCharacterLoaded` disables it on the server (`JumpHeight = 0`, Jumping state off) and only `LobbyController` re-enabled it, locally. In Server mode the server simulates the character, so the client predicted a jump the server refused, and the server corrected it.

**Done when**
- [x] In Server mode, jumping in the lobby is smooth (no snapping back or stutter), with the normal lobby jump height.
- [x] Jumping is still disabled in the arena (Space still dashes there).
- [x] Automatic mode still works.

**Test in Studio**
- Server mode: jump around the lobby, including while walking; walk out of the lobby into a round and back, and jump right after coming back.
- Mobile emulator: the jump/dash button in the lobby.

**Notes**
- Branch `agent/T-070-sa-lobby-jump`, lane `Github/Boomerang-lanes/docs-server-authority`.
- New `LobbyLibrary.applyJumpState(humanoid, isInLobby)`, used by both sides. The client still applies it every frame for its own character; the server now applies it to every living character 10 times a second (`CharacterService`, in the existing `PostSimulation` handler; one small box query per player per check).
- The helper now also re-enables the Jumping state when it doesn't match, not only when `JumpHeight` changes.
- **Check:** right at the lobby edge the server may switch up to 0.1 s after the client; a jump at that exact moment could still snap once.
- **Check (mobile):** in the lobby, the jump/dash button sets `humanoid.Jump = true` on the client (`AbilityController.useMovementInput`). Space also goes through Roblox's default controls, which send input to the server in Server mode, but a client-only `Jump = true` may not reach the server. If the mobile button still stutters, that's the next fix.
- Compiled with `luau-compile`; not play-tested (Studio runs the home repo's code).
- Passed Sol's Studio test (2026-10-03).

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
- [x] Walking and running play at a natural speed in Server mode, for your own and other players' models.
- [x] Idle, jump and fall are unchanged.

**Test in Studio**
- Server mode, 2 players: walk and run (including any sprint or speed boosts) and watch both models' feet against the ground.

**Notes**
- Branch `agent/T-069-sa-walk-anim-speed`, lane `Github/Boomerang-lanes/docs-server-authority`.
- `syncPoseAnimations` now divides the horizontal speed by `R15_WALK_SPEED_SCALE` (16) before the blend, matching the Animate's `onRunning`.
- Not play-tested in motion: the agent's `Humanoid:Move` didn't move the character (the game's own movement controller likely overrides it), so the fix comes from the formula. Compiled with `luau-compile`.
- Passed Sol's Studio test (2026-10-03).

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
