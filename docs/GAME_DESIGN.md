# Boomerang!: Game Design (MVP spec)

Transcribed from the client's **"Boomerang! Technical Document"** (PDF, kept outside the repo in Sol's `Game Assets/Boomerang/Game Direction/` folder). The PDF is the source of truth: if it changes, update this file. Hand-drawn diagrams from the PDF are described in words.

The client's UI scope of work (`Game Assets/Boomerang/Gui/Boomerang! UI.pdf`) currently has only a cover page, so there's no written UI spec yet.

**Scope:** this spec covers the **MVP** only (round flow, controls, the Classic gamemode, parry/clash, camera). Everything else in the game (the other gamemodes, pickups, environment objects, shop, daily rewards, monetisation) has **no written design**. For those, the existing code and Sol are the reference. Never invent design that isn't here: ask Sol.

> **How authoritative this is:** the client wrote it before the ideas were fully thought out. It's the origin the game orbits around, not always the final word (see CLAUDE.md). **Ignore the sketch descriptions below** (recall diagrams, mobile layout); sketches in other docs (e.g. GUI docs) are fine.
>
> **Agents:** don't edit this file unless asked. Where the code differs from this spec, see "Differences between the spec and the code" at the bottom. Don't "fix" the code to match without asking: some differences are deliberate.

---

## 1. Core round flow

1. Players spawn in the lobby.
2. A match can begin once there are **at least 2 players**.
3. After a **10-second intermission**, players are placed at random spawn points in the arena. The spawn points are **predefined per map** to keep the spacing between players consistent across maps. Players are assigned to random predefined spawn points.
4. Players fight according to the current gamemode's rules (the Classic gamemode in the MVP) until the win condition is met.

## 2. Controls

| Action | PC | Mobile |
|---|---|---|
| Dash | Spacebar | Mobile jump button |
| Throw boomerang | Right mouse button (hold to aim, release to throw) | Throw button (hold to aim, release to throw) |
| Manual recall | Hold E | Hold the recall button |
| Stab | Left mouse button | Stab button |

**Mobile layout** (from the sketch): the movement joystick is bottom-left. Bottom-right is a large **Dash** button, with **Stab** to its left, **Throw** above Dash, and **Recall** above Stab (to the left of Throw).

### a. Dash
Players dash in the direction they're facing. Availability may depend on the gamemode (e.g. dash may be disabled in Hot Potato).

### b. Throw boomerang
- While aiming, the player **can't move** (WASD / joystick disabled) and becomes stationary.
- The movement input is repurposed to **rotate the player's facing direction** (WASD on PC, the joystick on mobile).
- The game uses a shared global camera, so aiming is **not** camera-, cursor- or screen-position-based. It's purely direction-based, via the player's rotation.
- A **floating arrow** shows the aim direction, and it's **visible to all players**.
- While aiming, the camera, aim arrow and held boomerang have a **slight vibration** effect.
- The boomerang is launched in the **exact direction the player is facing at the moment of release**.

**Energy (revised 2026-10-16; the original spec counted bounces):**
- A thrown boomerang starts with **50 energy** (a tap) up to **100 energy** (aim held for a full `ChargeTime`), scaling with the charge.
- It loses energy as it flies: **1 per stud flown**, **30** when it bounces off a wall, **10** when it strikes a player, **40** when it clashes with another boomerang mid-air.
- At **0 energy or below** while flying out, what happens depends on what is beneath it:
  - **Over open air** (no ground to land on) it can't die: it **returns to the player automatically, whether or not it has line of sight**.
  - **Over ground** it asks one question. If there is a **clear line of sight** to its player, it **returns automatically**. If not, it **dies** (the dead state) and must be recalled manually or picked up.
- Either way, a boomerang that starts returning because it ran out is **refilled to the recall energy** (30, `BoomerangRecallEnergy`, tune `RecallEnergy`). The way back costs **no distance energy**, so an unobstructed return always makes it home; only bounces (30), player hits (10) and clashes (40) cost energy. At **0 again while returning it dies** (no second line-of-sight check; over open air it keeps heading for the player and dies once it is over ground). With 30 reserve, any wall hit on the way back kills it.
- **Line of sight** is a flat block cast (same shape and height the boomerang bounces with) from the boomerang to the player's `Hitbox` part, at the boomerang's own height, so only walls at least that tall block it. The height is one value, `GlobalConfig.BoomerangRaycastHeight` (default 1 stud), shared by the bounce cast and the LOS cast; tune it live with `setboomerangcastheight`. `togglelosvisualizer true` draws each LOS cast (green = clear, red = blocked).
- Running out of energy over ground (out of line of sight on the way out, or the recall energy spent on the way back) is the **only** way a boomerang dies. There is no distance limit and no turnaround distance, and a clash never kills it by itself.
- Every number is a `GlobalConfig` value and a Cmdr `tuneboomerang` setting (MinEnergy, MaxEnergy, EnergyPerStud, BounceEnergyCost, PlayerHitEnergyCost, ClashEnergyCost).

### b2. Returning boomerangs (revised 2026-10-16)
- A boomerang on its way back to the player behaves like an outgoing one with a different heading: it **bounces off obstructions**, **strikes players**, **loses energy** (flight, bounces, hits, clashes) and **dies at 0 energy** over ground (see the recall energy above). A manual recall in flight keeps whatever energy it had left and follows the same rules.
- A bounce **overrides** the steering toward the player: the bounce momentum takes over, then fades back into heading for the player over `BoomerangRecallBounceRecoverySeconds` (0.35 s; `tune RecallBounceRecovery`). If the bounce sends it toward the player it just builds speed; if it sends it away, it slows and curves around. This works for any combination of directions, including a moving player.
- This applies to a thrown boomerang recalled in flight or auto-returning. The held manual recall of a dead boomerang (below) keeps its own slide-along-surfaces behavior and has no energy.

### c. Manual recall
- Holding the recall input brings the boomerang back to the player's hand.
- Releasing it midway stops the recall; the boomerang rests at the last point it reached.
- During manual recall the boomerang **doesn't pass through walls or obstacles**. It collides with map geometry and takes the **fastest valid route** back.
- Diagrams: after a double ricochet the boomerang rests where it stopped and the recall path is a straight line to the player. If an object is in the way, the boomerang **gets stuck** against it. If the surface's shape allows it, the boomerang **slides along the surface** and continues to the player ("alternative route"). (An older note, crossed out in the sketch, said the player would have to reposition themselves.)
- Reference video: [Boomerang Manual Recall Reference Video](https://drive.google.com/file/d/1x444S0b2uhENR59ImZN7QktJrjleZNua/view?usp=sharing)

### d. Stab
Players can eliminate other players with a melee stab using the boomerang.

## 3. Classic gamemode

A free-for-all mode focused on fast-paced, constant combat.

- Each round lasts about **5 minutes**.
- Every player can attack every other player.
- Eliminated players **respawn immediately** at one of the set spawn points, with a temporary **forcefield for about 5 seconds** that makes them immune.
- Players who join after the round has started can **join mid-match** (like Roblox *Arsenal*).
- When the timer ends, the **top 3 players by kills** are the winners. Winners may be shown on a **podium**, possibly with victory animations.
- **Win condition:** the round ends when the timer expires; players are ranked by kills.

## 4. Match systems

### a. Parry (melee)
- Happens when **two players stab at the same time**.
- Neither player takes damage: both attacks are negated and both players enter a brief **stagger / recoil** state.
- A **"PARRIED"** indicator shows on both players' screens. Optional: screen shake and/or a sound effect.

### b. Clash (projectiles)
- Happens when **two boomerangs collide mid-air**.
- Both are deflected: they bounce off at new angles and each loses **40 energy** (`BoomerangClashEnergyCost`). A clash doesn't kill a boomerang by itself; it dies only if the clash leaves it at 0 energy with no line of sight to its player. A returning boomerang is knocked off course the same way.

### c. Camera *(marked done in the spec)*
For all gamemodes:
- Follows the **centroid** (average position) of all active players and pans smoothly to keep most players in view.
- **Adaptive zoom:** zooms out when players spread apart, in when they cluster, so all relevant gameplay stays on screen.
- **Shared globally:** every player sees the same camera view.

## 5. Boomerang physics notes
- Angle of incidence equals angle of reflection.
- Hitting map objects reduces the boomerang's energy (30), as does striking a player (10), a clash (40) and distance flown (1 per stud).
- Players are not bounced off: the boomerang passes through them (at the energy cost above).
- A dying boomerang (sliding to a stop after dying) keeps checking for its player: with line of sight and within 50 studs it resumes its recall, even at 0 energy.

---

## Differences between the spec and the code

Found while writing this file (2026-10-01). Each is either deliberate or still to do; Sol decides (see TASKS.md T-014).

| Spec | Code |
|---|---|
| A match needs at least 2 players | `GlobalConfig.PlayersRequiredToStart = 1` (see T-008) |
| Respawn forcefield lasts about 5 seconds | `GlobalConfig.SpawnShieldDuration = 2` |
| Classic: top 3 players by kills win, podium | `GamemodeLogics/Classic` picks a single highest-kill winner (none on a tie) |
| Auto-recall after one ricochet; 2+ surface hits → stops, manual recall | Replaced on 2026-10-16 by the energy system above (the old `Bounces` and `ThrowDistance` tool values are gone). |
