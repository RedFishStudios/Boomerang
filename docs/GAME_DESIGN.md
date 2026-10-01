# Boomerang!: Game Design (MVP spec)

Transcribed from the client's **"Boomerang! Technical Document"** (PDF, kept outside the repo in Sol's `Game Assets/Boomerang/Game Direction/` folder). The PDF is the source of truth: if it changes, update this file. Hand-drawn diagrams from the PDF are described in words.

The client's UI scope of work (`Game Assets/Boomerang/Gui/Boomerang! UI.pdf`) currently has only a cover page, so there's no written UI spec yet.

**Scope:** this spec covers the **MVP** only (round flow, controls, the Classic gamemode, parry/clash, camera). Everything else in the game (the other gamemodes, pickups, environment objects, shop, daily rewards, monetisation) has **no written design**. For those, the existing code and Sol are the reference. Never invent design that isn't here: ask Sol.

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

**Auto-recall:** the boomerang returns to the thrower automatically when:
- it slices through players, or
- it hits a surface and ricochets **once**. (Diagram: thrown at a surface → bounces off at the mirrored angle → flies back to the player.)

**Energy loss:**
- Every surface hit costs the boomerang energy.
- If it loses too much (e.g. after **2 or more surface hits**), it no longer auto-recalls. It stops where it ran out of energy, and the player must recall it manually.

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
- Both are deflected or cancelled: they bounce off at new angles and lose momentum / drop.

### c. Camera *(marked done in the spec)*
For all gamemodes:
- Follows the **centroid** (average position) of all active players and pans smoothly to keep most players in view.
- **Adaptive zoom:** zooms out when players spread apart, in when they cluster, so all relevant gameplay stays on screen.
- **Shared globally:** every player sees the same camera view.

## 5. Boomerang physics notes
- Angle of incidence equals angle of reflection.
- Hitting map objects reduces the boomerang's energy.
- Passing through players doesn't reduce energy.

---

## Differences between the spec and the code

Found while writing this file (2026-10-01). Each is either deliberate or still to do; Sol decides (see TASKS.md T-014).

| Spec | Code |
|---|---|
| A match needs at least 2 players | `GlobalConfig.PlayersRequiredToStart = 1` (see T-008) |
| Respawn forcefield lasts about 5 seconds | `GlobalConfig.SpawnShieldDuration = 2` |
| Classic: top 3 players by kills win, podium | `GamemodeLogics/Classic` picks a single highest-kill winner (none on a tie) |
| Auto-recall after one ricochet; 2+ surface hits → stops, manual recall | `Tools.ClassicBoomerang.Boomerang.Bounces = 2`. Not checked further. |
