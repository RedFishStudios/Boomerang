# 03 · Feature systems: UI, meta game, lobby, data

All paths are relative to `src/`. Each system follows the same split: a `<Name>Service` (server, owns the data and the rules), a `<Name>Controller` (client), often a shared `<Name>Library`, and data tables in `Shared/Referential/`.

## 1. UI

### How GUIs are loaded and opened

- **`Client/UI/UIController.luau`** requires every child of `Client/UI/Gui` (a module, or a folder's `init.luau`) at `init()`, calls each one's `start()`, and picks up modules added later.
- **A Gui module** is a table with `Type`, `Open` (bool), optional `RequiresMouse`, and the functions `open()`, `close(instant?)`, plus optional `toggle()`, `supercede()`, `refresh()` and `start()`. Code-built GUIs create their ScreenGui in `start()` or at load. Older ones take `script:WaitForChild("<Name>")`, a ScreenGui saved next to the module as `.rbxmx`.
- **Menus:** the modules in `UIController.MENUS` (CosmeticsShop, WeaponsShop, DailyClaims, Inventory, Stats, Quests, Settings). Opening a menu calls `UIController.supercede(name, "GamemodeHud")` (hiding the HUD until no menu is open), then closes the other menus.
- **`RequiresMouse = true`** frees the mouse while the GUI is open (through `MouseUnlockController`). Use it on anything clickable, because the over-the-shoulder camera locks the mouse.
- **Phase-driven GUIs** (Voting, GameAboutToStart, PendingPlayers, PreIntermission, DeathScreen...) open and close themselves from the round phase. `GameplayPhases.RoundEnded` shows the results screen, still named `PreIntermission`.

### The client-art kit

`Client/UI/ClientArt/` (ported from the client's package, `reference/ScripterPackage/UI`):

- **`Kit.luau`:**
  - `create` (Instance.new, with Parent set last), `image` (art at native pixels), `label` / `setText` (cream outlined text, several stacked TextLabels)
  - `pressable` (hover and press animation), `setEnabled`, `pop`, `rect`, `overlayButton`, `formatDuration`
  - `window(parent, name, image, canvas)`: a ScreenGui fitted to the screen, laid out in the art's own pixel canvas.
- **`Theme.luau`:** colours (Text / Outline / Ink, Wood, Gold...), rarity colours, the FredokaOne font, and motion values.
- **`Assets.luau`:** image ids per screen.
- **`Client/UI/ShopCommon/ShopBuilder.luau`:** `ShopBuilder.create(config)` returns a whole shop Gui module. The shops (`Gui/CosmeticsShop.luau`, `Gui/WeaponsShop.luau`) are just configs. Tabs live in `ShopCommon/Tabs/`. Purchases go `ShopController` → `RequestPurchase` RemoteFunction → `ShopService`.
- **Others:**
  - `ItemViewport.luau` (a model in a ViewportFrame)
  - `GuiMirror.luau` (mirrors a GUI for the left-handed layout)
  - `UIUtil.luau`
  - `Client/Core/GuiInsetController` (the player's inset settings)

### Which GUIs are in which style

| Style | GUIs |
|---|---|
| **New style, built entirely in code** | DailyClaims, Quests, Settings, Stats, Voting, DeathScreen, GameAboutToStart, PendingPlayers, PreIntermission (results), MenuButtons (the left lobby menu), StatsPanel, GamemodeHud (`LegacyBannerHud.luau` + its `.rbxmx` are kept only as reference), CosmeticsShop, WeaponsShop |
| **Hybrid**: a saved `.rbxmx` ScreenGui with the new art applied in code | Inventory, ItemAcquired (`OldTemplate.rbxmx` is a reference only), ElimMessage (the elimination feed), CustomTouchscreen |
| **Old style** (`.rbxmx`, not restyled yet) | Effects (the status-effects bar), HudButtons, UsePickupButtons (only its Explosive and Teleport icons are new) |
| **Plain, built in code** | Topbar |
| **Depends on the Studio place** | `Client/UI/Screens/InputScreen.luau` reads `PlayerGui.InputUI`, which comes from the place's StarterGui, not the repo |

To restyle an old GUI, copy the pattern of a recent one: `PendingPlayers` or `GameAboutToStart` for floating text, `Stats` or `Settings` for a window.

## 2. Cosmetics (five categories, one pattern)

| Category | Server / client / shared | Data | Saved as | Cmdr |
|---|---|---|---|---|
| Boomerang skins | `SkinService` / `SkinController` / `SkinLibrary` | `Referential/Skins.luau` (each skin: `Model` in `Shared/Assets/Tools`, `WeaponClass` = stats id in `Constants/Tools.luau`) | `OwnedSkins`, `EquippedSkin` | `grantskin` |
| Charge up effects (aim arrow) | `ChargeUpEffectService` / `ChargeUpEffectController` / `ChargeUpEffectLibrary` | `Referential/ChargeUpEffects.luau`; visuals in `Shared/Logics/ChargeUpEffects/<Id>` | `OwnedChargeUpEffects`, `EquippedChargeUpEffect` | `grantchargeupeffect` |
| Emotes (winner pedestal) | `EmoteService` / `EmoteController` / `EmoteLibrary` + `WinningEmoteLibrary` | `Referential/Emotes.luau` | `OwnedEmotes`, `EquippedEmote` | `grantemote` |
| Strike effects (elimination effects) | `ElimEffectService` / `ElimEffectController` (+ `Effects/`) / `ElimEffectLibrary` | `Referential/ElimEffects.luau`, `Constants/ElimEffectAssets.luau` | `OwnedElimEffects`, `EquippedElimEffect` | `grantelimeffect` |
| Taunts (after a round, T key / touch button) | `TauntService` / `TauntController` (+ `Taunts/`) / `TauntLibrary` | `Referential/Taunts.luau` | `OwnedTaunts`, `EquippedTaunt` | `granttaunt`, `taunt` |

- **The pattern:** the Service grants, buys and equips, saves to the profile, and publishes the equipped id as a **Player attribute** through `CosmeticLibrary.setEquipped`. The attribute names are in `CosmeticLibrary.ATTRIBUTES`: `EquippedSkin`, `EquippedChargeUpEffect`, `EquippedWinningEmote`, `EquippedElimEffect`, `EquippedTaunt`. Every client reads any player's cosmetic from that attribute and validates it through the Library, falling back to the default. `PlayerCosmeticController` caches them on the client.
- **Grant commands also equip** what they grant.
- **Never read `GlobalConfig.ForceEquippedTool` as the tool id.** Use `SkinLibrary.getWeaponClass` / `getModelName`.
- **Strike effects** are marked on the lethal hit (`ElimEffectLibrary.markLethalHit`, from `CombatLibrary`). The server fires `PlayElimEffect`, and clients render it.
- **Taunts** are only allowed during `RoundEnded` (`TauntLibrary.canTauntNow`).
- **Fan trails:** `Shared/Utils/FanTrails/` (ribbon and decor styles from the client's package).

## 3. Economy, crates, shop, Robux

- **Currency:** a single number, `Profile.Currency`. Change it only through `EconomyService.addCurrency` / `spendCurrency`. The client side is `EconomyController`.
- **Items:** `ItemService` / `ItemController` own `Inventory` (item id → amount). **`Referential/Items.luau` is empty today**, so the Item paths (shop, daily rewards, rewards) are wired up but have no data. `Referential/ShopItems.luau` now holds only the `ShopListing` type and an unused `CurrentDeal = nil`.
- **Crates:**
  - `Referential/Crates.luau` has BoomerangCrate, ShurikenCrate and FanCrate. `CrateLibrary` does the weighted roll over that category's tools (`Tools.CrateWeight > 0`, with a skin).
  - The Weapons Shop sells them through `ShopService` → `CrateService`, which spends the Currency and places a crate model in `workspace.PlacedCrates` next to the player. The player clicks it `GlobalConfig.CrateClicksToOpen` times to open it and gets the skin (`CrateOpened`, `CrateOpeningController`).
  - An unopened crate is granted when the player leaves.
  - Duplicates currently give nothing (a TODO).
  - **`LootBoxService.luau` / `LootBoxRates.luau` are empty template stubs.** The lobby crate stations (T-043/T-044) were meant to fill them; you could build on `CrateService` instead.
- **Robux:**
  - Product and gamepass IDs are in `Referential/MarketplaceItems.luau`. Today the products are `QuestReroll` (live) and `Placeholder`; there are no gamepasses.
  - `Shared/Library/MarketplaceLibrary.luau` wraps MarketplaceService on both sides: info and ownership caches, prompts.
  - `Server/Core/ProductService` handles `ProcessReceipt` and calls `Server/Logics/ProductLogics/<Product>` (`ProductId`, `grant(player) -> boolean`; `NotActive = true` skips it). Receipts are de-duplicated with the profile's `ProcessedReceipts` (the last 50).
  - Copy `ProductLogics/Template.luau` for a new product.
- **`PolicyLibrary`:** regional rules, such as whether paid random items are allowed.

## 4. Progression and rewards

- **Rewards:** `RewardLibrary` defines a reward's shape: Currency, Skin, ChargeUpEffect, Emote or Item, with a `FallbackCurrency` when the cosmetic is already owned. `RewardService.grant` hands one out. Only quests use it so far; daily rewards grant directly.
- **Quests:**
  - `Referential/Quests.luau` has three pools: Daily (3 slots, reset at UTC midnight), Weekly (3 slots, reset Monday) and Season (3 slots, ends `SEASON_ENDS_AT`, a placeholder).
  - Objective types: Eliminations, Wins, RoundsPlayed, MinutesPlayed, Throws, AbilityUses, Pickups, PickupUses.
  - `QuestService` handles assignment, resets, progress (counted only while alive in the arena), claiming, and the paid reroll (the `QuestReroll` product).
  - `QuestLibrary` is shared; the client side is `QuestController`.
  - Cmdr: `questprogress`, `resetquests`.
- **Daily rewards:**
  - `DailyRewardsService` (template-era code) uses a rolling 24 h window with a 7-day streak. Data is in `Referential/DailyRewards.luau`.
  - Cmdr: `resetdaily`.
- **Group Rewards chest:**
  - `GroupRewardService` / `GroupRewardController`, a lobby station. Group members claim `GlobalConfig.GroupRewardCurrency` every 24 h; non-members get the join prompt.
  - Group membership checks go **only** through `GroupMembershipService` / `GroupMembershipController` (`isMember`, `promptJoin`, `MembershipChangedTasks`).
  - Cmdr: `resetgroupreward`, `simulategroupmember`, `setgroupid`.
- **Stats:**
  - `LifetimeStatsService` is the only writer of the saved lifetime stats (Elims, Defeats, Wins, RoundsPlayed, TimePlayed, Throws, AbilityUses, PickupsAcquired, MonthlyStats).
  - Per-round stats are in `PlayerStatService` / `PlayerStatsLibrary` (replicated; reset every `LobbyVoting`).
  - The in-game `StatsPanel` replaces Roblox's player list.
- **Leaderboards:**
  - `LeaderboardService` saves Elims and Wins (all-time and this month) to OrderedDataStores and reloads the top 30 every 10 minutes (`Constants/LeaderboardConstants.luau`).
  - `LeaderboardController` draws them on the boards in `workspace.Lobby.Leaderboards`.
  - Cmdr: `refreshleaderboards`, `triggerleaderboardchange`.
- **Settings:**
  - `Constants/SettingConstants.luau` defines every setting (toggle or slider, menu section, per-device defaults). **Setting ids are permanent.**
  - `SettingsService` validates and saves them; `SettingsController` applies them (`getValue`, `SettingChangedTasks`, and its header lists every consumer).

## 5. Lobby

- `LobbyService` provides the lobby spawn point (`workspace.Lobby.LobbySpawnLocation`) and the `LobbyVolume` collision group.
- `LobbyLibrary.isCharacterInLobby` / `applyJumpState`: jumping is allowed only in the lobby. `LobbyController` fires `ClientIsInLobbyChangedTasks`.
- **Lobby stations:** see [`docs/LOBBY_STATIONS.md`](../docs/LOBBY_STATIONS.md). A Studio model tagged `LobbyStation` with a `StationId` gets a proximity prompt, floating title, glowing pad and per-player state; a service registers a handler. **The only station today is `GroupRewards`.** The prize wheel, crate stations, shop pedestals and server portal from `docs/LOBBY_SPEC.md` are backlog. Cmdr: `setstationstate`.
- The **winner pedestal** (tag `PlayerPedestal`, `PedestalService` / `PedestalController`) and the **leaderboards** are lobby objects, but not stations.
- The **AFK toggle** is in the left lobby menu (`PlayerSessionService`, the `OptedOut` attribute, Cmdr `optout`).

## 6. Saved data

- **`PlayerDataService`** (ProfileStore):
  - Store `"Dev"` in Studio, `"Live"` in live servers; profile key = the player's UserId.
  - The shape is `Shared/Data/ProfileTemplate.luau`. New fields are filled in by `Reconcile()` on load.
  - Read and write **only** through `PlayerDataService.get(player)` (a proxy that replicates changes to the player's client, `PlayerDataController`), never `profile.Data`.
  - `ShutdownSaveService` saves on shutdown.
- **Profile fields today:**
  - Stats: `Elims`, `Defeats`, `Wins`, `Losses` (unused, kept because it shipped), `RoundsPlayed`, `TimePlayed`, `Throws`, `AbilityUses`, `PickupsAcquired`, `MonthlyStats`.
  - Economy and rewards: `Currency`, `DailyRewards`, `GroupRewardLastClaim`, `Inventory`.
  - Cosmetics: `Owned…` / `Equipped…` for each of the five cosmetic categories.
  - Other: `Quests`, `Settings`, `ProcessedReceipts`, `GiftedPasses`.
- **Leaderboard stores:** `{Dev|Live}_{Elims|Wins}_AllTime` and `{Dev|Live}_{Elims|Wins}_{YYYY-MM}` (UTC month).
- **Rules:**
  - Change the `Profile` type and `ProfileTemplate.get()` together.
  - Never rename or repurpose a field that has shipped to live players.
  - IDs that are saved or sent over the network (item, skin, cosmetic, product, gamemode, pickup, setting ids) are permanent strings or numbers.
