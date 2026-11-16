# 04 · Status, open work and release blockers (2026-11-16)

## Where the project is

A **playable prototype under client review**. The full loop works with 1+ players: lobby → vote → "New round in N" → round → results (and taunts) → lobby. All six gamemodes, the pickups below, the meta systems (currency, daily rewards, group chest, quests, crates, five cosmetic categories, Robux products) and saved data work. The last weeks went into restyling every GUI with the client's art; the client was sent a review video of all GUIs (T-173).

The `Done` section of [`TASKS.md`](../TASKS.md) has an entry for every finished feature (about 180 tasks), each with what was decided, what changed and how to test it. Search it by system name before changing a system; it often explains *why* something works the way it does.

### Feature inventory

| Area | State |
|---|---|
| Gamemodes | Classic, TeamClassic, Elimination, TeamElimination, HotPotato, Assassin (late join). `ThrowBoomerang` exists but is commented out of `Gamemodes.luau`. |
| Boomerang | Throw (charge for power), auto-return on running out of energy, manual recall (charged, "ground approach"), catch (normal + heavy), bounces, clashes, dying/dead boomerang that slides then can be picked up or recalled, curving throws toward targets (PC mouse aim; "stage 1", T-141), lag-compensated hits. |
| Abilities | Dash (client-predicted, avoids deadly landings), Stab/Slash (crescent sweep, knocks weapons away, pops decoys). |
| Pickups, working | Fire, Electric (chain eliminations), Explosive, Homing, Teleport, Telekinesis, Shield, Speedup, Disguise, Decoy. Explosive, Teleport and Decoy are used with on-screen buttons / number keys (UsePickupButtons). |
| Pickups, stubs | BattleRoyale, DashNoclip, ExtraBoomerang, IceBoomerang, MultiBoomerang (`Disabled = true`): need design first (T-010). |
| Storm | The closing storm (`StormCloseService`, for modes with `StormClose = true`) is **switched off for testing** and has an argument bug; see [02_ARCHITECTURE.md](02_ARCHITECTURE.md). |
| Environment | Moving platforms (physics-driven, server-authoritative, crush), spinners, portals (projectiles go through), water, deadly parts, permanent fire. |
| Weapons / skins | Boomerang, shuriken, fan categories; six fan skins with trails; placeholder second weapon per category. Every skin uses the Classic stats for now. |
| Meta | Single currency, 7-day daily rewards, Group Rewards chest (group members), 3 daily + 3 weekly + season quests with reroll (Robux product), weapon crates bought with currency and clicked open in the lobby, all-time + monthly leaderboards, lifetime stats, winner pedestals with emotes. |
| Cosmetics | Skins, charge-up (aim arrow) effects, emotes, Strike (elimination) effects (Stone, Ashes, Sakura, Shark Attack), taunts (Too Easy, Bonk!, Royal Treatment, Nap Time). |
| GUI | New client-art style everywhere except the leftovers listed in [03_SYSTEMS.md](03_SYSTEMS.md). |
| Input | PC (plus an experimental alternative scheme toggled with **P**, T-140) and touch (custom touch buttons, left-handed layout option). **Console isn't supported yet** (T-176). |
| Bots | Decoys only (`Server/Logics/BotBehaviors/Decoy.luau`). No AI opponents. |

## Release blockers (must be done before a public release)

1. **Close the developer console: T-052.** `GlobalConfig.CmdrOpenToEveryone = true` lets *every player in every live server* use F2 (end rounds, grant currency, give pickups). Set it to `false`, and fill in `ADMIN_USER_IDS` and `MIN_ADMIN_GROUP_RANK` in `src/Server/Core/CmdrService.luau` (both are placeholders).
2. **Review the testing values in `GlobalConfig`: T-008.** `PlayersRequiredToStart = 1` (the commented line suggests `if isStudio then 1 else 2`; the client's spec says 2), `SkipVoting`, `ForceEquippedTool`, `ForceOverwritePickup`, and the debug switches (`VisualizeElectricChainRadius` is `true`).
3. **Replace every `-- TODO:RELEASE placeholder`.** List them with:

   ```bash
   grep -rn "TODO:RELEASE" src --include=*.luau
   ```

   As of today: all prices (skins, Strike effects, taunts, charge-up effects, crates), crate weights and weapon rarities (`Tools.luau`), daily reward amounts, the Group Rewards amount, `CrateClicksToOpen`, the quest season end date (2027-01-01) and season goals, a missing sound id in `Sounds.luau`, missing charge-up effect icons, the generic crate model, a reused taunt icon, and every skin's `WeaponClass` (all Classic stats).
4. **Paid random items.** Crates (and a future prize wheel) must respect `PolicyLibrary.arePaidRandomItemsRestricted` and Roblox's rules on showing odds. Today crates are bought with in-game currency only; check again before any Robux crate.
5. **`BotService` `HIP_HEIGHT`** is marked `TODO:VITAL` (tune so decoys stand at floor height).
6. **Anticheat is off.** `AnticheatService`'s speed check returns early (`if 1==1 then return end`). Decide whether to turn it on.
7. **Leftover debug code:** `print`s in `WeaponService`, `Boomerang.throw` and `CombatService`, and a test animation bound to **F** in `AnimationController.init`.

## Open work (the board's Backlog, by priority)

| ID | Priority | What | Blocked on |
|---|---|---|---|
| T-059 | P1 | Review round start/end and arena enter/exit for race conditions (the task lists concrete starting points). Propose fixes before changing code. | Nothing. A good first task. |
| T-014 | P1 | Spec vs code differences (min players, respawn forcefield length, Classic's winner(s), bounces): decide which to change. Table at the bottom of `docs/GAME_DESIGN.md`. | Client decision |
| T-008, T-052 | P1/P2 | Release checks above | Admin list from the client |
| T-102, T-103 | P2 | Boomerang desync hardening: an id + sequence number on every sync message; a periodic authoritative state check that heals any client/server mismatch. | Nothing |
| T-129 | P2 | Use-pickup buttons must be blocked (and dimmed) while your own boomerang is dying or dead. | Nothing |
| T-105, T-106 | P2 | Telekinesis steering in the over-the-shoulder camera (PC) and on console | Design decision |
| T-176 | P2 | Console (gamepad) support | Scope and button layout |
| T-010 | P2 | Design and build the five stub pickups | Design |
| T-018 | P2 | Icons for every pickup effect (Explosive and Teleport are done; Fire, Electric, Homing, Telekinesis, Disguise still show the old art) | Art |
| T-011 | P2 | Stale "figure out how teams should work" TODOs in three file headers | Trivial |
| T-005 | P2 | Convert the 3-space-indented files to tabs (leading whitespace only, never StyLua) | Nothing (in `Ready`) |
| T-024, T-042, T-043, T-044, T-046 | P2 | Lobby stations from `docs/LOBBY_SPEC.md`: shop pedestals, prize wheel, explosion crates with odds panel, sword crate, server-select portal. `LootBoxService` / `LootBoxRates` are empty stubs waiting for T-043. | Design: rewards, prices, odds |
| T-049 | P2 | Redeem codes | Design |
| T-061 | P2 | Replace the placeholder Group Rewards chest model | Model |
| T-078 | P2 | Smoke particle for the decoy poof | Asset |
| T-132 | P3 | Being crushed while immune becomes a "fake" death (respawn, no defeat) | Nothing |
| T-145 | P3 | Quest extras (reroll limits, Robux skip, event pools, notification badge) | Design |

The **Next free ID** line near the top of `TASKS.md` is **T-188**.

## Decisions in force (don't undo these by accident)

These were decided with the client. Code comments and task Notes cite them as "(Sol, <date>)".

- **One currency only**: `Profile.Currency`. No gems, cash or second currency.
- **"Eliminations" and "defeats"**, never "kill"/"death", in anything a player sees.
- **Crates, never eggs.**
- **Rounds are 5 minutes** for every gamemode (`Gamemodes.luau`, `ROUND_LENGTH = 300`). **Voting lasts 30 s** and **never ends early**, even if everyone has voted. Then **5 s** of "New round in N" (`LOBBY_ENDED_DURATION`), then the round. After the round, **10 s** of results in the arena (`RoundEnded`).
- **AFK players** (the lobby AFK toggle, `OptedOut` attribute) don't count toward `PlayersRequiredToStart`, can't vote and don't get the vote window.
- **A lone survivor doesn't automatically win** (T-177 was cancelled and undone).
- **Manual recall uses the "ground approach"** (`ManualRecallGroundApproach = true`); the old behaviour is still in the code behind that flag.
- **Only the server decides catches and hits.** The client predicts throws, dashes and catches; the server's result wins.
- **The client's scripter package is ported onto our systems**: none of its own data code, DataStore, Gems, remotes or quests were used.
- **The developer console is open to everyone** until release (on purpose, for client review).
- **The design doc isn't the final authority.** `docs/GAME_DESIGN.md` was written before the ideas were settled. Where the code differs, the difference is usually deliberate (see its bottom table). Ignore the sketches in the client's original PDF; the GUI documentation's sketches are fine to follow.

## Known rough edges

- **Race conditions** around round start/end and entering/leaving the arena have been seen occasionally (T-059 has the analysis starting points). "Who is in the round" lives in three places: `GameStateLibrary.LivingPlayersInArena`, `SpawnService`'s participants, and teams.
- **Boomerang desync** between client and server has been patched case by case (snapshots re-create missing boomerangs, T-101); the general fixes are T-102 / T-103.
- **Mixed indentation**: many files still use 3 spaces (T-005).
- **Old-style GUIs** remain (see [03_SYSTEMS.md](03_SYSTEMS.md)).
- **`Losses`** in the profile is never tracked. It's kept because the field has shipped; don't reuse it.
- **The chat command system** (`Server/Core/CommandService.luau`) is obsolete and disabled; it's kept only as a reference. Use Cmdr.
- `src/Server/Cmdr/Commands/` holds many tuning commands (`tuneboomerang`, `topdowncam`, `setlagcompensation`...). They change live values for testing only; the real defaults are in `GlobalConfig`.
