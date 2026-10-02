# Blade Ball lobby: feature research (T-040)

The client asked: *"anything they have in their lobby, we want in our lobby."* This lists what Blade Ball's lobby (and the systems you reach from it) offers, and how each maps to Boomerang.

Researched 2026-10-01 from public guides (sources at the bottom). **Limits:** the Blade Ball fan wiki (bladeball.fandom.com) blocks automated reading, and Blade Ball changes its lobby with every season/event. Treat this as a checklist to confirm by visiting the live game (ideally Sol or the client walks through it and screenshots each area) before committing to scope.

**Tags:** ✅ exists in Boomerang · 📋 planned (task ID) · 🆕 new, no task yet · ⚠️ needs a client decision (large or monetisation-sensitive)

---

## 1. Physical lobby areas (things you walk up to)

| Feature | In Blade Ball | Boomerang | Notes |
|---|---|---|---|
| **Spin wheel** (centre of the lobby) | A prize wheel. Spins come from codes, playtime rewards, coins (reported: up to 3/day for 3,000 coins) or Robux. "Instant Spin" (Robux) skips the animation. Prizes: coins, coin multipliers, cosmetics, abilities. | 🆕 | Paid random rewards must respect regional rules: `PolicyLibrary.arePaidRandomItemsRestricted` already exists. Fits the Robux-first, currency-later approach chosen for T-024. |
| **Crates** (next to the wheel) | Stands for sword-skin and explosion-effect crates. Walk up, press E (or "Purchase"). Free "Case Keys" from playtime rewards open one. | 🆕 (stub) | `LootBoxService` and `LootBoxRates` exist but are empty stubs. Same paid-random-item policy as the wheel. |
| **Shop / featured item displays** | Items bought with coins (abilities) or Robux (skins, bundles). | 📋 T-022 (shop GUI), T-024 (lobby pedestals) | The shop GUI exists. T-024 adds walk-up pedestals for the sale item. |
| **Limited-time merchant** | Event NPC shop (e.g. "Haunted Merchant") selling exclusive sword/explosion/emote/crate for coins, next to an event countdown. | 🆕 | Could reuse the pedestal + prompt pattern from T-024. Needs event content. |
| **Event countdown board** | Timer for the next event/update in the hub. | 🆕 | Small. Needs a source of event dates (config or remote). |
| **Leaderboards** | Boards for **most wins** and **most kills**. | 📋 T-032 (top 30 by eliminations + top-3 podium) | Blade Ball also has a **wins** board; consider a second board once T-032 exists (`Profile.Wins` is already saved). |
| **Player count board** | Shows players in the server vs. players in the current match. | 🆕 | Small. `GameStateLibrary.LivingPlayersInArena` already has the in-match list. |
| **Server Selection ring** | A red ring on the side of the lobby: choose normal, duels, ranked, AFK, tournament servers. | 🆕 ⚠️ | Boomerang has one server type today. Only useful once there are other modes/places (duels, ranked, AFK). |
| **Duels platforms** | Platforms with 2 to 8 "portals" (1v1 to 4v4). Standing on all spots starts a 5 s countdown; first to 3 wins; rematch option; W/L shown over heads. | 🆕 ⚠️ | Large: a separate match flow alongside `RoundCyclingService`. |
| **AFK zone / AFK World** | Stand there to earn currency over time (reported: 2 coins / 15 s, plus battle-pass currency). | 🆕 | Simple version: a lobby zone that ticks `EconomyService.addCurrency`. Needs anti-abuse limits. |
| **Group rewards chest** | Claim a reward for joining the developer's Roblox group. | 🆕 | Small: `Player:IsInGroup` check, one-time claim saved in the profile. Needs the client's group ID. |

## 2. Lobby UI and meta systems

| Feature | In Blade Ball | Boomerang | Notes |
|---|---|---|---|
| **Daily login rewards** | Escalating daily panel (guides mention 5-day and up to 21-day tracks). | ✅ DailyClaims (7 days) · 📋 T-009 (in Review), T-021 (assets) | |
| **Playtime rewards** | Milestones for time played per day (coins, spin tickets, crate keys). | 🆕 | Pairs with the wheel and crates. |
| **Daily quests** | 3 quests a day, coin rewards, bonus for all 3. | 📋 T-038 | |
| **Codes** | Enter codes (from the menu) for coins, spins, skins. | 🆕 | Small. Codes list on the server; redeemed codes saved in the profile. (Cmdr is developer-only and doesn't cover this.) |
| **Battle pass** | Seasonal free + premium tracks (reported 480–639 Robux), weekly challenges. | 🆕 ⚠️ | Large; needs seasons of content. |
| **Ranked** | Separate servers, tiers (Rookie/Bronze → Champion), seasons. | 🆕 ⚠️ | Large; needs matchmaking/places. |
| **Clans** | Paid clans, clan missions, crowns, clan perks. | 🆕 ⚠️ | Large. |
| **Trading** | Booths and a trading-token currency. | 🆕 ⚠️ | Large and policy-sensitive; `PolicyLibrary.isPaidItemTradingAllowed` exists. |
| **Emotes** | Equippable emotes (from crates, rewards, battle pass). | 🆕 | Ties into T-036 (how cosmetics are equipped). |
| **Cosmetic loadout** | Sword skins, explosion effects. | 📋 T-036 | Boomerang equivalents: boomerang skins, elimination effects. |
| **Top-left buttons** | Invite friends, playtime rewards, news, codes, VIP sword colour. | 📋 T-037 (HUD buttons) | Add invite/news/codes to the T-037 button list if wanted. |

---

## Suggested order (for Sol / the client to decide)

1. **Already planned, finish first:** T-024 pedestals, T-032 leaderboard (+ a wins board), T-037 HUD, T-038 quests.
2. **Small, high-value lobby additions:** group rewards chest, codes, playtime rewards, player-count board, AFK zone.
3. **Monetisation core (needs client sign-off on Robux/currency and policy):** spin wheel, crates (fill in `LootBoxService`).
4. **Large systems (separate scoping each):** duels, server selection, ranked, battle pass, clans, trading, limited merchant/events.

Nothing here has been turned into tasks yet; Sol decides which to add.

## Sources

- [Blade Ball on Roblox: How to Play, Block, and Survive Your First Rounds (allthings.how)](https://allthings.how/roblox-blade-ball-how-to-play-full-guide/): lobby stations (crates, group rewards, server selection, AFK zone), leaderboards (most wins/kills), player count board, daily login.
- [Blade Ball (NamuWiki)](https://en.namu.wiki/w/Blade%20Ball): top-left buttons, daily/playtime rewards, quests, roulette costs, trading booths, ranked tiers, clans, AFK World rates.
- [Blade Ball Guides hub (dungeonpath.com)](https://dungeonpath.com/games/blade-ball/): battle pass pricing, ranked, modes.
- [Blade Ball: How to Open Crates (robloxden.com)](https://robloxden.com/game-codes/blade-ball/guides/blade-ball-how-to-open-crates): crates at the central wheel area, press E / Purchase.
- [How to get and use Case Keys in Roblox Blade Ball (Destructoid)](https://www.destructoid.com/how-to-get-and-use-case-keys-in-roblox-blade-ball/): crates area, free keys from playtime rewards.
- [Roblox Blade Ball: How To Do Duels (prodigygamers.com)](https://prodigygamers.com/2023/11/06/roblox-blade-ball-how-to-do-duels-1vs1-or-4v4/): server selection ring, duel platforms, W/L over heads.
- [Blade Ball Battle Royale update: Spooky Showdown, Haunted Merchant (Sportskeeda)](https://www.sportskeeda.com/roblox-news/blade-ball-battle-royale-update-spooky-showdown-haunted-merchant): limited merchant next to the event countdown in the hub.
- Search results also listed fan-wiki pages that couldn't be read automatically: [Lobby](https://bladeball.fandom.com/wiki/Lobby), [Wheel](https://bladeball.fandom.com/wiki/Wheel), [Crates](https://bladeball.fandom.com/wiki/Crates), [The Merchant](https://bladeball.fandom.com/wiki/The_Merchant), [Leaderboards](https://bladeball.fandom.com/wiki/Leaderboards), [Server Selection](https://bladeball.fandom.com/wiki/Server_Selection), [AFK World](https://bladeball.fandom.com/wiki/AFK_World), [Quests](https://bladeball.fandom.com/wiki/Quests). Worth opening in a browser to confirm details.
