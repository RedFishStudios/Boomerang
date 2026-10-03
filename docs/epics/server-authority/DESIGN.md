# Finalize Conversion to Server Authority: Design

- **Status:** Discovery · **Priority:** P1 · **Update:** TODO (human review)
- **Stages:** single pass *(default: tasks in priority order. Only split into "Stage 1 / Stage 2" if there's a real midway point Sol can playtest, e.g. prototype → full version.)*
- **Lane:** `Github/Boomerang-lanes/docs-server-authority` (branch `agent/docs-server-authority`, Discovery docs only).

How to use this file: Sol and the agent fill in each section during Discovery. `TODO (human review)` means not written yet; `OPEN:` means undecided. **Agents never fill these in or decide them.** When Sol approves the design, set Status to Approved and write the tasks into `TASKS.md`.

Pitch (from [EPICS.md](../../EPICS.md)): the game uses Roblox's Server Authority (`Workspace.AuthorityMode`), but how it's used has problems. Finish the transition to it.

---

## Known problems

Problems Sol has seen with `AuthorityMode = Server`, plus the agent's diagnosis. Diagnoses are from reading code; confirm in Studio before acting on them.

### P1. Player character animations break in Server mode (work in Automatic)

**How animation works today** (`Client/Core/CharacterRenderController.luau`, `createCharacterModel`): the visible client-rendered model plays no animations of its own; it mirrors the hidden authoritative character.
1. `extractAnimations` finds a `LocalScript` named `Animate` in the rendered model and loads its Animation objects onto the rendered model's Animator, keyed by the AnimationId of the matching Animation in the authoritative character.
2. `sync()`, on `RunService.Stepped` per player, reads `authorityHumanoid:GetPlayingAnimationTracks()` and plays / re-speeds / stops the matching rendered-model tracks.

**Likely causes in Server mode:**
1. **The Animate script isn't a `LocalScript` any more.** The Server-authority Animate is a ModuleScript run by `RunAnimate.Client` / `RunAnimate.Server` scripts (see the forks below). The `c:IsA("LocalScript")` check never matches, so no track map is built and the rendered model stays in its default pose. Expected output: `Failed to find Animate script for custom character…`, then repeated `No synced animation tracks for player…`. *(High confidence: read directly from code.)*
2. **The authoritative character's tracks aren't where `sync()` looks.** In Automatic the client owns its character and its tracks replicate to everyone. In Server mode the new Animate only steps while `RunService:GetPredictionStatus` says this client simulates the character (`isSimulated` early-out in `stepAnimate`), and keeps its state in HumanoidRootPart attributes (`pose`, `currentAnimId`, `queuedPose`, …) for rollback, not in replicated tracks. For other players' characters, `GetPlayingAnimationTracks()` is likely empty on each client. The custom `AnimateReplication` remote (commit f514008) looks like a workaround for this. *(Medium confidence: general Server-authority behaviour, consistent with the symptom.)*

**Related findings:**
- Three unsynced forks of the Server-authority Animate exist: `src/Animate/` (not in `default.project.json`), `src/Shared/Networking/Animate.luau` and `src/Server/Core/Animate.luau` (synced, but nothing `require`s them). The live Animate is in the place, not Rojo; agents can't see which one runs.
- `Humanoid:GetPlayingAnimationTracks()` is deprecated; `Animator:GetPlayingAnimationTracks()` is the replacement.

**Possible direction** (`OPEN:` Sol decides): drive the rendered model from the Animate's replicated HumanoidRootPart attributes (`pose` / `currentAnimId`) instead of mirroring tracks; then remove the `AnimateReplication` remote and the duplicate Animate forks.

**To confirm in Studio:** play in Server mode; check the output for the two warnings above, and the class of `Animate` under the character. Check both your own character and another player's (they may break differently).

### P2+. TODO (human review)

Sol to list the other problems seen.

---

## 0. Epic or General tasks?

TODO (human review). Does this need a full Epic, or can it be 1–3 General tasks? If General: add the tasks to [TASKS.md](../../../TASKS.md), delete this folder, and stop here.

## 1. Player experience

TODO (human review). What "finalized" means for players (e.g. responsiveness, fairness, no visible desync).

## 2. Scope

TODO (human review). Systems to cover (from the pitch): characters and movement; `CharacterRenderController`'s hidden authoritative character plus client-rendered model; abilities such as Dash; weapons and boomerang prediction; animation sync. Relation to the `chickynoid-migration` branch, if any.

## 3. Performance budget

TODO (human review). Note: `CharacterRenderController` currently runs a `Stepped` sync per player and a per-frame collision loop per rendered model.

## 4. Save data

TODO (human review). Probably none.

## 5. Economy

n/a (probably).

## 6. Revenue

n/a (probably).

## 7. Implementation

TODO (human review).

## 8. Order of work

TODO (human review).

## 9. Testing

TODO (human review).

## 10. Out of scope

TODO (human review).

## 11. Open questions

- `OPEN:` Full Epic or general tasks? (section 0)
- `OPEN:` What other Server-authority problems has Sol seen?
- `OPEN:` Which Animate is live in the place (built-in Server-authority Animate, or one of the repo forks pasted in)?
- `OPEN:` P1 direction: attribute-driven rendered-model animation, or keep mirroring tracks and fix it?
- `OPEN:` Does this relate to the `chickynoid-migration` branch?
