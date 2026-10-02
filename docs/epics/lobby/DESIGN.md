# Lobby: Design

- **Status:** In Progress · **Priority:** P1 · **Update:** next client update
- **Stages:** single pass (each station is approved and built on its own)

This Epic was set up after the lobby work had already started, so it skipped the usual Discovery. The design source is **[docs/LOBBY_SPEC.md](../../LOBBY_SPEC.md)** (from the client's reference screenshots), with research in [docs/research/BLADE_BALL_LOBBY.md](../../research/BLADE_BALL_LOBBY.md). This file records decisions on top of that spec; it doesn't repeat it.

**Rule for this Epic:** every lobby feature must be individually approved by Sol before it moves onto the task list. Sol makes the GUI image assets and station models; agents build the behaviour.

`TODO (human review)` means not written yet; `OPEN:` means undecided. **Agents never fill these in or decide them.**

---

## 1. Player experience

See LOBBY_SPEC.md §1–3: a central hub with rewards (prize wheel), crates (explosion + sword), social (group rewards chest), navigation (server portal) and competition (leaderboards + podium) stations, all following the same interaction conventions.

## 2. Scope

- **What it affects:** `workspace.Lobby` in the Studio place, lobby stations, leaderboards, rewards and shop GUIs.
- **Integration points:** `LobbyService` / `LobbyLibrary`, `MarketplaceLibrary`, `PolicyLibrary`, `DailyRewardsService`, the stats added in T-048.
- **Assets needed:** station models and GUI art (Sol).
- **Size:** see [TASKS.md](TASKS.md).

## 3. Performance budget

`TODO (human review)`. Default: stations are event-driven (proximity prompts, tags); leaderboards refresh on a timer (every 10 minutes), not per frame.

## 4. Save data

Leaderboards use OrderedDataStores (T-032). Each station task notes its own saved fields; changes to saved shapes need Sol's approval.

## 5. Economy

`TODO (human review)`: wheel prizes, crate prices and odds, group reward amounts.

## 6. Revenue

- **Focus:** supporting.
- **Hooks:** paid wheel spins, premium crates (T-042, T-043).
- **Roblox policy check:** paid random items need visible odds and `PolicyService` checks (LOBBY_SPEC.md §3).

## 7. Implementation

Shared station framework first (T-047), then each station registers its own handler.

## 8. Order of work

1. T-047 station framework.
2. Stations as Sol approves them: T-024, T-042, T-043, T-044 (blocked by T-036), T-045, T-046 (needs destinations).

## 9. Testing

Sol tests each station in Studio. Add Cmdr commands for anything hard to reach by playing (e.g. reset a daily claim, refresh leaderboards now).

## 10. Out of scope

See LOBBY_SPEC.md §4.

## 11. Open questions

See LOBBY_SPEC.md §5, and the Open questions in each task.
