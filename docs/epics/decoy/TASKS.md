# Decoy / NPC-Bot system: Tasks

Epic task list. Format and rules: "How to use this board" in [TASKS.md](../../../TASKS.md). Design: [DESIGN.md](DESIGN.md).
Take new IDs from the `Next free ID` line in [TASKS.md](../../../TASKS.md), reserved on `main` first ([GIT_WORKFLOW.md](../../GIT_WORKFLOW.md#2-reserve-a-task-id-before-adding-any-new-task)). Every task here has `Epic: Decoy`.

Implementation tasks are written after Sol approves [DESIGN.md](DESIGN.md). Only the asset dependency below is parked now.

---

## Ready

## In Progress

## Review

## Backlog

### T-078 · Smoke particle for the decoy poof
- **Priority:** P2
- **Owner:** Sol
- **Epic:** Decoy
- **Area:** GUI / Assets
- **Files:** (particle asset) + wherever bot/decoy despawn VFX are registered

**Problem / goal**
When a decoy is hit/eliminated it poofs into a smoke particle. Sol provides the smoke particle asset; an agent wires it into the decoy's despawn VFX once the bot layer exists.

**Notes**
- Parked during Discovery (Sol, 2026-10-09). Blocked on the asset from Sol and on the bot layer existing.

## Done
