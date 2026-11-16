# 05 · Working on Boomerang with AI agents

The project was built almost entirely by a human (the previous developer) directing AI coding agents (Claude Code / Cowork), with the human making design decisions, play-testing and signing off. Everything an agent needs to know is meant to be written down in the repo, in three files:

| File | Role |
|---|---|
| [`CLAUDE.md`](../CLAUDE.md) | Instructions every agent session loads automatically (Claude Code reads it at the start; other tools can be pointed at it). Conventions, architecture, rules. |
| [`TASKS.md`](../TASKS.md) | The task board. Each task has Priority, Owner, Files, Problem/goal, Open questions, "Done when", "Test in Studio" and Notes. |
| `docs/*.md` | Specs an agent must read before touching an area (see `CLAUDE.md`, "Start here"). |

This workflow suited the project well, and you can keep it. But `CLAUDE.md` and `docs/GIT_WORKFLOW.md` are written around the previous developer's own PC, name and habits. **Before giving an agent its first task, adapt them** as below, or the agent will try to ask "Sol", work in folders that don't exist, and refuse to do ordinary git operations.

## 1. Keep: these are project rules

These sections of `CLAUDE.md` describe the codebase and the client's requirements. Keep them as they are:

- **Toolchain, Rojo tree, Leftover and reference modules, The Studio place has more than the repo, Boot / module loading, Where things go, Networking, Game structure, Data, Developer commands (Cmdr), Code conventions.** They're accurate, except for the out-of-date points in section 3 below.
- **"Missing game items and values"**: when a value or ID doesn't exist yet, the agent adds a placeholder in the registry where it belongs, marked `-- TODO:RELEASE placeholder`, and never invents missing *design*.
- **"How authoritative the docs are"**: the design doc isn't the final word; ask instead of "fixing" code or doc.
- **Player-facing wording**: "eliminations"/"defeats", never "kill". **One currency.** **Crates, never eggs.** **Permanent IDs** (anything saved or sent over the network) never change.
- **Roblox Studio MCP rules**: the repo is the source of truth for code; never edit synced scripts in Studio; never touch the maps package; never publish; no agent play-testing; add Cmdr commands for hard-to-reach states.
- **Ask instead of guessing** on gameplay intent, and one clear question before code rather than a guess that has to be undone.
- **Keep credit usage low**: grep before reading, no throwaway test harnesses, one syntax check per batch, leave play-testing to the human.
- **GUI art approval**: every image upload (including re-uploads of a fix) waits for an explicit yes on the final file.
- **Commit message style**: short, past tense, describing the change in the game ("Added environment portals", "Fixed issue with claims menu not being able to close"), with no task IDs or `fix:`-style prefixes. It keeps the history readable for the client. Keep it if you like it.
- **⛔ Never delete large things without explicit confirmation.** Worth keeping in any repo where agents run shell commands. The limits are "about a third of the repo" (1 MB, or 155+ files in one delete); re-measure if the repo grows.

## 2. Change or drop: the previous developer's personal setup

Edit these in `CLAUDE.md` (and `docs/GIT_WORKFLOW.md`, `TASKS.md`) to match how *you* work:

| Where | What it says now | What to do |
|---|---|---|
| Everywhere | "Sol" as the person to ask, who play-tests and signs off, and whose decisions are quoted | Replace "ask Sol" with your name or "the developer". Leave the historical "(Sol, <date>)" citations in task Notes and code comments alone: they record decisions. |
| Intro bullets | "This is client work: Sol develops it for the client and reports finished changes daily" | Rewrite for your arrangement. |
| "Workflow for agents" → Git | **Lanes**: one clone per agent chat in `C:\MY FILES\Github\Boomerang-lanes\<lane>`, a "home repo" that stays on `main`, `git push home agent/<lane>`, "ship lane" as the only permission to merge, "cull branches", Cowork delete permissions for lock files | Simplify. If you run one agent at a time, a normal workflow is enough: a branch per task (`agent/T-###-short-name`), you review the diff and merge. If you want parallel agents, git worktrees (or Claude Code's built-in worktree sessions) do the same job as lanes with less ceremony. Keep "agents never push to GitHub" and "never force-push / rebase / reset `main`" if you like those safeguards. |
| Git identity | `git -c user.name="SoulsplosionSide" -c user.email="116596822+LaurKnill@users.noreply.github.com" commit …` | **Remove.** That's the previous developer's identity; commits must be yours. `docs/GIT_WORKFLOW.md` also forbids `Co-Authored-By` trailers so only the previous developer appeared as author; decide your own policy. |
| `Commits.txt`, `AgentLog.md` | Git-ignored logs in the home repo: a daily client-facing change log, and an undo log of agent merges | Drop them, or keep the idea of a client-facing change log if your client wants daily reports. |
| "Changing this CLAUDE.md" | Asks whether to record changes in `C:\MY FILES\SharedDocs\CLAUDE_MD_CHANGES.md` | Remove (and you can delete `docs/CLAUDE_MD_CATCHUP.md`). |
| "The `Github` folder is read-only…" | About the previous developer's folder of several projects | Remove. |
| "When Sol says they're logging off" | Session summary habit | Keep or drop, as you prefer. |
| "GUI art" | Points to `C:\MY FILES\Projects\Boomerang\Assets\ArtPipeline\…` and Blender 5.3's Python on that PC | Point it at wherever you keep the art pipeline (see [06_ART_PIPELINE.md](06_ART_PIPELINE.md)), or remove it. |
| "Roblox Studio MCP" | Place name, placeId 74945725552268, "confirm the right place with Sol" | Keep the rules; replace "Sol" with you. |
| `TASKS.md` "How to use this board" | Owner values `Agent` / `Sol` / `Sol → Agent`; IDs reserved by a "Setup workspace" commit on `main` in the home repo | Rename the owners (`Agent` / `<you>` / `<you> → Agent`). If only one agent works at a time, just bump `Next free ID` in the same commit as the task. |
| `.vscode/settings.json` | `editor.formatOnSave: true` with StyLua | Turn off (see [01_SETUP.md](01_SETUP.md)). |

A quick way to do all of this: open a Claude Code session in the repo and ask it to "adapt CLAUDE.md, docs/GIT_WORKFLOW.md and the TASKS.md rules for a new single developer named X, following HAND_OFF/05_AGENT_WORKFLOW.md section 2", then review the diff.

## 3. Out of date in `CLAUDE.md` (fix while you're there)

- The **"Aim arrows"** paragraph (under Data → Currency and items) names `AimArrowService`, `AimArrowController`, `AimArrowLibrary`, `Shared/Referential/AimArrows.luau`, profile fields `OwnedAimArrows` / `EquippedAimArrow`, and the Cmdr command `grantaimarrow`. These were renamed to **charge up effects**: `ChargeUpEffectService`, `ChargeUpEffectController`, `ChargeUpEffectLibrary`, `Shared/Referential/ChargeUpEffects.luau`, `OwnedChargeUpEffects` / `EquippedChargeUpEffect`, and `grantchargeupeffect`. The visuals live in `Shared/Logics/ChargeUpEffects/`.
- It doesn't yet describe several newer systems (emotes, Strike effects, taunts, crates, quests, rewards, leaderboards, lifetime stats, pedestals, settings, bots, lag compensation). [03_SYSTEMS.md](03_SYSTEMS.md) covers them. You could add one line per system to `CLAUDE.md` "Game structure" so agents find them.
- "Weapons" lists `ClassicBoomerang, ClassicShuriken, ClassicFan, plus Placeholder... copies`. Fan skins (BambooBreeze, Moonsong, SakuraDrift, SunfirePhoenix, SunsetPop, TidalSurge) were added since.

- "Weapons": each tool's `Category` no longer picks a Weapons Shop tab. The Weapons Shop has no tabs now; it sells one crate per category (`Tools.CrateWeight`).
- "Where things go":
  - It says each GUI is `init.luau` + its `.rbxmx`. Most GUIs are now built in code.
  - `Shared/Assets` no longer has GUI assets (`Shared/Assets/Gui` is gone).
  - `Client/UI/ClientArt`, `Client/UI/ShopCommon`, `GuiMirror`, `ItemViewport` and `UIUtil` aren't listed.
- "Currency and items": `Referential/Items.luau` is empty and `ShopItems.luau` holds only the listing type. The shop contents come from `Client/UI/ShopCommon/Tabs/`.
- The Referential list names `LootBoxRates` (an empty stub) but not `Crates`, `Quests`, `Skins`, `ChargeUpEffects`, `Emotes`, `ElimEffects` or `Taunts`.

Spot-check anything else before relying on it: these docs, like `CLAUDE.md`, describe the code on 2026-11-16.

## 4. The task loop that worked

1. **Write the task first** in `TASKS.md`, with the template: goal, open questions, "Done when" checkboxes, "Test in Studio" steps. Tasks with open questions stay in `Backlog` until they're answered.
2. **Agent picks up a `Ready` task**, moves it to `In Progress`, asks its open questions *before* writing code, then implements on its own branch.
3. **Agent finishes**: fills the task's Notes (what changed, every `TODO:RELEASE placeholder` it added, exactly what to check in Studio, which Cmdr command reaches the feature), moves it to `Done`, commits.
4. **You test in Studio** (agents can't run Studio play sessions), then merge.
5. Follow-up feedback becomes a new task or a note on the same one.

What made agents effective here:
- **Module headers.** Most modules start with a `Description:` block saying what the module owns and where its data lives. Keep writing them. Agents rely on them to find code.
- **The dashed section headers** in every module (`CONSTANTS` / `TYPES` / `PRIVATE VARIABLES` / `PUBLIC VARIABLES` / `PRIVATE FUNCTIONS` / `PUBLIC FUNCTIONS` / `CORE FUNCTIONS`), from the snippets in `.vscode/snippets.code-snippets`.
- **Cmdr commands for every hard-to-reach state** (`setnextgamemode`, `getpickup`, `resetdaily`, `simulategroupmember`, `setstationstate`...), so testing a feature takes seconds.
- **A placeholder over a blocked task.** Missing price or ID? Add it in the right registry with `-- TODO:RELEASE placeholder` and keep going.
- **`.rbxmx` changes are XML** and hard to review as text. Always open them in Studio.

## 5. Verifying changes without Studio

Agents can't run the game. The checks they can run:
- `selene src` (lint), if Selene is installed.
- `rojo sourcemap default.project.json --output sourcemap.json`, then the Luau language server's diagnostics, or `luau-lsp analyze` with the sourcemap, for type errors.
- Reading the Studio output log through the Studio MCP, if it's set up, after you press Play.

Everything else is play-testing, which is yours.
