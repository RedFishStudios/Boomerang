# Moving platforms: carrying the players who stand on them

Goal: a player standing on a moving platform moves with it, and can walk around on it while it carries them.

Constraints:
- `Workspace.AuthorityMode = Server`. Each character is simulated on the server and predicted by its own client, and any
  movement change has to happen inside `RunService:BindToSimulation` so rollback and replay stay deterministic.
- The platform's path is a pure function of `time()`, run on the server and on every client
  (`Shared/Logics/Environment/MovingPlatform.luau`).
- Characters are R6 Humanoids (HipHeight 0, root 3 studs above the feet), with no ControllerManager.
- Test map: `MovingPlatformTest` (`setnextmap MovingPlatformTest`). You spawn on a still platform, and a moving platform
  shuttles 35 studs across a gap beside it at 10 studs/s.

Switches at the top of `MovingPlatform.luau`: `PHYSICS_DRIVEN`, `CARRY_ENABLED`, `RIDE_MODE`, `PUSH_ENABLED`.

## Attempts

Newest last. Each entry: what was tried, the commit, what happened.

- [x] **Anchored platform, velocity carry** (2026-10-27, "Fixed an issue with players clipping through moving platforms by
  updating to better standards for server authority"). The platform is anchored and its CFrame is set every simulation step.
  `AssemblyLinearVelocity` is written so the Humanoid follows its floor (the CARRY section).
  Riding wasn't the problem at the time; characters walking into the platform were popped through it.
- [x] **Scripted push** (2026-10-28, "Attempted fix of desynced interactions with moving platforms"). PUSH section: characters
  caught by the leading face are moved clear of it inside the simulation step. Riders are skipped.
- [x] **Physics drive** (2026-10-28, "Changed to body movers", `PHYSICS_DRIVEN = true`). The platform is unanchored,
  maximum density, and held to its path by a rigid AlignPosition and AlignOrientation. The goal was for physics to do the
  pushing and carrying.
  Result: pushing worked. **Riding didn't.** On 2026-11-09 the server read the moving platform's `AssemblyLinearVelocity` as
  0.0 the whole time it moved: the rigid constraint repositions it with no velocity of its own. The Humanoid saw a still
  floor, so the platform slid out from under a rider. Confirmed by Sol walking onto it.
- [x] **Back to anchored + velocity carry** (2026-11-09 experiment, `PHYSICS_DRIVEN = false`, `RIDE_MODE = "Velocity"`).
  Result: riding works on the server and as seen by the client (no corrections). The rider's velocity matched the platform's
  (10 studs/s), but they slipped back about 2 studs over the 35-stud trip and the slip wasn't recovered when the platform
  stopped.
- [ ] **Anchored + exact carry** (2026-11-09, `PHYSICS_DRIVEN = false`, `RIDE_MODE = "Delta"`). Every simulation step, each
  character whose feet are on the platform's top (within `RIDE_HEIGHT_TOLERANCE`) and whose root is over it (within
  `RIDE_FOOTPRINT_MARGIN`) is moved by the platform's own move and turn that step. The platform's velocity stays at zero so
  the Humanoid doesn't carry them twice. Their own walking is untouched.
  Result (my test, a character placed on the platform; I can't send walking input): it rides. Over three round trips
  the rider stayed within 0.3 studs of where they started on the platform, on the server and as seen by their own client,
  with zero client corrections (no frame-to-frame jumps over 0.3 studs). One earlier run, right as a Hot Potato round began,
  showed the rider swinging up to 6 studs on the client (163 jumpy frames). It didn't happen again; cause unknown, so watch
  for it.
  PartsTest crusher with this mode: a player standing in its path was pushed ahead of the face across the map and crushed at
  the end wall (scripted PUSH), never passed through.
  Still for Sol: walking around on top while it moves, walking/jumping on and off, dashing on it, two players riding.

## Known gaps / ideas not tried yet

- A rider who jumps isn't carried while in the air (only feet on the top count), so they land behind where they took off
  (relative to the platform). Could carry anyone above the footprint within a few studs.
- Stepping off keeps no momentum from the platform (it never had a velocity in Delta mode).
- With `PHYSICS_DRIVEN = false`, pushing characters in the platform's way is back to the scripted PUSH section. The standing
  case works (above); walking / dashing into the oncoming platform was the case the physics drive was brought in to fix,
  so check that by hand.
