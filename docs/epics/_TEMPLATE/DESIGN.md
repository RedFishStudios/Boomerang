# <Epic name>: Design

- **Status:** Discovery · **Priority:** P1 · **Update:** <name>
- **Stages:** single pass *(default: tasks in priority order. Only split into "Stage 1 / Stage 2" if there's a real midway point Sol can playtest, e.g. prototype → full version.)*

How to use this file: Sol and the agent fill in each section during Discovery. `TODO (human review)` means not written yet; `OPEN:` means undecided. **Agents never fill these in or decide them.** When Sol approves the design, set Status to Approved and write the tasks into `TASKS.md`.

---

## 0. Epic or General tasks?

Does this need a full Epic, or can it be 1–3 General tasks? If General: add the tasks to [TASKS.md](../../../TASKS.md), delete this folder, and stop here.

## 1. Player experience

What the player sees and does. Who it's for (see [GAME_DESIGN.md](../../GAME_DESIGN.md)). How complex it should be compared with the rest of the game, and how easy to learn.

## 2. Scope

- **What it affects:** systems, GUIs, data.
- **Integration points:** every existing file this Epic changes. "If it isn't broken, don't fix it" applies here: keep these changes small.
- **Assets needed:** models, GUI art, sounds, animations (and who makes them).
- **Size:** rough number of tasks.

## 3. Performance budget

Cost on low-end and mobile devices and busy servers (Boomerang is PVP-heavy with lots of projectiles: server cost matters most). Event-driven, no new per-frame or per-player polling unless justified here.

## 4. Save data

New or changed saved fields, permanent IDs, migration of old data. Changes to saved shapes need Sol's approval.

## 5. Economy

Currency sources and sinks this adds or changes.

## 6. Revenue

- **Focus:** none / supporting / primary.
- **Hooks:** game passes, developer products (`MarketplaceItems`), skins.
- **Roblox policy check:** e.g. paid random items have extra rules; the audience is all ages.

## 7. Implementation

How it's built: modules, server/client split, remotes, config. Whether it can be switched off while in progress, and how.

## 8. Order of work

What must exist first. The path from first working version to final version. If there are Stages, list them here.

## 9. Testing

What Sol tests in Studio, Cmdr commands needed (add tasks for missing ones), and whether it needs public testing before a full release.

## 10. Out of scope

What this Epic deliberately doesn't do.

## 11. Open questions

- `OPEN:` …
