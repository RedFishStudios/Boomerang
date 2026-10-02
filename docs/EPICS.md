# Epics

An **Epic** is a large feature (e.g. the lobby or a quest system) that needs a lot of back-and-forth with Sol before and during implementation. Each Epic gets a folder with its design doc and its own task list. Everything smaller goes in the general task board, [TASKS.md](../TASKS.md).

Task format, IDs and board rules: the "How to use this board" section of [TASKS.md](../TASKS.md). IDs are global: Epic tasks take their IDs from the same `Next free ID` line.

---

## Active

| Epic | Priority | Status | Folder |
|---|---|---|---|
| Lobby | P1 | In Progress | [epics/lobby/](epics/lobby/) |

## Proposed

Not started yet. Each one begins with **Discovery** when Sol picks it up. Format:

```markdown
### <Epic name>
- **Priority:** P0 / P1 / P2
- **Pitch:** one or two sentences: what it is and why.
- **Discovery should cover:** the questions to work through first.
```

### Weapons & Skins
- **Priority:** P2
- **Pitch:** Settle what separates an **alternate weapon** (e.g. Shuriken, Fan) from a **cosmetic skin** that keeps the same stats, then build how players equip them. Today `GlobalConfig.ForceEquippedTool` forces `ClassicBoomerang` for everyone. Replaces task T-036. Blocks the weapon crate station (T-044, Lobby).
- **Discovery should cover:** the final rule for "alternate weapon" vs "skin" (do alternates change stats/behaviour, or are all of them skins?); whether skins can apply to any weapon or only one; how equipping works (loadout screen, per-round choice, one weapon + one skin?) and whether gamemodes can override it; how it's saved in the profile (`Inventory` + an equipped field); how it fits `Items.luau`, `Tools.luau` and `ToolService`; where it's sold or won (shop, crates, wheel) and the GUI it needs.

### Quests
- **Priority:** P2
- **Pitch:** Daily/weekly objectives that give players a reason to come back and play more rounds, with rewards. Replaces task T-038.
- **Discovery should cover:** daily vs. weekly vs. one-off quests; objective types (eliminations, round wins, pickups used, gamemodes played; these can reuse the T-048 stats); rewards and how they fit the Currency economy; save data and reset timing; the GUI and where it opens from (HUD button, lobby station?).

### Achievements
- **Priority:** P2
- **Pitch:** Long-term milestones (e.g. lifetime eliminations, wins, gamemodes mastered) with rewards. Replaces task T-039.
- **Discovery should cover:** the achievement list; rewards; whether they map to Roblox badges; save data (most can read the T-048 lifetime stats); the GUI; overlap with Quests (one shared system or two?).

## Shipped

One line per shipped Epic. Its folder was deleted when it shipped; the commit below still has it (`git show <commit>~1:docs/epics/<epic>/DESIGN.md`).

| Epic | Shipped | Folder removed in | Lasting docs |
|---|---|---|---|
| *(none yet)* | | | |

---

## When something is an Epic

Decided during Discovery. The first question of every Discovery is **"Does this need a full Epic, or can it go in general tasks?"** Rough guide: if it fits in about 1–3 tasks and needs little design discussion, it's general tasks.

## Lifecycle

| Status | What happens | Who moves it on |
|---|---|---|
| **Proposed** | A pitch in the list above. Nothing else exists yet. | Sol picks it up. |
| **Discovery** | Create `docs/epics/<epic>/` from [epics/_TEMPLATE/](epics/_TEMPLATE/). Sol and the agent discuss and fill in `DESIGN.md`. **No tasks yet.** | Sol approves the design. |
| **Approved** | The agent writes the tasks into the Epic's `TASKS.md`, ordered by priority. | Work starts. |
| **In Progress** | Tasks move through the board as usual. | All tasks done. |
| **Playtest** | Sol tests the whole Epic in Studio (and the client reviews it). | Sol. |
| **Shipped** | Run the ship steps below. | |

**Agents never write an Epic's tasks before Sol approves its DESIGN.md**, and never mark an Epic Shipped. For the Lobby Epic, every feature also needs Sol's individual approval before it moves onto the board.

## Epic priority

- `P0`: urgent; blocks the game or the next update.
- `P1`: part of the next update for the client.
- `P2`: later.

Keep only 1–2 Epics **In Progress** at a time.

## Shipping an Epic

Done in one docs change, after Sol confirms it shipped:
1. Fold what stays true into a lasting doc under `docs/` (e.g. `docs/systems/<SYSTEM>.md`; create it if needed): how it works, files, data, decisions that still apply. Link it from CLAUDE.md's "Start here" table if agents need it.
2. Move the Epic's Done tasks to the `Done` section of [TASKS.md](../TASKS.md). Move any unfinished tasks to the general board (or drop them, with Sol's OK).
3. Delete the Epic folder.
4. Move its row to **Shipped** above, with the date and the commit hash of the commit that deletes the folder (filled in after Sol commits).

## Epic folder

```
docs/epics/<epic>/
  DESIGN.md   What the Epic is and the decisions made (template sections)
  TASKS.md    The Epic's task list (same rules as TASKS.md)
```

Use a short lowercase folder name (e.g. `quests`, `lobby`). Other files (drafts, configs, research) may live in the folder while the Epic is active.
