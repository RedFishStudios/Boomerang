# Boomerang!: Hand-off

**Start here.** This folder is for the developer taking over Boomerang!. You won't be able to contact anyone who worked on it before, so it tries to answer every question you'd otherwise have to ask. It was written on **2026-11-16** from the state of `main` on that day. If you've just inherited the repo, read the documents in this order:

| # | Document | What's in it |
|---|---|---|
| 1 | [01_SETUP.md](01_SETUP.md) | Accounts and access, tools, getting the game running in Studio, and **what lives outside this repo** |
| 2 | [02_ARCHITECTURE.md](02_ARCHITECTURE.md) | How the code is organised: boot, module loading, networking, the round loop, weapons, characters, camera |
| 3 | [03_SYSTEMS.md](03_SYSTEMS.md) | Every feature system: UI, cosmetics, crates, quests, rewards, shop and Robux, the lobby, saved data |
| 4 | [04_STATUS.md](04_STATUS.md) | What's finished, what's open, release blockers, placeholders, known issues, decisions in force |
| 5 | [05_AGENT_WORKFLOW.md](05_AGENT_WORKFLOW.md) | How to keep working with AI agents (Claude Code or similar), which of the repo's agent rules to keep, and what to change in `CLAUDE.md` |
| 6 | [06_ART_PIPELINE.md](06_ART_PIPELINE.md) | How the GUI art is made and uploaded, and where it lives |

You'll also want these existing docs (they're still correct, and these hand-off docs link to them instead of repeating them):

- [`CLAUDE.md`](../CLAUDE.md): the agent instruction file. It's the most detailed description of the codebase's conventions. It's written around the previous developer's personal setup, though; [05_AGENT_WORKFLOW.md](05_AGENT_WORKFLOW.md) lists what to keep and what to change.
- [`TASKS.md`](../TASKS.md): the task board. `Backlog` and `Ready` are the open work; `Done` (most of the file) is a detailed history of every feature, with the decisions made and what to test.
- [`docs/GAME_DESIGN.md`](../docs/GAME_DESIGN.md): the client's original MVP spec, plus a table of where the code deliberately differs.
- [`docs/LOBBY_SPEC.md`](../docs/LOBBY_SPEC.md) and [`docs/LOBBY_STATIONS.md`](../docs/LOBBY_STATIONS.md): the lobby spec and the "lobby station" framework.

---

## The project in one page

**Boomerang!** is a Roblox PVP game: short, round-based matches on small arena maps, where the main weapon is a boomerang you aim, throw, recall and catch. It's inspired by the indie game *Boomerang Fu*, with a Roblox-style presentation and lobby inspired by *Blade Ball*. It's client work: the game belongs to a client (the Roblox group **293180599**; GitHub organisation `RedFishStudios`), and the previous developer built it for them, reporting finished changes to the client daily.

- **Round loop:** players wait in a lobby, vote between two gamemodes, then play a round in an arena, see the results, and go back to the lobby. Gamemodes: Classic, Team Classic, Elimination, Team Elimination, Hot Potato, Assassin.
- **Combat:** throw (hold to aim, release), manual recall, catch, dash, slash ("Stab"), clashes between boomerangs. Pickups spawn in the arena and power up the boomerang (Fire, Electric, Explosive, Homing, Teleport, Telekinesis...) or the player (Shield, Speed, Disguise, Decoy).
- **Meta game:** one currency (`Currency`), daily rewards, a Group Rewards chest, daily/weekly/season quests, weapon crates, and cosmetics: boomerang skins, charge-up (aim arrow) effects, emotes on the winner pedestal, elimination ("Strike") effects and after-round taunts. Robux developer products go through one receipt handler.
- **Platforms:** PC and mobile (touch) are supported. Console isn't yet (task T-176).
- **State on 2026-11-16:** a playable prototype under client review. Every core system works. Prices, rewards, weights and some art are placeholders (marked `-- TODO:RELEASE placeholder`). The developer console is open to every player on purpose while the client reviews the game, which **must** be closed before public release (T-052). The last few weeks went into restyling every GUI with the client's art.

## Tech in one paragraph

Luau, synced from this repo into Roblox Studio with **Rojo 7.7** (`default.project.json`); packages via **Wally** (Cmdr for the dev console, ProfileStore for saved data; both are committed in `Packages/` and `ServerPackages/`). No frameworks: two boot scripts auto-load every module whose name contains `Service` / `Controller` / `Screen` / `Library` and call `init()` then `start()`. Client/server traffic goes through one small remotes wrapper (`SimpleRemotes`). Round state is replicated with reactive values (`GameStateLibrary`). The server is authoritative; the client predicts throws and dashes. Most new GUIs are built in code from a small kit (`Client/UI/ClientArt/Kit.luau`) rather than drawn in Studio.

## The first hour

1. Read [01_SETUP.md](01_SETUP.md) and get the place open in Studio with `rojo serve` running.
2. Press Play. You'll spawn in the lobby, a vote starts (one player is enough), then a round. Press **F2** for the developer console; `help` lists every command.
3. Skim [02_ARCHITECTURE.md](02_ARCHITECTURE.md), then open `src/Server.server.luau`, `src/Server/Core/RoundCyclingService.luau` and `src/Shared/Library/GameStateLibrary` to see the loop.
4. Read [04_STATUS.md](04_STATUS.md) to pick what to do next.
5. If you'll use an agent, do the `CLAUDE.md` changes in [05_AGENT_WORKFLOW.md](05_AGENT_WORKFLOW.md) first. Until you do, an agent will try to ask "Sol" questions and follow file paths on a PC you don't have.

## Words you'll see

| Word | Means |
|---|---|
| **Sol** | The previous developer. `CLAUDE.md`, `TASKS.md` and code comments cite "Sol, <date>" for decisions; treat those as decisions already made by the project. |
| **The client** | The game's owner, who wrote the original design doc and supplied art and a "scripter package". |
| **Elimination / defeat** | A kill / a death. Player-facing text never says "kill" (Roblox audience safety); keep it that way. |
| **Strike effect** | An elimination effect (a cosmetic played on the player you eliminate). Code: `ElimEffect*`. |
| **Charge up effect** | The aim arrow cosmetic shown while aiming. Older code and docs call it an **aim arrow** (`AimArrow*`); it was renamed. |
| **Crate** | A paid random item box. Never "egg": the client's package used egg wording from another game, and it must not appear. |
| **Pickup** | An in-round power-up (`Shared/Logics/PickupLogics`). |
| **Lobby station** | Anything players interact with in the lobby (`docs/LOBBY_STATIONS.md`). |
| **Lane** | The previous developer's name for one agent's private clone of the repo (see 05). |
| **Ship lane** | The previous developer's phrase for "merge this branch into `main`". |
| **`RoundEnded`** | The phase after a round where players are **still in the arena** for 10 s (results screen, taunts). Easy to miss. |
| **Cmdr** | The developer console (F2). |
