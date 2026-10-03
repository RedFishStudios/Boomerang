# Lobby: Tasks

Epic task list. Format and rules: "How to use this board" in [TASKS.md](../../../TASKS.md). Design: [DESIGN.md](DESIGN.md).
Take new IDs from the `Next free ID` line in [TASKS.md](../../../TASKS.md). Every task here has `Epic: Lobby`.

---

## Ready

## In Progress

## Review

## Backlog

### T-024 · Shop pedestals in the lobby
- **Priority:** P2
- **Owner:** Sol → Agent
- **Epic:** Lobby
- **Area:** Server / Client
- **Files:** New: lobby pedestal logic (e.g. an Environment logic or a `LobbyShopService`); `Shared/Referential/ShopItems.luau` (`CurrentDeal`)

**Problem / goal**
Lobby pedestals show a floating, slowly spinning model of the current sale item. Walking up to one shows a prompt to buy it.
- **Sol:** build the pedestal model(s) in the lobby (Studio) and tag/name them.
- **Agent:** spawn and spin the current deal's model over each pedestal (client-side is fine), add a ProximityPrompt, and buy through the existing purchase flow.
- **Sol: focus on Robux** (`MarketplaceLibrary.promptDeveloperProduct` with the item's `ProductId`), **but keep it scalable** so a Currency purchase option can be added later (e.g. a per-pedestal/per-item payment method, not Robux hard-coded into the prompt logic).

**Decisions (Sol, 2026-10-02)**
- `ShopItems.CurrentDeal` will be removed. There can be several pedestals, **each with its own item**, rotated **manually**.
- Pedestals are lobby stations (T-047, `docs/LOBBY_STATIONS.md`).
- 🗣️ Before starting: discuss how to make live-updatable config values (so pedestal items can change without a new place version). This may become a separate "flag handler" task that comes first.

**Open questions (ask Sol first)**
- Is `ShopItems.CurrentDeal` the item to show, and does it rotate (daily/weekly)?
- How should pedestals be marked in the place (tag name / folder)?

**Notes**

---

### T-042 · Prize wheel
- **Priority:** P2
- **Owner:** Sol → Agent
- **Epic:** Lobby
- **Area:** Server / Client / Build
- **Files:** New: wheel station (uses T-047); `MarketplaceLibrary`, `PolicyLibrary`

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. A freestanding prize wheel on a pedestal with segmented rewards and a spin animation, used through a station prompt.

**Open questions (ask Sol first)**
- Rewards and their weights; is it cosmetic-only or can it affect gameplay?
- How spins are earned/bought: free per day, Currency, Robux (Robux-first like T-024?), codes (T-049), playtime?
- Spin animation length; is an "instant spin" Robux option wanted?

**Notes**
- 🗣️ **Talk with Sol before starting.**
- A paid random reward: must respect `PolicyLibrary.arePaidRandomItemsRestricted` and Roblox's rules on disclosing odds.

---

### T-043 · Explosion crates (normal + premium) with odds panel
- **Priority:** P2
- **Owner:** Sol → Agent
- **Epic:** Lobby
- **Area:** Server / Client / Build
- **Files:** `Server/Core/LootBoxService.luau` and `Shared/Referential/LootBoxRates.luau` (currently empty stubs); crate stations (T-047)

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. Two crate stations side by side (a normal and a more elaborate premium crate), each with a world-space name and, when approached, a panel showing rarity odds (e.g. Rare / Legendary / a very rare tier). Build the crate logic generically in `LootBoxService` so T-044 reuses it.

**Open questions (ask Sol first)**
- Crate names, prices and currency (Robux-first like T-024? Currency?), reward tables and odds.
- What do "explosion" crates contain in Boomerang (elimination effects?)
- Do crates open in the lobby (animation) or just act as purchase points with the reward shown in the ItemAcquired popup?

**Notes**
- 🗣️ **Talk with Sol before starting.**
- Paid random items: `PolicyLibrary.arePaidRandomItemsRestricted` + odds disclosure required.

---

### T-044 · Sword (boomerang) crate station
- **Priority:** P2
- **Owner:** Sol → Agent
- **Epic:** Lobby
- **Area:** Server / Client / Build
- **Files:** Crate station (T-047), `LootBoxService` (T-043)

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. A separate crate station for weapon cosmetics, visually distinct from the explosion crates. In Boomerang this is presumably a **boomerang skin** crate.

**Open questions (ask Sol first)**
- Is this a loot box, a fixed-item shop, or something else? Cost and contents.
- Depends on how weapons/skins are equipped (Weapons & Skins Epic, was T-036).

**Notes**
- 🗣️ **Talk with Sol before starting.** Reuses T-043's crate logic.

---

### T-046 · Server Selection portal
- **Priority:** P2 *(later: needs destinations first)*
- **Owner:** Sol
- **Epic:** Lobby
- **Area:** Design / Build
- **Files:** -

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. A large portal arch on a glowing ring with a sign, leading to other servers/modes/worlds.

**Open questions (ask Sol first)**
- What does it lead to in Boomerang? (Today there's a single server type; this needs other places or modes first, e.g. duels/ranked from `docs/research/BLADE_BALL_LOBBY.md`.)
- Physical selection (several portals) or a follow-up UI?

**Notes**
- 🗣️ **Talk with Sol before starting.** Probably later; nothing to build until destinations exist.

---

## Done

### T-045 · Group Rewards chest
- **Priority:** P2
- **Owner:** Sol → Agent
- **Epic:** Lobby
- **Area:** Server / Client / Build
- **Files:** New: group rewards station (T-047); profile field for claimed state

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. A large chest on a glowing pad with a "GROUP REWARDS" title. Players in the client's Roblox group can claim a reward; the chest shows locked/unlocked/claimed states.

**Decisions (Sol, 2026-10-02)**
- Group ID **293180599**, stored in `GlobalConfig` (e.g. `GlobalConfig.GroupId`) so it's easy to find and change.
- Membership is required. A non-member who triggers the chest is prompted to join the group in-game.
- Claimable **once per day**.
- Reward: a placeholder for now. "Once per day" = 24 h since the last claim, exactly like Daily Rewards.

**Research: detecting a join during the session (2026-10-02)**
- `GroupService:PromptJoinAsync(groupId)` is client-only and shows Roblox's native join prompt. It returns an `Enum.GroupMembershipStatus`: `Joined`, `AlreadyMember`, `JoinRequestPending` (manual-approval groups) or `None` (cancelled/ineligible). Wrap it in `pcall`.
- `Player:IsInGroup` is cached (about 60 s). The prompt clears the *client's* cache only, so the server can still see the old answer right after a join.
- Plan: chest handler on the server checks membership; if not a member, tells the client to call `PromptJoinAsync`. On `Joined`, the client asks the server to retry, and the server verifies with the uncached `GroupService:GetGroupsAsync(userId)` before granting (never trust the client's result alone).

**Open questions (ask Sol first)**
- The group ID, and is membership required?
- What's the reward, and is it one-time or on a cooldown?

**Notes**
- 🗣️ **Talk with Sol before starting.**
- Done (2026-10-02). `GlobalConfig.GroupId = 293180599` and `GlobalConfig.GroupRewardCurrency = 100` (**`TODO:RELEASE placeholder`** reward, Currency). New profile field `GroupRewardLastClaim` (0 = never; filled in by Reconcile).
- New `Server/Core/GroupRewardService` (station `StationId = "GroupRewards"`): members claim once per rolling 24 h; non-members get the join prompt; after `Joined`/`AlreadyMember` the client fires `GroupRewardJoined` and the server re-checks with uncached `GetGroupsAsync` (3 s cooldown) before granting. Per-player station state: `Active` ("Claim"), `Locked` ("Join group"), `Claimed` (prompt hidden, unlocks itself when the 24 h are up). New `Client/Core/GroupRewardController`: join prompt + "Group reward claimed! +100 Currency" popup (ItemAcquired).
- Cmdr: `resetgroupreward <players>` makes the chest claimable again.
- **Studio setup (Sol):** tag the chest model `LobbyStation` with `StationId = "GroupRewards"`, `Title = "GROUP REWARDS"`, and a glowing child part named `Pad`.
- **Test in Studio:** as a group member: claim (popup, +100 Currency, prompt disappears, pad dims), rejoin (still claimed), `resetgroupreward me` (claimable again). Join flow: needs an account **not** in the group, ideally in a live/team-test server. `PromptJoinAsync` has had reported Studio issues; if it errors in Studio, the warning "join prompt failed" shows and nothing breaks.
- Review follow-up (Sol, 2026-10-02): membership moved out of the chest into its own `Server/Core/GroupMembershipService` + `Client/Core/GroupMembershipController` (`isMember`, `refreshMembership`, `promptJoin`, `MembershipChangedTasks`, per-server group id override, per-player simulation). `GroupRewardService` only uses that API; `GroupRewardController` now only shows the claim popup. Remotes renamed: `GroupMembershipPromptJoin`, `GroupMembershipJoinReport`.
- New Cmdr: `simulategroupmember <players> member|nonmember|real`, `setgroupid [groupId]` (this server only, not saved).
- **Testing the join flow as a member:** `simulategroupmember me nonmember` → chest shows "Join group" (dimmed) → trigger it: the join prompt opens (Roblox will say you're already a member; the simulation keeps you a non-member) → `simulategroupmember me real` → the pending claim goes through. Or `setgroupid <a group you're not in>` to test the real prompt and join.
- Passed Sol's Studio test (2026-10-03).

---

### T-047 · Lobby station framework (labels, glowing pads, proximity prompts)
- **Priority:** P1
- **Owner:** Agent
- **Epic:** Lobby
- **Area:** Client / Server / Shared
- **Files:** New: e.g. `Shared/Library/LobbyStationLibrary.luau` (+ client/server parts); used by T-024, T-042–T-045

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. Every lobby station (pedestals, wheel, crates, group chest, portal) shares the same conventions: a world-space title above it, a glowing activation pad, a proximity prompt or info panel when approached, and locked/unlocked or active visual states. Build this once as a reusable, tag-driven framework (e.g. CollectionService tag `LobbyStation` plus attributes such as `StationId`, `Title`, `ActionText`) so each station only registers its callback. Sol provides the models and art; this task is the behaviour.

**Done when**
- [ ] A tagged part/model in the lobby gets a title label, prompt and pad highlight automatically.
- [ ] Stations register server-side handlers by `StationId`; prompts fire them; per-player visual state (e.g. claimed/locked) can be set from the server.
- [ ] Works with T-024 pedestals; no station-specific code in the framework.

**Notes**
- Ask Sol for the tag/attribute names if a convention already exists in the place.
- Tag convention (no existing one in the place could be checked, Studio had another place open): CollectionService tag `LobbyStation` + attributes `StationId` (required), `Title`, `ActionText`, `HoldDuration`, `MaxDistance`, `PromptPart`, `PadPart` (default a descendant named `Pad`), `TitleHeight`. Documented at the top of `LobbyStationLibrary`.
- New: `Shared/Library/LobbyStationLibrary` (conventions, `StationState` type), `Server/Core/LobbyStationService` (creates prompts, `registerHandler(stationId, fn)`, `setPlayerState(player, stationId, state)`; triggers only count in the lobby, 0.5 s cooldown), `Client/Core/LobbyStationController` (title BillboardGui, pulsing PointLight on the pad that brightens while the prompt is shown and dims when `State` isn't `"Active"`, per-player prompt text/visibility; `ApproachedTasks` / `LeftTasks` / `StateChangedTasks` for station code such as the crate odds panel). Handles StreamingEnabled.
- Cmdr: `setstationstate <players> <stationId> <state> [promptEnabled]` (`clear` resets).
- **Test in Studio:** tag a lobby part/model `LobbyStation` with `StationId = "Test"`, `Title = "TEST"`, and a child part named `Pad`. Check the label, the pad glow (brighter near it), and the prompt (triggering warns "no handler registered" in Studio, that's expected). Then `setstationstate me Test Locked false`: prompt hides, glow dims; `setstationstate me Test clear` restores. Station visuals (font, label size, glow strength) are constants at the top of the controller, easy to tune.
- Passed Sol's Studio test (2026-10-02). Guide: `docs/LOBBY_STATIONS.md`.

---

### T-032 · Lobby leaderboards (Eliminations + Wins, Monthly / All-Time)
- **Priority:** P2
- **Owner:** Agent
- **Epic:** Lobby
- **Area:** Server / Client
- **Files:** `Server/Core/LeaderboardService.luau`, `Client/Core/LeaderboardController.luau`, `Shared/Constants/LeaderboardConstants.luau`, `Shared/Data/ProfileTemplate.luau`, `Server/Core/LifetimeStatsService.luau`, `Server/Cmdr/Commands/RefreshLeaderboards*.luau`

**First lobby feature (Sol, 2026-10-01).** Depends on T-048 (stats tracking).

**Problem / goal (Sol's spec)**
- Two physical boards: `workspace.Lobby.Leaderboards.Elims` ("Eliminations", never "Kills") and `.Wins`. GUI on the large side facing the lobby floor.
- Each board has two CanvasGroups, **Monthly** and **All-Time**, cross-fading every 10 s.
- Top 30 per board; data refreshed every 10 minutes.
- **No podium for now** (ask Sol later).

**Done when**
- [ ] Both boards show Monthly / All-Time, alternating every 10 s, top 30 with rank, headshot, display name and value.
- [ ] Scores are saved and the boards reload every 10 minutes; monthly boards start fresh each UTC month.

**Test in Studio**
- Needs Studio API access for DataStores (Game Settings > Security). Get some eliminations/wins, then `refreshleaderboards` (Cmdr) instead of waiting 10 min. Check both boards, both periods, the fade, and the side they're drawn on.
- Multi-player check: Team Test or a live test server.

**Notes**
- Stores: `OrderedDataStore`s named `{Dev|Live}_{Elims|Wins}_{AllTime|YYYY-MM}`, so Studio data never mixes with live (same idea as PlayerDataService's `Dev` key). Studio uses `Dev`.
- Server cost: one background loop every 10 min (writes only changed scores > 0, then 4 `GetSortedAsync` + 1 batched display-name request). Scores are also written when a player leaves. Nothing per frame, no instances replicated: clients build the SurfaceGuis themselves (in PlayerGui, adorned to the board parts) and do the fading locally. `MaxDistance` 200 hides them far away; hidden CanvasGroups are set invisible.
- Monthly scores: new profile field `MonthlyStats` (`MonthKey`, `Elims`, `Wins`), updated by `LifetimeStatsService` next to the all-time values. Only Elims/Wins earned from this change on count.
- Faces (from Studio raycasts toward the lobby floor): Elims = `Right`, Wins = `Left`. Set in `LeaderboardConstants.Boards` if a board is moved.
- Visuals are code-built and styled after the game's GUIs (FredokaOne with dark outlines, orange-yellow title gradient, mint values, teal banner and panel, wooden frame, purple highlight for your own row). Colours are constants at the top of `LeaderboardController`; swap for a template later if wanted.
- **Check in Studio:** both board parts are **unanchored with no joints**, so they'll fall when the game runs. Anchor them (place-only change; I didn't touch the place).
- New Cmdr: `refreshleaderboards` (alias `refreshlb`).
- Passed Sol's Studio test (2026-10-02).

---

### T-053 · Leaderboards fade between periods
- **Priority:** P2
- **Owner:** Agent
- **Epic:** Lobby
- **Area:** Client
- **Files:** `Client/Core/LeaderboardController.luau`, `Shared/Constants/LeaderboardConstants.luau`

**Problem / goal**
The leaderboards switch abruptly between Monthly and All-Time. They should fade gradually, using a CanvasGroup for the fade. The controller already has a cross-fade (`fade()` tweens each period's CanvasGroup `GroupTransparency` over `FadeDuration` = 0.6 s), so find out why it doesn't show in game (e.g. CanvasGroups inside a SurfaceGui, `Visible` toggled too early, or the changes in commit `5158746` "Updated leaderboard visuals") and fix it.

**Done when**
- [ ] Each board fades smoothly from one period to the other, with no pop.

**Test in Studio**
- Stand by the boards and run `triggerleaderboardchange` (or wait 10 s): both boards fade to the other period.

**Notes**
- Likely cause: 4 full-board CanvasGroups (2 per board, at 100 pixels per stud) exceeded Roblox's CanvasGroup texture memory, so they were drawn as plain frames and `GroupTransparency` was ignored. Only the instant `Visible` toggle remained. (Not confirmed in Studio: the place wasn't open.)
- Fix: each board now has a static background (frame, banner, panel) and **one** CanvasGroup (`Fader`) holding only each period's title and entries. A swap fades the Fader out, switches period and fades it back in. `FadeDuration` is now 1 s for the whole swap (0.5 s out, 0.5 s in).
- If it still pops: check the Studio output for a CanvasGroup memory warning; lowering `PIXELS_PER_STUD` in the controller would shrink the CanvasGroup further.
- **Actual cause (found after Sol confirmed it still popped):** the SurfaceGuis are made with `Instance.new`, which defaults `ZIndexBehavior` to `Global` (Studio's Insert menu sets `Sibling`, scripts don't). CanvasGroups only apply `GroupTransparency` under `Sibling`. Now set to `Sibling` in `createBoardGui`. The single-Fader restructure stays (less CanvasGroup memory).
- Cmdr `triggerleaderboardchange` (alias `swaplb`) swaps every player's boards now; the 10 s timer restarts after any swap.
- Uncommitted. Files: `Client/Core/LeaderboardController.luau`, `Shared/Constants/LeaderboardConstants.luau`, `Server/Core/LeaderboardService.luau`, `Server/Cmdr/Commands/TriggerLeaderboardChange*.luau`.
- Passed Sol's Studio test (2026-10-02).

---

### T-040 · Research Blade Ball's lobby
- **Priority:** P1
- **Owner:** Agent
- **Epic:** Lobby
- **Area:** Design (research)
- **Files:** `docs/research/BLADE_BALL_LOBBY.md` (new)

**Problem / goal**
The client said: "anything they have in their lobby, we want in our lobby". Research the current Blade Ball lobby (Roblox) and write a list of every lobby feature, with a short description, screenshots/links where possible, and how it might map to Boomerang (existing system, new system, or asset-only).

**Done when**
- [x] `docs/research/BLADE_BALL_LOBBY.md` lists every lobby feature found (shops, pedestals, leaderboards, spin wheels, rewards, quests, social features, etc.), with sources.
- [x] Each feature is tagged: already in Boomerang / planned task (ID) / new.
- [x] No new tasks are created from it without Sol's approval; propose them in the doc instead.

**Notes**
- Written: `docs/research/BLADE_BALL_LOBBY.md`. It covers 11 physical lobby features and 11 lobby UI/meta systems, each tagged existing / planned / new / needs a client decision, plus a suggested order and sources.
- The Blade Ball fan wiki couldn't be read automatically; the doc lists its relevant pages to confirm in a browser. Lobby content changes with seasons, so a walkthrough of the live game is recommended before scoping.
- No tasks were created from it (as the task requires); Sol decides.
- Accepted by Sol (2026-10-02).

---

### T-041 · Lobby hub layout blockout
- **Priority:** P1
- **Owner:** Sol
- **Epic:** Lobby
- **Area:** Build (Studio)
- **Files:** Studio: `workspace.Lobby`

**Problem / goal**
Spec: `docs/LOBBY_SPEC.md`. Block out a spacious central hub with walking lanes and zones: rewards (wheel, visible from spawn), crates (explosion + sword), social (group rewards), navigation (server portal with open space), competition (leaderboards + podium). Functional parity with the reference, not a copy of its art.

**Open questions (ask Sol first)**
- Functional parity (same kinds of stations) or close visual parity with the reference?
- Art direction, floating vs. grounded lobby, which stations must be visible from spawn?

**Notes**
- **Not needed (Sol, 2026-10-01):** the hub is already built in Studio (`workspace.Lobby.Model`). What remains is per-station decor (signs, ads, prompts), covered by each station's task.

---
