# Boomerang: Task Board

The general task board: fixes, tooling, cleanup and small features. See [CLAUDE.md](CLAUDE.md) for how the project works.
Large features are **Epics**, each with its own task list under `docs/epics/<epic>/TASKS.md`: see [docs/EPICS.md](docs/EPICS.md). Active: [Lobby](docs/epics/lobby/TASKS.md).

## How to use this board

- **These rules apply to every task list**, general and Epic. A task keeps its ID when it moves between lists (general ↔ Epic): move the whole block, don't copy it. Epic tasks have an `Epic:` line.
- **Status is the section a task sits in.** To change it, move the whole task block to another section.
  `Ready` → `In Progress` → `Review` → `Done`. `Backlog` holds ideas that aren't ready to start.
- **Adding a task:** first **reserve** the next free ID (`T-###`) on `main` in the home repo ([docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md#2-reserve-a-task-id-before-adding-any-new-task)), then copy the template below into `Backlog` or `Ready` in your lane with that ID.
- **Priority:** `P0` breaks the game or blocks the current milestone · `P1` needed for the current milestone · `P2` nice to have.
- **Owner:** `Agent` (an agent can do it), `Sol` (design decisions or assets only Sol can provide), or `Sol → Agent` (Sol decides first, then an agent implements).
- **Agents:**
  - Only pick up tasks in `Ready` whose Owner is `Agent`, or `Sol → Agent` once Sol has answered its questions.
  - If a task has **Open questions**, ask Sol before starting.
  - Move the task to `In Progress` when you start, and to `Review` when you're done.
  - Fill in **Notes** with what changed, what still needs testing in Studio, and any `TODO:RELEASE placeholder` values you added.
  - When moving a task to `Review`, add a client-facing line to `Commits.txt` (see CLAUDE.md).
  - **Moving tasks to `Done` is the agent's job, not Sol's.** When Sol reports that a task passed testing in Studio, move it to `Done` and add a short note (e.g. "Passed Sol's Studio test (date)"). Never move a task to `Done` on your own judgment, before Sol has tested it.

**Next free ID: T-084** *(shared by every task list, general and Epic)*

<details>
<summary><b>Task template</b> (click to expand, then copy)</summary>

```markdown
### T-### · Short title
- **Priority:** P0 / P1 / P2
- **Owner:** Agent / Sol / Sol → Agent
- **Epic:** <Epic name>   ← only in Epic task lists; omit here
- **Area:** Server / Client / Shared / GUI / Data / Tooling
- **Files:** `path/to/file.luau`

**Problem / goal**
What's wrong, or what should exist.

**Open questions (ask Sol first)**
- (Remove this section if there are none.)

**Done when**
- [ ] Concrete, checkable outcome

**Test in Studio**
- Step to verify it works

**Notes**
(Filled in by whoever works on it.)
```
</details>

---

## Ready

> **Urgent: instructed by Sol to do today (2026-10-03).** T-062 to T-067 come before everything else in Ready.

### T-005 · Convert space-indented files to tabs
- **Priority:** P2
- **Owner:** Agent
- **Area:** Tooling
- **Files:** every `.luau` / `.lua` file under `src/` that uses 3-space indentation, **except** the "Leftover and reference modules" listed in CLAUDE.md

**Problem / goal**
Sol decided the standard is **tabs**. Many newer files use 3 spaces, and some mix both. Convert **leading indentation only**: each 3-space step becomes one tab. Mixed lines (tabs and spaces) are normalised to the indentation level they visually sit at.

- **Don't run StyLua**: it would also change call parentheses, line wrapping, quotes, etc. Use a script that only touches leading whitespace.
- Don't touch multi-line strings (`[[ ... ]]`) or block comments whose content alignment matters. Check the diff for these.
- Don't touch `.rbxmx`, `Packages/`, `ServerPackages/`, or the leftover/reference files.
- Do it in batches by folder (e.g. `Server/`, `Client/`, `Shared/`) so each batch is easy to review with `git diff -w` (which should show no changes).

**Done when**
- [ ] No in-scope file has a line whose leading whitespace contains spaces (except alignment inside block comments/strings, listed in Notes).
- [ ] `git diff -w` shows nothing for the converted files.

**Test in Studio**
- Start a server and join: no new errors in the output. (Whitespace-only change; this is just a sanity check.)

**Notes**

---

## In Progress

## Review

### T-077 · Telekinesis pickup: steer your thrown boomerang
- **Priority:** P2
- **Owner:** Agent
- **Area:** Shared / Client / Server
- **Files:** `Shared/Logics/PickupLogics/TelekinesisBoomerang.luau`, `Shared/Logics/WeaponLogics/Boomerang.luau`, `Shared/Referential/ThrownWeapons.lua`, `Shared/Library/BoomerangTuningLibrary.luau`, `Shared/Library/PickupLibrary.luau`, `Shared/Constants/GlobalConfig.luau`, `Client/Core/WeaponController.luau`, `Server/Core/WeaponService.luau`

**Problem / goal** (split from T-010)
Implement the TelekinesisBoomerang stub. While the effect is active, the owner can nudge their thrown boomerang toward their aim — a gentle bias, not full control, so it slowly turns toward the cursor (PC) or the direction the aim thumbstick is dragged (touch).

**Done when**
- [ ] Pickup enabled and spawnable; effect lasts `GenericEffectTimeout`.
- [ ] The owner's aim bends the thrown boomerang (server-authoritative, client-predicted, reconciled by the usual snapshots).
- [ ] Input sits behind one provider function per control scheme (PC mouse, touch thumbstick, console stubbed) so it's easy to change later.
- [ ] Steering strength tunable live via Cmdr `tune TelekinesisInfluence <n>`.

**Test in Studio**
- Get the pickup (spawn one / force it), throw, then:
  - PC: move the mouse while it flies — it should slowly curve toward the cursor, not snap.
  - Touch: after throwing, drag the aim thumbstick — the boomerang should bias that way; releasing stops steering and must NOT throw again.
- `tune TelekinesisInfluence 5`, throw: it should turn faster. `reset TelekinesisInfluence` restores the default (2).
- Confirm it only steers your own boomerang, not other players'.

**Open questions (for Sol)**
- Steering applies while the boomerang is flying out (Outgoing/Exhausted), not during its automatic return — confirm that feels right.
- Default influence is 2 (Homing is 3). Tune to taste.

**Notes**
- Branch `agent/T-077-telekinesis`, lane `Boomerang-lanes/T-077-telekinesis`.
- Added `TelekinesisBias` to `ThrownWeapons.Data`; the flight loop lerps `direction` toward it (`Boomerang.luau`, next to Homing), on server and the owner's client.
- Client (`WeaponController`) streams the aim direction over a new unreliable remote `TelekinesisSteer` (throttled ~20 Hz) and predicts locally; server (`WeaponService`) validates (effect active + thrown weapon) and sets the bias. Added `PickupLibrary.isEffectActive`.
- New tuning setting `TelekinesisInfluence` in `BoomerangTuningLibrary`; default from `GlobalConfig.TelekinesisSteerInfluence = 2`. The existing `tune` / `reset` Cmdr commands pick it up automatically.
- No new placeholders added. `AcquirableThingData.TelekinesisBoomerang` already existed with a placeholder `Img = 17` (pre-existing; its real icon is part of T-018).
- Telekinesis and Homing are mutually exclusive (Sol, 2026-10-09): PickupService `NotCompatible` keeps the other out of the pickup pool while you have one.
- Couldn't syntax-check here (no Luau/selene/rojo on the device); needs a Studio load to confirm it compiles.

---

### T-076 · Shop GUI (new art, tabs, rarity)
- **Priority:** P1
- **Owner:** Agent
- **Area:** GUI / Client
- **Files:** `Client/UI/Gui/Shop/` (`init.luau`, `RarityStyles.luau`, `ShopListings.luau`, `Tabs/`), `Client/Core/ShopController.luau`, `Shared/Referential/ShopItems.luau`, `Shared/Constants/Icons.luau`

**Problem / goal**
Build the Shop menu from Sol's new art (frame, tab button, listing base, balance plank, square and wide buttons) following Sol's reference image. Tabs: Featured, Skins, Emotes, Arrows, Effects. Featured and Skins work; the other tabs are selectable but blank. The grid shows 3x2 listings; Featured never scrolls, Skins scrolls past 6.

**Done when**
- [ ] The Shop opens from the lobby Shop button (and B in Studio) with the new art, red X, tab row and balance plank
- [ ] Featured shows the hand-picked skins; Skins lists every skin on sale (same system as the Inventory's Skins tab)
- [ ] Buying a skin with Currency updates the listing to "Owned" and the balance

**Test in Studio**
- Open the Shop: purple Featured tab selected, the other tabs brown; Featured shows Shuriken and Fan (Common, gray frames) with their 3D models and coin prices; balance at the bottom matches your Currency.
- Click Skins, Emotes, Arrows, Effects: Skins lists the skins on sale; the other three open blank.
- To see the scroll bar: temporarily add more `Skins` entries (more than 6 on sale) and open the Skins tab; the cells should shrink slightly to make room for the bar. Resize the Studio window to check it scales.
- Your Studio profile already owns Shuriken and Fan, so both show a gray "Owned" button. To test a purchase you need a profile that doesn't own one (remove it from `OwnedSkins`, or use a fresh Studio store key), then F2 → `givecurrency me 5000` and click the price: the button turns gray "Owned" and the balance drops.
- Check that the whole menu covers the screen without a gap at the top (IgnoreGuiInset) and the close X works.
- The Robux price button and the gift button aren't visible yet: no skin has a `ProductId`, and gifting is off (`GIFTING_ENABLED` in `Shop/init.luau`).

**Notes**
- Branch `agent/T-076-shop-gui`, lane `Github/Boomerang-lanes/T-076-shop-gui`.
- Built entirely in code with `CreateElement` (like Stats); the old `Shop.rbxmx`, `ItemListingTemplate.rbxmx` and `TabButtonTemplate.rbxmx` were removed, and so was the old Topbar Shop button (MenuButtons opens the Shop). The ScreenGui has `IgnoreGuiInset = true` and `ScreenInsets = None` (no safe areas).
- Tabs are declared in `ShopItems.Tabs` (name, order, emoji icon). A tab's content is `Shop/Tabs/<Id>.luau` (shape `ShopTab` in `Shop/init.luau`: `Scrollable`, `MaxListings?`, `getListings`, `subscribe`). Tabs without a module (Emotes, Arrows, Effects) open blank: add a module to set one up.
- Listings come from `ShopListings.getDisplay` (skins via `SkinLibrary` / `SkinController`, items via `Items`); the model is shown with `ItemViewport`.
- Rarity: a listing's rarity is the `Rarity` of its model's entry in `Tools.luau`; `RarityStyles.luau` maps a rarity to the frame tint and name color (insertion point). Every tool is still the `Common` placeholder, so every listing is gray for now.
- Layout is all scale, except the grid's cell size and scroll bar width, which are measured from the grid and recomputed when it resizes (a ScrollingFrame's children can't use scale for this). 
- Placeholders: tab emoji (`ICON_EmojiPlaceholder` labels, in their own label so they can become images later). The Skins tab uses 🎨 because the boomerang emoji doesn't draw in Roblox's font.
- `Icons.luau`: added `ShopFrame`, `ShopTabButton`, `ShopListingBase`, `ShopBalanceFrame`, `ShopSquareButton`, `ShopWideButton`, `GiftIcon`, `RobuxIcon`. `TODO:` Sol gave the same asset id for the square and wide buttons; check it's the wide art.
- `ShopController.requestRobuxPurchaseItem` now takes the listing type, so skins with a `ProductId` can be bought with Robux (the server-side grant for a skin product isn't set up: no skin has a product yet).
- Not tested in Studio: the lane couldn't be served through Rojo from here. Everything in this task needs a Studio check.

### T-075 · Inventory GUI (new art, tabs)
- **Priority:** P1
- **Owner:** Agent
- **Area:** GUI / Client
- **Files:** `Client/UI/Gui/Inventory/` (was `Gui/Skins/`), `Client/UI/Gui/MenuButtons/init.luau`, `Shared/Constants/Icons.luau`

**Problem / goal**
Apply Sol's Inventory art (primary frame, item listing frame, tab frame) to the Skins menu, following Sol's reference image. No separate Equip button: each listing is the button; the equipped one is green and shown in the large panel on the right. Tab column (Skins, Emotes, Arrows, Effects) set up modularly; only Skins works for now.

**Done when**
- [ ] Inventory opens from the lobby Skins button with the new art and the tab column
- [ ] Clicking an owned skin equips it; its listing turns green and it shows in the Detail panel

**Test in Studio**
- Open Skins (left menu): frame, "Your Skins" title, 4 tabs on the left, Classic listing green and shown on the right.
- F2 → `grantskin me Shuriken` → Shuriken appears (tan); click it → Detail panel shows Shuriken, "Common" and an Equip button; click Equip → listing turns green, "Equipped" shows, held boomerang swaps. Check the 3D models fit inside each listing and the Detail panel.
- Emotes / Arrows / Effects tabs show (darker) and do nothing yet.
- Check the layout of `Inventory.rbxmx`, `InventoryListingTemplate.rbxmx`, `InventoryTabTemplate.rbxmx` in Studio (positions were set by hand from the reference; tweak freely).

**Notes**
- Branch `agent/T-075-inventory-gui`, lane `Github/Boomerang-lanes/T-075-inventory-gui`.
- `Gui/Skins` renamed to `Gui/Inventory` (UIController name "Inventory"; MenuButtons' Skins button opens it). The old Shop-style `.rbxmx` files were removed.
- Tabs: `TABS` in `Inventory/init.luau`; a tab's content is `Inventory/Tabs/<Id>.luau` (shape `InventoryTab`: `Title`, `getItems`, `selectItem`, `subscribe`). Tabs without a module are shown darker and do nothing.
- All listings and tabs have an empty `ICON` ImageLabel placeholder (the 3D ViewportFrame previews were dropped). `InventoryItem.Icon` fills it once icons exist.
- The item listing art has transparent padding: listings and the Detail panel are transparent and hold an oversized `Art` ImageLabel (scale-only values in `Icons.luau`), so the visible frame fills the cell. Listing colors are set on `Art`. (First version cropped with ImageRectOffset in pixels, which broke because Roblox downscales uploads over 1024px.) No Offset values in the Inventory .rbxmx files; text strokes use ScaledSize.
- Follow-up (Sol, 2026-10-06): only owned skins are listed; the Detail panel uses the item listing art tinted brown (panel widened to 42% of the content to limit stretching); `Rarity` added to `Tools.luau` (skins read it through their model's tool entry) and shown under the name in the Detail panel.
- `TODO:RELEASE placeholder`: `Rarity = "Common"` on ClassicBoomerang, Shuriken and Fan in `Tools.luau`.
- Follow-up 2 (Sol, 2026-10-06): clicking a listing only selects it (lighter tint) and shows it in the Detail panel; the panel shows an Equip button (ListingFrameButtonGreen) when the selected skin isn't equipped, and "Equipped" when it is. Listings and the Detail panel show the 3D tool model (same asset as the character holds) via the new reusable `Client/UI/ItemViewport.luau` (`renderTool` / `renderModel`), which fits the model into a square camera automatically. Per-model pose: `Viewport = { Rotation, Zoom? }` in `Tools.luau` (angles picked with a test viewport GUI, `StarterGui.ViewportTest`, left disabled in the place; delete it whenever).
- Icons.luau: added `InventoryFrame`, `InventoryItemListingFrame`, `InventoryTabFrame`.

### T-074 · Stats menu
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client / GUI / Server / Data
- **Files:** `Client/UI/Gui/Stats/`, `Client/UI/Gui/MenuButtons/init.luau`, `Server/Core/LifetimeStatsService.luau`, `Shared/Data/ProfileTemplate.luau`, `Server/Cmdr/Commands/ShowStatsServer.luau`

**Problem / goal**
A Stats button in the left lobby menu opens a Stats menu showing the player's lifetime stats. Left: six cards, in order Time Played, Eliminations, Defeats, Games Played, Games Won, Throws. Right: the smaller stats (times each ability was used, times each pickup was collected) as placeholder rows with a count, no fill bar. Layout sized after Sol's reference screenshot, without its "Personal Stats" / "Ability Usage Comparison" labels. Uses the DailyClaims base frame (title centered, no streak number), its X button and its card frame for now.

**Decisions (Sol, 2026-10-05)**
- 5th card is Games Won (the request listed Eliminations twice).
- The right list has abilities and pickups.
- New saved stat `Throws`: every successful weapon throw.

**Done when**
- [ ] The Stats button opens/closes the menu; the X closes it.
- [ ] The six cards and the list show the player's saved values, and Throws counts up.

**Test in Studio**
- Open Stats from the left menu. New profile: cards show 0 Min / 0, and the list shows Dash, Stab and the enabled pickups with 0.
- Throw a few times, dash/stab, grab a pickup, then reopen: Throws and the counts went up (F2 `showstats me` shows the same values, incl. Throws). Time played shows minutes under an hour, hours after (saved every minute).
- Check `Stats.rbxmx` / `StatListingTemplate.rbxmx` in Studio: card sizes, text positions, row height (rows scale to the list's width, 7:1), and the list scrolls when rows overflow.

**Notes**
- Branch `agent/T-074-stats-gui`, lane `Github/Boomerang-lanes/T-074-stats-gui`.
- Card icons and row icons are the Roblox placeholder image; the rows are plain code-colored frames (placeholders for Sol's art). Menu button uses placeholder emoji art like the others.
- Pickup rows skip stub pickups (`Disabled = true`). Row names use the item-acquired notification titles (`AcquirableThingData`); ids without an entry (Dash, Stab) are spaced out from the id. Each group is sorted most-used first.
- The `.rbxmx` files are Sol's Studio saves (Rojo hadn't synced the hand-written ones); card number/label moved closer, list text slimmer (Sol, 2026-10-05).
- `Throws` counts through `SharedTasks.WeaponThrownTasks` (fired once per accepted throw). With the debug switch `SyncAbilitiesToEveryPlayer` on, the copied throws count for every player.

---

### T-073 · Returning boomerang circles the player instead of reaching them
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Logics/WeaponLogics/Boomerang.luau`

**Problem / goal**
A returning boomerang (mostly the held manual recall of a dead boomerang, sometimes a normal return) can miss the player and keep curving around them; moving in circles keeps it orbiting. It should turn into the player more directly.

**Done when**
- [ ] A manual recall of a dead boomerang reaches the player instead of orbiting, even while they run in circles
- [ ] Normal returns still feel the same from a distance and no longer curve around the player up close

**Notes**
- Branch `agent/T-073-return-accuracy`, lane `Github/Boomerang-lanes/T-073-return-accuracy`.
- Cause: in `Boomerang.recall` the whole velocity eased toward the player at `5 × RecallAcceleration` per second. Manual recall uses `ManualRecallMomentumMultiplier = 0.15`, so it turned at ~0.75/s; at 80 studs/s that's a turning circle of roughly 100 studs, wider than the distance to the player.
- Fix: the velocity is split into the part heading at the player and the sideways part. The forward part still builds up at the old (heavy) rate. The sideways part is removed at least `RETURN_STEER_TIGHTNESS × speed / distance` per second (constant at the top of the file, default 3; 1 would be a perfect circle). Far away nothing changes; up close it turns in hard enough to always spiral inward.
- Test in Studio: manual recall a dead boomerang from various angles and run circles around it; normal throws from max range while strafing. If it now looks too snappy up close, lower `RETURN_STEER_TIGHTNESS` (try 2); if it still curves, raise it.

### T-072 · Boomerang skins (equip, shop, daily rewards)
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server / Client / Shared / GUI / Data
- **Files:** `Shared/Referential/Skins.luau`, `Shared/Library/SkinLibrary.luau`, `Server/Core/SkinService.luau`, `Client/Core/SkinController.luau`, `Client/UI/Gui/Skins/`, `Client/UI/Gui/MenuButtons/init.luau`, `ShopItems.luau`, `DailyRewards.luau`, `Items.luau`, `ProfileTemplate.luau`, `WeaponService`, `ToolService`, `WeaponController`, `WeaponLogics/Boomerang.luau`, Shop + DailyClaims GUIs, `Server/Cmdr/Commands/GrantSkin*.luau`, `Server/Cmdr/Types/SkinType.luau`

**Problem / goal**
Equippable boomerang skins with identical stats (every skin uses the `ClassicBoomerang` weapon class for now; the weapon-class concept stays). Skins button in the left lobby menu, Skins GUI, owned/equipped skins saved, granted via Shop, Daily Rewards and Cmdr. Starting skins: Shuriken, Fan (Classic is the default, always owned).

**Done when**
- [ ] A skin can be obtained from the shop, daily rewards and `grantskin`
- [ ] Skins menu opens from the lobby menu, equips owned skins, and the held + thrown boomerang use the skin's model
- [ ] Owned and equipped skins persist across rejoins

**Test in Studio**
- F2 → `grantskin me Shuriken` → "New skin acquired!" popup. Open Skins (left menu) → Shuriken shows Equip, Fan shows Locked → Equip → held model swaps; throw it: the thrown model is the Shuriken too (check from a second client as well).
- Rejoin: Shuriken still owned and equipped.
- Shop → Skins tab lists Shuriken/Fan; `givecurrency me 2000`, buy Fan → shows Owned, appears in Skins.
- `resetdaily me true` and claim up to day 3 (`resetdaily me` between claims): day 3 grants Shuriken, or +250 Currency if already owned. Day 7 = Fan.
- Check `Skins.rbxmx` / `SkinListingTemplate.rbxmx` in Studio (copied from the Shop panel/card; ViewportFrame preview angle may need tuning).

**Notes**
- Branch `agent/T-072-skins`, lane `Github/Boomerang-lanes/T-072-skins`.
- Profile: new `OwnedSkins` (default skins aren't stored) and `EquippedSkin`. The server sets an `EquippedSkin` Player attribute; the server now decides the throw/aim weapon class instead of trusting the client.
- Shop: `ShopTab.Items` became `Listings` (`{Type = "Item" | "Skin", Id}`); Example items and the Weapons tab removed; `CurrentDeal` is nil. `ProductLogics/Placeholder.luau` kept with `NotActive = true` (Sol's choice).
- `TODO:RELEASE placeholder`: Shuriken/Fan prices (500/1000) and `WeaponClass`, all daily currency amounts and skin `FallbackCurrency` (250/500).
- Skins GUI uses the Shop panel/card assets; no title label yet. Sol may want to restyle.
- Follow-up (Sol's feedback): skin cards are shorter to fit their content (bigger preview, cell height 0.25 → 0.205); the Fan's `MotorC0` attribute was moved so it's held by its handle in the hand instead of up the arm (rotation unchanged).

### T-037 · Player HUD buttons
- **Priority:** P1
- **Owner:** Sol → Agent
- **Area:** GUI / Client
- **Files:** `Client/UI/Gui/MenuButtons/init.luau` (new), `Client/UI/Gui/DailyClaims/init.luau`

**Problem / goal**
The player needs a HUD with buttons. Known so far:
- **Currency**: shows the player's Currency; clicking opens a Robux shop tab to buy more Currency.
- **Shop**: opens the shop.
- **Quests**: opens quests (feature: T-038).
- **Achievements**: opens achievements (feature: T-039).
**Sol:** decide the full button list and make the assets. **Agent:** wire each button (Currency display via `EconomyController.CurrencyChangedTasks`, opening GUIs via `UIController`). Buttons for features that don't exist yet stay hidden.


**Decisions (Sol, 2026-10-03)**
- Buttons: Currency, Shop, Quests, Achievements, Daily (Daily moves off the top bar). Quests/Achievements hidden until T-038/T-039 exist.
- Layout from Sol's mockup (sizes/layout only, not its buttons): left side, vertical; Currency on top, two buttons wide, with room for a boomerang icon; below it a 2-column grid of square-ish buttons with a name plate.
- Placeholder art for now (Sol's assets later). Clicking Currency will open a Robux shop for buying Currency; that shop comes later, so the click is a stub for now.

**Notes**
- Branch `agent/T-037-hud-menu-buttons`, lane `Github/Boomerang-lanes/maintenance`.
- New code-built `MenuButtons` gui (no `.rbxmx`): placeholder colored tiles with emoji icons (🪃 currency, 🛒 Shop, 🎁 Daily, 📜 Quests, 🏆 Achievements) and FredokaOne labels. Sizes, colors, icons and position are constants at the top of the module; it scales with screen height (UIScale) and sits at 42% height so it stays clear of the mobile thumbstick.
- Currency shows `EconomyController` balance with thousands separators and updates live. Click: `openCurrencyShop()` stub (prints in Studio only).
- Shop toggles the Shop gui; Daily toggles Daily Rewards. The top bar's Daily button was removed (DailyClaims no longer registers it; the Topbar module stays for future buttons).
- Quests/Achievements: `MenuButtonsGui.setButtonEnabled("Quests", true, QuestsGui.toggle)` turns one on when its feature exists; hidden buttons don't leave gaps.
- Hidden while you're alive in the arena (lobby menu); say if it should show during rounds too.
- Didn't use `HudButtons/Hud.rbxmx` (that's the in-round Throw/Dash/Stab buttons).
- Not lint-checked.
- **Art pass (2026-10-06, branch `agent/hud-left-art`, lane `Github/Boomerang-lanes/hud-left-art`):** `MenuButtons` now uses Sol's assets. Buttons = grayscale interior `138558379535634` (cropped with `ImageRectOffset`/`ImageRectSize`, tinted per button with `ImageColor3`; 9-slice rendered wrongly in Studio) under the wooden frame `78059494085912`; currency bar = `97631724752812`. Icon and name text sit in the frame's free window and name board; the art's free-space rectangles are constants (`FRAME_ICON_AREA`, `FRAME_BOARD_TEXT`, `BAR_COIN_AREA`, `BAR_TEXT_AREA`) converted to Scale. Icons and the currency coin are still emoji placeholders. Button size is now 100x90 (the frame art's proportions).
- **Update (2026-10-06, branch `agent/hud-left-currency-icon`):** the currency bar now shows Sol's coin image `110596837298294` (`CURRENCY_ICON`: left 5%, centered vertically, 70% of the bar height, square). Quests and Achievements were removed from the left bar (Sol: only Currency, Shop, Daily, Skins, Stats); `setButtonEnabled` stays for any later button.
- **Test in Studio:** the tint only multiplies the grayscale (average ~50% gray), so button colors come out darker than a bright mockup; adjust the `Color` tints in `BUTTONS`, or lighten the grayscale asset. Check the text fits on the name board ("Achievements" is the longest, hidden for now), and the balance on the bar with big numbers.

---

### T-060 · Bug: aim arrow stays visible while not aiming
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client / Weapons
- **Files:** `Client/Core/WeaponController.luau` (aim arrow), `Shared/Library/PlayerStatsLibrary.luau` (`CurrentMovementState` "Aiming"), `Server/Core/WeaponService.luau`

**Problem / goal**
Sometimes the aim arrow stays visible while the player isn't otherwise aiming: they walk at normal speed instead of the slow aiming speed. Often happens after throwing a boomerang. Likely the arrow's visibility and the aiming movement state are cleared by different paths (e.g. throw, release, recall, weapon lock, death, the stats reset on `LobbyVoting`) and one of them misses the other. Find the cause and make both follow one source of truth.

**Done when**
- [ ] The arrow is only visible while the player is in the aiming state, including after throws, recalls, deaths and round changes.

**Test in Studio**
- Throw repeatedly (fast taps, hold-and-release, throw right as the boomerang returns, throw during weapon lock): the arrow never stays without the slow aiming walk.

**Notes**
- Branch `agent/T-060-aim-arrow-race`, lane `Github/Boomerang-lanes/T-060-aim-arrow-race` (first fix: `agent/T-060-aim-arrow-visibility`, shipped).
- **Review 2 (2026-10-05): failed** - Sol: the arrow alone still sometimes stays (walk speed and the rest are fine), rare race.
  - Cause: `beginAiming` waits for the character model (`getCharacterModel(player, true)` can yield up to 5 s while the model is being built, e.g. right after a respawn or a ragdoll rebuild). If the throw/cancel happened during that wait, `stopAiming` found no arrow to remove, then `beginAiming` resumed and created one that nothing ever removed. Affected other players' arrows too.
  - Fix: a per-player arrow generation counter (bumped by every begin/stop); a `beginAiming` that was overtaken while waiting no longer creates the arrow. Backstop: the render loop removes the local arrow on any frame where the local player isn't aiming.
- Causes found (client and server aim could disagree, and the arrow only listened to the server):
  - When the client dropped its aim without throwing (weapon locked mid-aim, throw refused while locked, round change to LobbyVoting), the server was never told, so it kept the player "aiming".
  - A "stop aiming" from the server was dropped while the weapon was locked, so the arrow stayed.
  - LobbyVoting cleared the local aim but not the arrow.
  - A late "aiming" confirmation from the server could re-create the arrow after the player had already released.
- Fix: the local arrow now follows the local aim (`setLocalAimState(false)` always removes it). A new `WeaponAimCancel` remote tells the server when the client leaves aim without a throw; the server's new `cancelAiming` (also called by `applyLockOnWeapon`) clears its aim, restores walk speed and tells every client to hide the arrow. A late aim confirmation for an aim the player already left is answered with a cancel instead of an arrow.
- Not lint-checked.

---

## Backlog

### T-061 · Replace the placeholder Group Rewards chest with the real model
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Build (Studio)
- **Files:** Studio: `workspace.Lobby.GroupRewardsChest` (place-only)

**Problem / goal**
T-058 put a placeholder chest in the lobby (simple parts). Replace it with the final chest model and art (LOBBY_SPEC: a large locked treasure chest on a glowing activation pad, prominent "GROUP REWARDS" label), keeping it a lobby station.

**Open questions (ask Sol first)**
- The final model (Sol provides it), and whether it should look different when claimed/locked (an open lid, a lock): that would be a small `GroupRewardController` addition reading the station state.

**Done when**
- [ ] The final model replaces the placeholder, with the `LobbyStation` tag and the same attributes (`StationId = "GroupRewards"`, `Title = "GROUP REWARDS"`, `MaxDistance`) and a glowing part named `Pad` (or `PadPart` set).
- [ ] Title and prompt sit well on the new model (`PromptPart` / `TitleHeight` if needed).

**Test in Studio**
- Same as T-058: walk up, claim, `resetgroupreward me`, `simulategroupmember me nonmember`.

**Notes**

---

### T-059 · Review arena enter/exit and round start/end for race conditions
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server / Rounds
- **Files:** `Server/Core/RoundCyclingService.luau`, `SpawnService.luau`, `ArenaService.luau`, `GameTeamService.luau`, `Shared/Library/GameStateLibrary`, `Shared/Utils/PlayersUtil`, `Shared/Logics/GamemodeLogics/*`

**Problem / goal**
Sol occasionally hits race conditions when players enter or leave the arena and when a round starts or ends. Review how these transitions are managed and propose improvements (or confirm the rest is an acceptable byproduct). Propose before changing code.

Starting points from a quick read (2026-10-02, not verified):
- `ArenaService.sendToArena` → `getSpawnPoint` can yield up to ~6s waiting for the character/PrimaryPart, then teleports and adds the player to `LivingPlayersInArena` without re-checking that the same round is still active (only a partial round-id check after the waits).
- `LivingPlayersInArena` is read-cloned-written from several places (`sendToArena`, `setArena`, CharacterDied, PlayerRemoving, round end). Fine while nothing yields in between, fragile otherwise.
- "Who is in the round" lives in three places: `LivingPlayersInArena`, `SpawnService.roundParticipants` and player teams.
- Order at round start: `RoundActive` phase is applied (subscribers fire) **before** `ArenaService.setArena` clones the map and before `RoundStartingTasks` / gamemode `setup()`. `MapChangedTasks` and `RoundStartingTasks` run `"parallel"`; `PlayersUtil` events run `"deferred"`, so subscriber order isn't guaranteed.
- Round end has two paths: timer (`endActiveRound` → `teardown()`) and the gamemode firing `RoundFinishedTasks`. Check one can't run twice or overlap the other.
- `PlayerStatsLibrary` resets every player's stats on `LobbyVoting`, which can overlap with in-flight state.

Possible directions: a round id / token checked after every yield; one owner for "round participants"; a fixed, documented order of steps at round start/end instead of parallel subscribers.

**Done when**
- [ ] Short write-up in Notes: each race found, how likely it is, proposed fix (or "acceptable").
- [ ] Sol picks which fixes to make (follow-up tasks).

**Open questions**
- Any specific repro Sol remembers (gamemode, number of players, what went wrong)?

**Notes**

---


### T-052 · Close Cmdr before public release
- **Priority:** P2 now · **RELEASE BLOCKER:** must be done before the game's public release
- **Owner:** Sol → Agent
- **Area:** Server / Shared
- **Files:** `Shared/Constants/GlobalConfig.luau` (`CmdrOpenToEveryone`), `Server/Core/CmdrService.luau` (admin list, group rank)

**Problem / goal**
For client review, `GlobalConfig.CmdrOpenToEveryone = true` lets **every player** in a live server use the F2 console (end rounds, grant currency and pickups). Not urgent while the game is in review, but it **must** be switched off before the public release, or any player can cheat.

**Open questions (ask Sol first)**
- Which developers' UserIds go in the admin list, and which group/rank (if any) counts as admin?

**Done when**
- [ ] `CmdrOpenToEveryone = false`.
- [ ] The admin UserIds and group rank in `CmdrService` are filled in (no `TODO:RELEASE placeholder` left there).

**Test in Studio**
- Published test place, non-admin account: F2 does nothing and Cmdr remotes refuse commands. Admin account: F2 works.

**Notes**

---

### T-014 · Spec vs. code differences: decide which to change
- **Priority:** P1
- **Owner:** Sol → Agent
- **Area:** Shared / Server
- **Files:** `docs/GAME_DESIGN.md` (bottom table), `GlobalConfig.luau`, `Logics/GamemodeLogics/Classic.luau`

**Problem / goal**
The client's MVP spec and the code differ in a few places (minimum players, respawn forcefield length, Classic's winners: top 3 + podium vs a single winner, boomerang bounces). Some may be deliberate.

**Open questions (ask Sol first)**
- For each row in the table: keep the code, or change it to match the spec?

**Done when**
- [ ] Each difference is either accepted (noted in GAME_DESIGN.md) or split into its own implementation task.

**Notes**

---

### T-008 · Release check: GlobalConfig values that are set for testing
- **Priority:** P1 *(before release)*
- **Owner:** Sol
- **Area:** Shared
- **Files:** `src/Shared/Constants/GlobalConfig.luau`

**Problem / goal**
`PlayersRequiredToStart = 1` is hard-set; the commented-out line suggests the intended value is `if isStudio then 1 else 2`. Also review `SkipVoting`, `ForceEquippedTool`, `ForceOverwritePickup` and the debug visualiser switches before release.

**Done when**
- [ ] Each value is confirmed for release, or marked `-- TODO:RELEASE`.

**Notes**

---

### T-010 · Stub pickups (`-- STUD`): design and implement
- **Priority:** P2
- **Owner:** Sol
- **Area:** Shared
- **Files:** `src/Shared/Logics/PickupLogics/` (`BattleRoyale`, `DashNoclip`, `Decoy`, `ExtraBoomerang`, `IceBoomerang`, `MultiBoomerang`)

**Problem / goal**
These pickups are stubs (`Disabled = true`, marked `-- STUD` / `-- TODO`) with only a one-line description. Each needs its design written before an agent can implement it. Split into one task per pickup when a design is ready.

**Notes**
- TelekinesisBoomerang split out to T-077 (implemented, in Review).
- ExplosiveBoomerang and Disguise are already implemented (not stubs); removed from the list. The `-- STUD` / `-- TODO` header lines left in Disguise.luau are just stale comments.

---

### T-011 · Stale header TODOs in GameTeamService, HitboxService, LobbyService
- **Priority:** P2
- **Owner:** Sol
- **Area:** Server
- **Files:** `src/Server/Core/GameTeamService.luau`, `src/Server/Core/HitboxService.luau`, `src/Server/Core/LobbyService.luau`

**Problem / goal**
The file headers say "TODO: figure out how teams should work" (HitboxService has the same text, probably copy-pasted). Teams now exist (TeamClassic, TeamElimination). Confirm and remove or rewrite the TODOs.

**Notes**

---

### T-017 · Hot Potato "bomb will explode" GUI (replace the placeholder)
- **Priority:** P2
- **Owner:** Sol
- **Area:** GUI
- **Files:** `Shared/Logics/GamemodeLogics/HotPotato/HotPotatoGui.rbxmx`, `HotPotato/init.luau`

**Problem / goal**
The Hot Potato "bomb will explode" GUI is a placeholder. Sol creates the final image assets and layout; an agent can wire up any behaviour changes afterwards.

**Notes**

---

### T-018 · Icons for every pickup effect
- **Priority:** P2
- **Owner:** Sol
- **Area:** GUI
- **Files:** `Client/UI/Gui/ItemAcquired/`, `Client/UI/Gui/Effects/`, `Shared/Constants/Icons.luau`

**Problem / goal**
Every pickup effect needs an icon, shown both in the pickup notification (ItemAcquired) and in the status-effects GUI (Effects). Sol creates the images; an agent registers the IDs in `Icons.luau` and hooks them up if that isn't automatic.

**Notes**

---

### T-020 · ItemAcquired: show 3D models in a ViewportFrame
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** GUI / Client
- **Files:** `Client/UI/Gui/ItemAcquired/` (`init.luau`, `Template.rbxmx`)

**Problem / goal**
ItemAcquired can only show images. When a tool/model is acquired (e.g. a new boomerang), it should show the model in a ViewportFrame instead.
- **Sol:** add a ViewportFrame (and camera framing preferences) to the ItemAcquired template.
- **Agent:** clone the item's model into it, frame it automatically (bounding box), optionally spin it slowly, and clean it up when the popup closes. Images stay supported.

**Open questions (ask Sol first)**
- Where does each item's model come from (e.g. `Shared/Assets/Tools/<ToolId>`)? Should `Items` entries get a `Model` field?

**Notes**

---

### T-021 · Login rewards (Daily Claims) GUI assets
- **Priority:** P2
- **Owner:** Sol
- **Area:** GUI
- **Files:** `Client/UI/Gui/DailyClaims/DailyClaims.rbxmx`

**Problem / goal**
The Daily Claims GUI uses placeholder visuals. Sol creates the final assets.

**Notes**

---

### T-022 · Finish the shop GUI assets
- **Priority:** P2
- **Owner:** Sol
- **Area:** GUI
- **Files:** `Client/UI/Gui/Shop/` (`Shop.rbxmx`, `ItemListingTemplate.rbxmx`, `TabButtonTemplate.rbxmx`)

**Problem / goal**
The shop GUI still has placeholder/progress visuals. Sol finishes the assets.

**Notes**
- T-076 rebuilt the Shop GUI in code with Sol's new art; the three `.rbxmx` files listed above were removed.

---


### T-049 · Redeem codes system
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Client / GUI
- **Files:** New: e.g. `Server/Core/CodesService.luau`, a server-only codes list, a client controller; GUI by Sol

**Problem / goal**
Players enter a code to receive a reward. Server: validates the code (case-insensitive), checks expiry and that the player hasn't redeemed it (saved in the profile), grants through `EconomyService` / `ItemService`, rate-limits attempts. Client: sends the code from the GUI and shows the result (ItemAcquired popup / message).

**Open questions (ask Sol first)**
- Reward types (Currency, items, wheel spins later?), expiry dates, limited-use codes?
- Where is the code entry opened (HUD button, settings)? GUI assets are Sol's.

**Done when**
- [ ] Codes live in a server-only module (never replicated).
- [ ] Redeeming works once per player per code and survives rejoin.
- [ ] A Cmdr command lists codes / resets a player's redeemed codes for testing.

**Notes**

---

## Done

### T-062 · Boomerang snaps back when it flies too far; it should auto-return instead
- **Priority:** P0 (urgent, do today: Sol 2026-10-03)
- **Owner:** Agent
- **Area:** Shared / Server / Client
- **Files:** `Shared/Logics/WeaponLogics/Boomerang.luau` (`autoRecallOrDie`, recall/dead state), `Shared/Constants/GlobalConfig.luau` (`BoomerangRecallRange`)

**Problem / goal**
Right now the boomerang snaps back when it flies too far away. Instead, flying too far should **trigger a return**, not a snap.
- Presumably it enters the dead state because of distance (out of range, per T-035).
- If the dead state's "look for a place to land" makes it keep sliding further and further away, it should switch to an **automatic recall state** and fly back to the player on its own (no manual recall needed).

**Done when**
- [ ] No snap/teleport back at long range: the boomerang visibly flies back.
- [ ] A dead/dying boomerang that keeps sliding away while looking for a landing spot auto-recalls to the player.

**Test in Studio**
- Throw at max distance in open space and toward slopes/edges where it would slide away: it never snaps back, and a sliding dead boomerang returns on its own.

**Notes**
- Branch `agent/T-062-far-boomerang-returns`, lane `Github/Boomerang-lanes/maintenance`.
- Cause: in the dying (Clashed) state, with nothing below to land on, the boomerang keeps its momentum and slides on; at 100 studs from where it started dying, `Clashed.luau` called `removeFromField` (an instant catch = the snap back). Landing inside a collidable part also snaps back (unchanged). Sol (2026-10-03): to discuss later; flying back from inside a part would collide with it, so collision handling needs deciding first.
- Fix: the server now starts an automatic recall (`Boomerang.recallFromClashed`, no hold needed) via a new `ClashedWeaponLogic.onSlidingAway` hook when either: it has slid with nothing to land on for `GlobalConfig.DyingBoomerangNoGroundRecallSeconds` (0.75 s), or it's more than `GlobalConfig.DyingBoomerangMaxSlideDistance` (100 studs) from where it started dying. Clients follow the server's Returning snapshot (same path as `DyingBoomerangCanRecoverInRange`).
- Not lint-checked (no Selene/luau-analyze here). Tune the two GlobalConfig values if it gives up too early or too late.
- Passed Sol's Studio test (2026-10-03).

---

### T-063 · Boomerang doesn't auto-recall without a direct line of sight (it dies)
- **Priority:** P0 (urgent, do today: Sol 2026-10-03)
- **Owner:** Agent
- **Area:** Shared / Server
- **Files:** `Shared/Logics/WeaponLogics/Boomerang.luau` (`autoRecallOrDie`)

**Problem / goal**
If the boomerang has no direct line of sight to the player when it would start returning, it dies instead of auto-recalling. Line of sight shouldn't decide this: it should auto-recall (the recall already slides along obstructions).

**Done when**
- [ ] Within recall range but behind a wall/obstacle, the boomerang still auto-recalls.

**Test in Studio**
- Throw so it ends up around a corner or behind a pillar within range: it returns instead of dying.

**Notes**
- Sol (2026-10-03): the rule is range **and** line of sight: auto-return only if within `BoomerangRecallRange` and nothing solid is between the boomerang and the player; otherwise it dies (drops). Blockers: anything the boomerang collides with; characters ignored.
- Branch `agent/T-063-recall-line-of-sight` (stacked on `agent/T-065-tune-attribute-name`), lane `Github/Boomerang-lanes/maintenance`.
- `Boomerang.autoRecallOrDie` now also needs `hasLineOfSightToPlayer` (a ray from the boomerang to the player's root using the projectile obstruction rules). Server and client both check; the server still decides death.
- Sol (2026-10-03): `DyingBoomerangCanRecoverInRange` turned **on**, and it now needs line of sight too (`Clashed.luau`, same ray rule). A dying boomerang that comes back within range and in view of its player (including one that dropped because a wall blocked the view) flies back on its own. Test: throw so it drops behind a wall within range, then step into view while it's still sliding: it should return. Once fully dead (stopped), it stays dead.
- Not lint-checked.
- Likely related to T-064 and T-062: check them together.
- Passed Sol's Studio test (2026-10-03).

---

### T-065 · `tune RecallAcceleration 5` errors
- **Priority:** P0 (urgent, do today: Sol 2026-10-03)
- **Owner:** Agent
- **Area:** Server / Shared / Tooling
- **Files:** `Server/Cmdr/Commands/` (`tuneboomerang`), `Shared/Library/BoomerangTuningLibrary`, `Shared/Logics/WeaponLogics/Boomerang.luau` (follow-up to T-054)

**Problem / goal**
Running `tune RecallAcceleration 5` throws an error. Find and fix it.

**Done when**
- [ ] `tune RecallAcceleration 5` sets the value without errors and it takes effect on the next/current recall.

**Test in Studio**
- `tune RecallAcceleration 5`, throw and recall (manual and auto): no errors on server or client output.

**Notes**
- Branch `agent/T-065-tune-attribute-name` (stacked on `agent/T-066-T-067-tune-charge-aimwalk`), lane `Github/Boomerang-lanes/maintenance`.
- Cause (client's server console): `Attribute name exceeds 50 character limit ("BoomerangTuning_ClassicBoomerang_RecallAcceleration")`, 51 characters. Every setting on every tool was fine except that one (Shuriken/Fan names are shorter).
- Fix: attribute prefix shortened to `BT` (`BT_ClassicBoomerang_RecallAcceleration`, 38), plus an assert with a clear message if a future name goes over 50.
- Not lint-checked.
- Passed Sol's Studio test (2026-10-03).

---

### T-066 · Cmdr command: tune how fast a charge reaches max power
- **Priority:** P0 (urgent, do today: Sol 2026-10-03)
- **Owner:** Agent
- **Area:** Server / Shared / Tooling
- **Files:** `Server/Cmdr/Commands/`, `Shared/Library/BoomerangTuningLibrary`, `Shared/Constants/GlobalConfig.luau` (`AimFullStrength`?), `Client/Core/WeaponController.luau`

**Problem / goal**
Add a tuning command for the speed at which a throw charge becomes max powered. Follow the T-054 pattern (a new `boomerangsetting` value for `tune` / `resetboomerang`, replicated, session-only).

**Decisions**
- Per tool, like the other `tune` settings; value in seconds to full charge (Sol, 2026-10-03).

**Done when**
- [ ] The charge-up time can be set, shown and reset from Cmdr and takes effect for every player.

**Test in Studio**
- Change the value, hold to charge on two clients: max power is reached faster/slower as set.

**Notes**
- Branch `agent/T-066-T-067-tune-charge-aimwalk`, lane `Github/Boomerang-lanes/maintenance`.
- New `tune` setting `ChargeTime` (default `GlobalConfig.AimFullStrength`, 2 s). The server uses it for the throw's power (`WeaponService` throw handler, per the thrown tool); the client uses it for the aim arrow's fill/shake. The arrow's length is unchanged. `resetboomerang ChargeTime` resets it.
- Other players' aim arrows use `GlobalConfig.ForceEquippedTool`'s value (the client doesn't know their tool); fine while everyone uses the forced tool.
- Not lint-checked.
- Passed Sol's Studio test (2026-10-03).

---

### T-067 · Cmdr command: tune the player's move speed while "standing still"
- **Priority:** P0 (urgent, do today: Sol 2026-10-03)
- **Owner:** Agent
- **Area:** Server / Shared / Tooling
- **Files:** `Server/Cmdr/Commands/`, `Shared/Constants/GlobalConfig.luau` (`AimingWalkSpeed`?), `Client/Core/WeaponController.luau`, `Server/Core/WeaponService.luau`

**Problem / goal**
Add a tuning command for the speed the player moves when they are "standing still" (Sol's wording). Same pattern as T-054: session-only, replicated, show/reset.

**Decisions**
- "Standing still" = the slowed walk while aiming/charging (`GlobalConfig.AimingWalkSpeed`) (Sol, 2026-10-03).

**Done when**
- [ ] The value can be set, shown and reset from Cmdr and takes effect for every player.

**Test in Studio**
- Change the value and aim/charge while moving: the player moves at the new speed.

**Notes**
- Branch `agent/T-066-T-067-tune-charge-aimwalk`, lane `Github/Boomerang-lanes/maintenance`.
- New `tune` setting `AimWalkSpeed` (studs/s, default `GlobalConfig.AimingWalkSpeed` = 4.8). Per held weapon like the other `tune` settings (say if it should be one value for all weapons). Used by the server's walk-speed tween on aim start and by the client's local walk speed. Applies from the next aim.
- Not lint-checked.
- Passed Sol's Studio test (2026-10-03).

---

### T-058 · Put the Group Rewards chest in the lobby
- **Priority:** P1
- **Owner:** Agent
- **Area:** Build (Studio)
- **Files:** Studio: `workspace.Lobby` (place-only, not in the repo)

**Problem / goal**
The Group Rewards back-end is done (T-045: `GroupRewardService` + `GroupMembershipService`), but there's no chest in the lobby, so players can't use it. Place a physical Group Rewards chest in the lobby as a lobby station (see `docs/LOBBY_STATIONS.md`): a chest model on a glowing pad with a "GROUP REWARDS" title, per `docs/LOBBY_SPEC.md` (social/reward zone, visually prominent).

**Done when**
- [ ] A chest Model under `workspace.Lobby`, tagged `LobbyStation`, with `StationId = "GroupRewards"`, `Title = "GROUP REWARDS"`, and a child part named `Pad` (glowing ring) under it.
- [ ] Prompt, title and pad sit sensibly on the model (set `PromptPart` / `TitleHeight` / `MaxDistance` attributes if the defaults don't fit).
- [ ] `workspace.Lobby.TestLobbyStation` (T-047 test object) is removed if it's still there.

**Test in Studio**
- Walk up to the chest: title, glowing pad, "Claim" prompt (or "Join group" with `simulategroupmember me nonmember`).
- Claim: popup, Currency added, prompt hides, pad dims. `resetgroupreward me` makes it claimable again.

**Notes**
- Agents: only edit the place through the Studio MCP when asked; never save or publish it (Sol does).
- Sol (2026-10-02): use a placeholder model; the real model is T-061.
- Done in "Boomerang [Development]" via the Studio MCP (not saved; **Sol saves the place**): `workspace.Lobby.GroupRewardsChest`, a placeholder wooden chest (Base, Lid, gold bands, Lock) on a purple neon `Pad` ring, facing the spawn, where the T-047 test station was (about 30 studs from spawn). Attributes: `StationId = "GroupRewards"`, `Title = "GROUP REWARDS"`, `MaxDistance = 12`. `TestLobbyStation` removed. Move it if you'd like it elsewhere: the station follows the model.
- Passed Sol's Studio test (2026-10-03).

---

### T-057 · OptOut player state + Cmdr command
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server / Rounds
- **Files:** `Server/Core/PlayerSessionService.luau` (new), `Server/Core/SpawnService.luau`, `Server/Cmdr/Commands/OptOut.luau` + `OptOutServer.luau` (new)

**Problem / goal**
Server-only, non-replicated per-session `OptOut` state: the player doesn't take part in rounds and isn't added when a round starts. Cmdr `optout [bool]` toggles it on the sender (no value = true).

**Done when**
- [ ] `optout` / `optout true` keeps you out of the next round; `optout false` lets you back in.

**Test in Studio**
- Two players (local server). Player A runs `optout`; when the next round starts, A stays in the lobby and B plays.
- Try a respawn / late-join gamemode: A still doesn't spawn in.
- `optout false`, then the next round includes A.

**Notes**
- New `PlayerSessionService` holds per-session server-only data (cleared on leave). Starts false on join. Fires `OptOutChangedTasks`.
- `SpawnService`: opted-out players are skipped when the round starts and `canSpawnIntoRound` returns false for them.
- Turning it on mid-round doesn't remove the player now; they just can't respawn. Still counted in voting and `PlayersRequiredToStart` (open questions for Sol). Gamemode logic that loops `Players:GetPlayers()` (e.g. team setup) wasn't changed.
- Passed Sol's Studio test (2026-10-03).

---

### T-048 · Track more player stats
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server / Data
- **Files:** `Shared/Data/ProfileTemplate.luau`, `Server/Core/PlayerStatService.luau` (or a new `StatsService`), `CombatLibrary`, `AbilityService`, `PickupService`, `RoundCyclingService`

**Problem / goal**
Save these lifetime stats in the profile (only Eliminations exists today):
- times each ability was used (e.g. Stab, Dash) and each pickup was acquired (e.g. FireBoomerang): per id
- time played
- rounds played (only rounds the player was in from start to finish)
- rounds won
- eliminations (already tracked as `Elims`)
- **defeats** (deaths). Never use the word "kill" in stat names or player-facing text (see CLAUDE.md).
Use `EconomyService`-style owner functions so other code doesn't write these fields directly.

**Decisions (Sol, 2026-10-01)**
- `Losses` is not tracked (stays in the profile, unused). Track **Defeats** instead: eliminated by another player.
- Team wins count for every member of the winning team; ties count for nobody.
- Saved only for now; T-032 (leaderboards) will display them.

**Done when**
- [ ] New fields in `ProfileTemplate` (type + `get()`), filled by `Reconcile` for existing profiles.
- [ ] Each stat increments in exactly one place; time played is saved on leave/autosave.
- [ ] A Cmdr command shows a player's stats (for testing).

**Notes**
- New `Server/Core/LifetimeStatsService.luau` owns all lifetime stats; nothing else writes them. The `Elims` increment moved there from `CombatService`.
- New profile fields (filled by `Reconcile`): `Defeats`, `RoundsPlayed`, `TimePlayed` (seconds), `AbilityUses` and `PickupsAcquired` (id -> count). `Wins` existed but was never written; it's tracked now.
- Elims/Defeats: from `CombatLibrary.PlayerKilledPlayerTasks`, so environment deaths with no attacker don't count as defeats.
- Rounds played: players in the server when the round started and still there when it finishes. Late joiners (e.g. Assassin) don't get it, but can still get a win.
- Pickups: only real pickups in the world, via a new `PickupService.PickupAcquiredTasks`. Cmdr/chat grants don't count. Abilities: every successful use (`SharedTasks.PlayerUsedAbility`).
- Time played: added to the profile every 60 s, plus on leave through a new `PlayerDataService.ProfileRemovingTasks` that runs before the session ends (the existing `ProfileRemovedTasks` runs after, when writes are no longer saved).
- Cmdr: `showstats <player>` (alias `stats`).
- Test in Studio: play a few rounds (FFA and team), eliminate and get eliminated, dash/stab, grab pickups, then `showstats`. Rejoin and check the values survived, including time played.
- Passed Sol's Studio test (2026-10-03).

---

### T-009 · Daily rewards: grant item rewards and notify the player
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server / Client / GUI
- **Files:** `Server/Core/DailyRewardsService.luau`, `Shared/Referential/DailyRewards.luau`, `Client/UI/Gui/DailyClaims/`, `Client/UI/Gui/ItemAcquired/`

**Problem / goal**
Claiming a login reward must grant it and tell the player.
- Item rewards: `DailyRewardsService` still has `-- TODO: grant player the item`. Grant them with `ItemService.grantItem` (T-006).
- Notification: show the reward on the client with the ItemAcquired popup (items) and a currency popup/message (currency). Use the existing ItemAcquired GUI; final visuals are Sol's (T-021).
- `DailyRewards` points at the `ExampleItem` placeholders; keep them and mark them `-- TODO:RELEASE placeholder` if they aren't already.

**Done when**
- [x] Item rewards are added to the Inventory; currency rewards keep working.
- [x] The player sees a notification for every claimed reward (item and currency).

**Test in Studio**
- Claim on day 1 (item) and day 2 (currency) (use Cmdr or reset `LastClaim` in Studio data): each grant shows a popup and is saved.

**Notes**
- Server: `DailyRewardsService` grants the reward first (`ItemService.grantItem` / `EconomyService.addCurrency`) and only then advances the streak, so a misconfigured reward doesn't use up the claim. The remote now returns `true, claimedDay`.
- Client: item rewards show the ItemAcquired popup through ShopController's existing Inventory listener; currency rewards show "Daily reward claimed! +N Currency" from `DailyClaims`.
- `TODO:RELEASE placeholder` added to the 4 `ExampleItem`/`ExampleWeapon` rewards in `DailyRewards.luau`.
- Play-tested in Studio: day-1 claim granted ExampleItem1 once and returned day 1; a second claim the same day was refused; the popup GUI was enabled; no client/server errors from these modules. The day-2 currency claim wasn't exercised (needs a day to pass or a reset of `LastClaim`).
- Cmdr `resetdaily <players> [resetStreak]` (alias `resetdailyclaim`): makes the next claim available now, as if a day had passed (streak kept). `resetdaily me true` also resets the streak to day 1. Backed by `DailyRewardsService.makeClaimable` / `getNextDay`. Reopen the Daily Claims GUI after running it to see the change.
- Test in Studio: claim (day 1 item) → `resetdaily me` → claim again (day 2 currency popup) → rejoin and check both saved.
- Passed Sol's Studio test (2026-10-03).

---

### T-064 · After more than 3 bounces it won't auto-recall, even with line of sight and in range
- **Priority:** P0 (urgent, do today: Sol 2026-10-03)
- **Owner:** Agent
- **Area:** Shared / Server
- **Files:** `Shared/Logics/WeaponLogics/Boomerang.luau` (bounce count / `energy`, `autoRecallOrDie`)

**Problem / goal**
If the boomerang bounces more than 3 times, it doesn't auto-recall, even though it has a direct line of sight and is within the recall radius. It should auto-recall.

**Done when**
- [ ] A boomerang that has bounced 4+ times auto-recalls when in range with line of sight.

**Test in Studio**
- Throw in a small enclosed space so it bounces 4+ times near you: it returns.

**Notes**
- Dismissed by Sol (2026-10-03): the last bounce already starts the return (max 3 bounces per tool), so this works as intended.

---

### T-056 · Electric + Explosive: explosion eliminations start electric chains
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Logics/PickupLogics/ElectricBoomerang.luau`, `Shared/Logics/PickupLogics/ExplosiveBoomerang.luau`

**Problem / goal**
Phase 3 of T-029 (Sol's decision, 2026-10-02): with both Electric and Explosive active, every player eliminated by the explosion also starts an electric chain from them, exactly like a thrown Electric boomerang elimination (credited to the thrower, thrower and teammates exempt, arcs and radius visual).
- Explosion eliminations currently reach `PlayerKilledPlayerTasks` with weapon id `"ExplosiveBoomerang"`, which the chain listener ignores.

**Done when**
- [ ] Electric + Explosive explosion eliminations start chains; Explosive alone doesn't.
- [ ] Explosions never eliminate the thrower's teammates.

**Test in Studio**
- `getpickup` Electric and Explosive, explode next to one player in a group: the explosion victims each chain to enemies within `GlobalConfig.ElectricChainRadius`.
- TeamClassic/TeamElimination: an explosion next to a teammate doesn't eliminate them.

**Notes**
- Depends on T-029.
- The chain listener in `ElectricBoomerang.luau` now also starts a chain when the weapon id is `"ExplosiveBoomerang"` and the killer has Electric active. Everything else (credit, exemptions, arcs, radius visual) is the same path as a thrown hit.
- Sol: explosions now spare teammates too (`ExplosiveBoomerang` skips non-enemies via `GameTeamLibrary.areEnemies`), with or without Electric.
- Not lint-checked.
- Passed Sol's Studio test (2026-10-02).

---

### T-054 · Cmdr commands for boomerang tuning
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Server / Shared / Tooling
- **Files:** `Server/Cmdr/Commands/` (new definition + `<Name>Server` pairs); values in `Shared/Constants/Tools.luau` (`Speed`, `ThrowDistance`) and `Shared/Constants/GlobalConfig.luau` (`ManualRecallSpeedMultiplier`, `ManualRecallMomentumMultiplier`); used by `Shared/Logics/WeaponLogics/Boomerang.luau`

**Problem / goal**
Let Sol tune boomerang feel live in a server, without editing code. Add Cmdr commands (group `DevTesting`, so they show under "Boomerang commands" in `help`) to set:
- **Maximum throw speed** (`Speed` in Tools)
- **Maximum throw distance** (`ThrowDistance` in Tools)
- **Maximum manual recall speed** (currently `ManualRecallSpeedMultiplier` × max speed)
- **Manual recall pickup speed**: how quickly a manually recalling boomerang reaches its max speed (currently `ManualRecallMomentumMultiplier`)

Boomerang logic runs on both the server and the client, so a changed value must reach every client too (e.g. replicated attributes), or the client's prediction won't match the server. Changes last for the server session only (not saved). Running a command with no value should print the current value, and there should be a way to reset to the defaults.

**Decisions**
- Per tool: a command changes the weapon the caller is currently holding (Sol, 2026-10-02).
- Units: ThrowSpeed, ThrowDistance and RecallSpeed are absolute (studs/s, studs, studs/s); RecallAcceleration stays a multiplier (1 = normal recall). RecallSpeed is its own per-tool value, `ManualRecallSpeed` in Tools (Sol, 2026-10-02), replacing `GlobalConfig.ManualRecallSpeedMultiplier`; defaults equal each tool's Speed, so nothing changes in play.

**Done when**
- [x] The four values can be set, shown and reset from Cmdr, and take effect on the next throw/recall for every player.

**Test in Studio**
- Local server with 2 players: change each value, throw/recall on both clients, and check the boomerang matches on both.

**Notes**
- New `Shared/Library/BoomerangTuningLibrary`: per-tool overrides stored as `ReplicatedStorage` attributes (`BoomerangTuning_<ToolId>_<Setting>`), so they replicate; falls back to Tools/GlobalConfig. `Boomerang.luau` reads it for throw speed/distance and manual recall speed/acceleration.
- Cmdr: `tuneboomerang [setting] [value]` (alias `tune`; no args = show all, no value = show one) and `resetboomerang [setting]` (no setting = reset all). New type `boomerangsetting` (ThrowSpeed, ThrowDistance, RecallSpeed, RecallAcceleration). Values must be > 0.
- Added `WeaponService.getEquippedToolId(player)`.
- Live update (Sol's follow-up): values are re-read every frame, so a boomerang already in flight picks up changes. A changed ThrowSpeed eases toward the new value (same rate as the aim-bonus fade); ThrowDistance applies immediately; recall speed/acceleration apply mid-recall. Test: `tune ThrowSpeed 1`, throw, `tune ThrowSpeed 80` → it should speed back up to 80 (check on both clients).
- Not lint-checked (no Selene/luau-analyze here). Test as below, plus `tune` with no weapon held.
- Passed Sol's Studio test (2026-10-02).

---

### T-055 · Topbar buttons (first one: Daily rewards)
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client / GUI
- **Files:** `Client/UI/Gui/Topbar/init.luau` (new), `Client/UI/Gui/DailyClaims/init.luau`

**Problem / goal**
Buttons in the top bar, lined up with Roblox's default topbar buttons (player list, chat). Each button is placed on the left or the right, has a short text and an optional icon, and is as wide as its text needs. Every button uses the same text size. First button: "Daily" with a gift emoji, which opens/closes the Daily Rewards menu.

**Done when**
- [x] A reusable `TopbarGui.addButton({ Id, Text, Icon?, Side, Order?, onActivated })` that any feature can call.
- [x] The "Daily" button toggles the Daily Rewards menu.

**Test in Studio**
- PC and mobile emulator (a few screen sizes): the Daily button sits in the top bar next to Roblox's buttons, same height and vertical position, text fully visible, and it opens and closes Daily Rewards.
- Open/close the chat and the player list: our button never overlaps Roblox's buttons.

**Notes**
- `Client/UI/Gui/Topbar` is code-built (no `.rbxmx`). Its ScreenGui uses `ScreenInsets = TopbarSafeInsets`, so Roblox keeps it inside the free part of the top bar: left buttons start after Roblox's left buttons, right buttons end before Roblox's right buttons. Buttons are 44 px tall, 12 px from the top (Roblox's own size), and shrink if the top bar is shorter.
- Style: a dark, slightly see-through pill like Roblox's buttons, white FredokaOne text at size 20 for every button, width from `AutomaticSize`. All values are constants at the top of the module (swap in Sol's assets later if wanted).
- `Icon` is an emoji/text glyph, or an image id (`rbxassetid://...`).
- **Emoji:** used 🎁 (gift). There's no "gift basket" emoji; if you meant the basket (🧺), it's a one-character change in `DailyClaims/init.luau`.
- DailyClaims registers its own button in `start()`. The Studio-only `Y` key toggle is still there.
- Like HudButtons, the top bar isn't flagged `RequiresMouse`, so on PC it can't be clicked while the over-the-shoulder camera locks the mouse during a round (Roblox's own buttons behave the same). Fine in the lobby.
- Replaces T-050 (closed by Sol, 2026-10-02).
- Not syntax-checked: no Luau checker is installed on this machine.
- Passed Sol's Studio test (2026-10-02).

---

### T-026 · Menus can lock the screen in the over-the-shoulder camera
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client / GUI
- **Files:** `Client/UI/UIController.luau`, `Client/Core/CustomCameraController.luau`, `Client/UI/Gui/*`

**Problem / goal**
In the in-game over-the-shoulder camera the mouse is locked/hidden, so a clickable GUI that appears during a round (e.g. Shop, Daily Claims, Voting, ItemAcquired with buttons) can't be clicked or closed, and the player is stuck. Audit every GUI that can open during a round and make sure the mouse is freed while it's open (e.g. a `Modal` button or `UserInputService.MouseBehavior`/`MouseIconEnabled` handled centrally in `UIController` for menu-type GUIs), and restored when it closes.

**Done when**
- [x] Opening any menu-type GUI while in the arena camera frees the mouse; closing the last one restores the camera's mouse lock.
- [x] GUIs that shouldn't open during a round are listed in Notes (ask Sol whether to block them).

**Test in Studio**
- During a round, open each menu (shop, daily claims, settings...) with keyboard/HUD buttons and close it with the mouse.
- Repeat on gamepad and on a mobile emulator.

**Notes**
- New `Client/Core/MouseUnlockController`: every frame, if any open gui has `RequiresMouse = true` (`UIController.isMouseRequired()`), it shows an invisible `Modal` button (Roblox's standard way to free a locked mouse) and keeps the cursor visible. When the last one closes, it hides the button and re-hides the cursor if the camera is in the arena's Regular (over-the-shoulder) mode.
- Flagged `RequiresMouse = true`: Shop, DailyClaims, Voting (the guis with clickable buttons that open as menus).
- Not flagged: HudButtons and CustomTouchscreen (always on screen, so flagging them would never re-lock the mouse), and the notification-style HUDs (no buttons). If HudButtons should be clickable in the over-the-shoulder camera, that needs a separate decision (e.g. holding a key to free the mouse).
- No gui is blocked from opening during a round; ask Sol if any should be.
- Syntax-checked with `luau-compile`; not play-tested (Sol declined the Studio play-test).
- PC (keyboard/mouse) passed Sol's Studio test (2026-10-02). Gamepad and mobile checks still to do (low priority).
- Passed Sol's Studio test (2026-10-02).

---

### T-023 · Assassin: let players join mid-round
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared / Server
- **Files:** `Shared/Constants/Gamemodes.luau`, `Shared/Logics/GamemodeLogics/Assassin.luau`, `Server/Core/RoundCyclingService.luau`, `Server/Core/SpawnService.luau`

**Problem / goal**
New players should be able to join an Assassin round in progress. They're immediately given a target, and are added to the loop that fairly assigns assassins and targets for the rest of the round.
- `Gamemodes.Assassin` currently has `LateJoinEnabled = false`.
- `Assassin.luau` already subscribes `addMember` to `GameStateLibrary.PlayerAddedToArenaTasks`, which assigns the newcomer a target and fills in targetless members. Check that this path is complete once late join is on (and that it also works for players who rejoin).

**Done when**
- [x] `LateJoinEnabled = true` for Assassin.
- [x] A player joining mid-round spawns into the arena, gets a target at once, and becomes someone's target as soon as fairly possible.
- [x] Nobody is left without a target or hunted by two assassins because of the join.

**Test in Studio**
- Start Assassin with 2 players, then join a 3rd mid-round (Studio local server, 3 players): the newcomer gets a target and the target arrows/GUI update for everyone.
- Leave and rejoin mid-round: no errors, assignments stay consistent.

**Notes**
- `Gamemodes.Assassin.LateJoinEnabled = true`. Late joiners already reach `Assassin.addMember` through the normal spawn path (`SpawnService` → `LivingPlayersInArena` → `PlayerAddedToArenaTasks`).
- New `giveAssassin()` in `Assassin.luau`: a member nobody is hunting (a late joiner, or a respawning player) gets an assassin right away. A hunter whose target already has several assassins is redirected to them; otherwise they're spliced into the ring (a random hunter now hunts them, and they take over that hunter's old target).
- Checked with a simulation harness running the real target functions (200 random runs of joins, deaths/respawns and leaves): with 2+ members, every member always had a target and an assassin. Not play-tested with real players (needs a multi-client Studio test).
- Passed Sol's Studio test (2026-10-02).

---

### T-029 · Electric boomerang rework: chain kills
- **Priority:** P1
- **Owner:** Sol → Agent
- **Area:** Shared
- **Files:** `Shared/Logics/PickupLogics/ElectricBoomerang.luau`, `Shared/Library/CombatLibrary.luau`, `Shared/Assets/Particles/Electric*`

**Problem / goal**
Water now kills (T-028), so electrifying water and "zapping" players no longer make sense. **Remove those concepts entirely** (electrified water state, zapped animation/effect, `PlayZappedAnimation`, the dependency on `Water`).
New behaviour: when an electric boomerang kills a player, every other player within **5 studs** (configurable) of the victim is also killed, with an **electric arc** drawn between the two. The chain continues from each newly killed player to anyone within 5 studs of them. The thrower can never be affected.
- Chain kills should be credited to the thrower and go through the normal kill path (elim messages, scoring).
- **Sol: the chain skips the thrower's teammates** (use `GameTeamLibrary.areEnemies`).

**Sol's decisions (2026-10-02)**
- The chain is guaranteed for every enemy in range (thrower and teammates exempt). No max length; an extremely small delay between links.
- The effect stays active for the pickup's whole duration (no longer ends on use).
- Pickup subtitle: "Electricity shocks players in range".
- Keep the Zapped animation, sound and pickup display entry for later.
- **Phased:** (1) core chain logic, (2) config + arc visuals, (3) Electric + Explosive: eliminations from the explosion also start chains. Phases 2 and 3 wait until phase 1 passes testing.

**Done when**
- [x] The old electric/water/zap code and remotes are gone; nothing else references them.
- [x] Chain kills work as specified.
- [x] Values (radius, delay) in config. *(phase 2)*
- [x] Arcs show on all clients.
- [ ] ~~Electric + Explosive explosion eliminations start chains.~~ Split out to T-056.

**Test in Studio**
- `getpickup` the Electric pickup, group 3–4 test players within 15 studs and eliminate one with a thrown boomerang: the others die in a chain; the thrower and teammates never die; players 16+ studs away survive; a red radius cylinder appears on every electric-eliminated player for 5s.
- Elim feed shows "Shocked" for chained eliminations; they count for the thrower's score.
- Stab eliminations with Electric active should **not** chain (only thrown boomerangs).

**Notes**
- Passed Sol's Studio test (2026-10-02). Phase 3 (Electric + Explosive) moved to T-056.
- Depends on T-028 (water kills).
- Phase 1: `ElectricBoomerang.luau` rewritten. It listens to `CombatLibrary.PlayerKilledPlayerTasks`: a kill by a thrown boomerang (Tools `LogicClass == "Boomerang"`) with the pickup active starts a chain; each link calls `CombatLibrary.attackHitPlayer(thrower, "ElectricChain", ...)`, so shields/immunity/scoring apply and the chain recurses. Radius 15 and link delay 0.05s are in GlobalConfig (`ElectricChainRadius`, `ElectricChainLinkDelay`).
- Debug: `GlobalConfig.VisualizeElectricChainRadius` (currently true) shows a client-only red cylinder (chain radius) for 5s on every electric elimination (boomerang victim and chained victims), via the `VisualizeElectricChainRadius` remote.
- Removed Zapped checks from `CharacterController`, `WeaponLibrary`, `Dash`, `Stab`, and `"Zapped"` from AnimationController's core tracks. Kept `Animations.Zapped`, `Sounds.Zapped`, `AcquirableThingData.Zapped` and the ElectricPlayer/ElectrifiedObject particles.
- New elim type "Shocked" (`CombatService.getElimType`, `ElimMessage` GUI).
- Electric + Explosive currently only plays the ElectricExplosion particle (no zap, no early end).
- Phase 2: arcs drawn on each client (`ElectricChainArc` remote, fired only when a link actually eliminates): jagged beam segments in the electric blue (0,131,255) with a light core and the ElectrifiedObject glow texture (243660373), flickering 3 times over ~0.25s then fading over 0.2s; a burst of the ElectricExplosion particles at the target. Tuning constants (`ARC_*`) at the top of `ElectricBoomerang.luau`. Existing bolt textures are flipbook sheets, so they can't be used on beams.
- Cmdr `zapchain [player]`: eliminates the player (default: you) as if by an Electric boomerang and starts a chain, with arcs and the radius visual. On someone else, you are the thrower (credited, exempt, teammates skipped); on yourself, nobody is credited and everyone in range is hit. Needs an active round; no pickup needed.
- Not lint-checked (no Selene/luau-analyze here).

---

### T-050 · HUD button for Daily Rewards
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** GUI / Client
- **Files:** `Client/UI/Gui/HudButtons/`, `Client/UI/Gui/DailyClaims/`

**Problem / goal**
Add a HUD button that opens the Daily Rewards (DailyClaims) GUI, ideally with an indicator when a reward is claimable. **Sol:** the button asset and placement. **Agent:** wire it to `DailyClaims.toggle()` and the claimable indicator.

**Notes**
- Part of the HUD button set in T-037.
- Closed by Sol (2026-10-02): replaced by the topbar "Daily" button (T-055). The "reward ready" indicator was dropped.

---

### T-015 · Set up Cmdr as the developer console
- **Priority:** P1
- **Owner:** Agent
- **Area:** Server / Client / Tooling
- **Files:** `src/Server/Core/CmdrService.luau`, `src/Client/Core/CmdrController.luau`, `src/Server/Cmdr/Commands/GiveCurrency.luau`, `src/Server/Cmdr/Commands/GiveCurrencyServer.luau`

**Problem / goal**
Sol wants Cmdr (installed through Wally, previously unused) as the in-game command console for developer testing.

**Done when**
- [x] `CmdrService` registers Cmdr's built-in commands and the project's commands in `Server/Cmdr/Commands`.
- [x] A server `BeforeRun` hook only lets admins run commands: everyone in Studio; in live servers the players in `ADMIN_USER_IDS`, the owner of a user-owned game, or group members at or above `MIN_ADMIN_GROUP_RANK`. A matching client hook exists, because Cmdr blocks all commands in live games without one.
- [x] `CmdrController` only loads the console (F2) for players with the server-set `CmdrAdmin` attribute.
- [x] Example command `givecurrency <players> <amount>` (useful for testing the shop).
- [x] CLAUDE.md explains how to add commands.

**Test in Studio**
- Press F2: the console opens. Run `help`, then `givecurrency me 100`, and check the currency updates in the shop.
- Run `kill me` to check a built-in command works.
- After publishing, join a live server with a non-admin account: F2 does nothing.

**Notes**
- Syntax-checked with `luau-compile`; not run in Studio.
- `TODO:RELEASE placeholder` values in `CmdrService`: `ADMIN_USER_IDS` (empty: add the developers' UserIds) and `MIN_ADMIN_GROUP_RANK = 255` (group owner only).
- Cmdr's built-in admin commands (`kick`, `teleport`, `announce`...) are all registered. If some shouldn't be available, `RegisterDefaultCommands` can take a list of groups.
- Passed Sol's Studio test (2026-10-02). The "live server, non-admin: F2 does nothing" step no longer applies: Cmdr is open to everyone for client review until T-052.

---

### T-012 · Agentic setup: design doc, toolchain, package metadata
- **Priority:** P2
- **Owner:** Sol → Agent
- **Area:** Tooling
- **Files:** `docs/GAME_DESIGN.md`, `aftman.toml`, `wally.toml`

**Problem / goal**
Follow-ups to make agents more useful:
- [x] `docs/GAME_DESIGN.md`: transcribed from the client's "Boomerang! Technical Document" PDF (MVP spec), with a table of where the code differs (see T-014). The UI scope-of-work PDF only has a cover page so far.
- [ ] `aftman.toml` only pins Rojo. Add StyLua / Selene / Wally / wally-package-types? Mutatory moved to Rokit; should Boomerang too?
- [ ] `wally.toml` still names the package `larsb/roblox-game-template`.
- [x] Roblox Studio MCP: added to the Claude desktop config (`Roblox_Studio`, via `%LOCALAPPDATA%\Roblox\mcp.bat`); confirmed on 2026-10-01 that an agent can list Studio instances and read the place. Usage rules are in CLAUDE.md.
- [x] Jecs removed (`wally.toml`, `wally.lock`, `Packages/`). Cmdr kept and set up (T-015).

**Done when**
- [ ] Each point is decided, done or dropped, and CLAUDE.md is updated.

**Notes**
- The remaining points need Sol's answers; the task stays in Review until then.
- Accepted by Sol (2026-10-02).

---

### T-007 · Record the leftover / reference modules
- **Priority:** P2
- **Owner:** Agent
- **Area:** Tooling
- **Files:** `CLAUDE.md`

**Problem / goal**
Several files are backups or references. Sol's decision: keep them all as references, and list them so agents don't touch them.

**Done when**
- [x] CLAUDE.md has a "Leftover and reference modules: don't touch" list: `ReferencePlayerModule/`, `src/Animate/`, `Server/Core/Animate.luau`, `Shared/Networking/Animate.luau`, `CharacterService/Old.luau`, `CharacterController/old.luau`, `ItemAcquired/OldTemplate.rbxmx`.

**Notes**
- `Server/Assets/Maps/PackageLink.gltf` was not kept: it was removed as part of T-013.
- `Server/Core/Animate.luau` and `Shared/Networking/Animate.luau` aren't required by any file in the repo. If something in Studio uses them, it isn't visible here.
- Accepted by Sol (2026-10-02).

---

### T-013 · Stop Rojo from overwriting the map package
- **Priority:** P1
- **Owner:** Agent
- **Area:** Tooling
- **Files:** `default.project.json`, `src/Server/Assets/Maps/PackageLink.gltf` (deleted)

**Problem / goal**
The maps moved from Rojo-synced `.rbxmx` files to a Studio package (commit 9fd09d6), but `src/Server/Assets/Maps/` stayed on disk holding only `PackageLink.gltf`, a file type Rojo ignores. Rojo therefore saw `Maps` as an empty folder it owns, and because nodes under a `$path` don't keep unknown instances, it deleted the package contents in Studio on every sync.

**Done when**
- [x] `src/Server/Assets/` is removed from disk.
- [x] `default.project.json` declares `ServerStorage.Server.Assets` as a `Folder` with `$ignoreUnknownInstances: true`, so Rojo creates the folder if missing but never touches its contents.
- [x] CLAUDE.md tells agents never to add files under `src/Server/Assets/`.

**Test in Studio**
- Restore the maps package to the correct version once more, then connect Rojo (or restart `rojo serve`): `ServerStorage.Server.Assets.Maps` and its maps stay unchanged.
- Start a round: `ArenaService` finds the maps as before.

**Notes**
- Checked with Rojo 7.7.0 (`rojo build` on a copy of the project tree): the project file is valid and `Assets` is created as an empty Folder.
- Sol: commit the deleted `PackageLink.gltf` along with `default.project.json`.
- Passed Sol's Studio test (2026-10-02).

---

### T-051 · Touch controls follow the player's current input
- **Priority:** P1
- **Owner:** Agent
- **Area:** Client
- **Files:** `Client/Core/PlatformController.luau`, `Client/UI/Screens/InputScreen.luau`

**Problem / goal**
Players can switch input mid-game. Touching the screen while on keyboard/mouse shows the touchscreen GUI; using keyboard/mouse while on touch hides it.

**Done when**
- [ ] Keyboard/mouse → touch: touchscreen GUI (CustomTouchscreen + mobile buttons) appears.
- [ ] Touch → keyboard/mouse: it disappears.

**Test in Studio**
- Touch-screen laptop (or a phone/tablet with a keyboard/mouse): start on mouse, tap the screen, then move the mouse / press a key. Repeat starting on touch.
- On mobile, typing in chat with the on-screen keyboard must not hide the touch controls.
- Studio's device emulator may not reproduce mixed input well; a real device is the reliable test.

**Notes**
- `PlatformController` is now the single source of truth: `InputScreen` used `PreferredInput` (via `DeviceUtil`) while `CustomTouchscreen` used `PlatformController`, so they could disagree. `InputScreen` now listens to `DominantControlSchemeChanged`. `DeviceUtil` is untouched (now unused).
- Fixes in `PlatformController`: unmapped input types (Focus, TextInput...) no longer flip the scheme to PC (this could hide touch controls on mobile when the window regained focus); mouse buttons/wheel and gamepads 5–8 are now recognised; keyboard input while typing in a TextBox is ignored; the starting scheme uses the last input / `PreferredInput` instead of assuming touch on any touch-capable device (touch laptops started in touch mode).
- Roblox's own thumbstick/jump button (`TouchGui`) is switched by the PlayerModule, not by this code.
- Passed Sol's Studio test (2026-10-02).

---

### T-030 · Make the server-authoritative character invisible
- **Priority:** P2
- **Owner:** Agent
- **Area:** Client
- **Files:** `Client/Core/CharacterRenderController.luau`

**Problem / goal**
Each player has a server-authoritative character (physics/hits) and a client-rendered model. The authoritative character should never be visible. `everyFrame` currently sets it to transparency `0.5` when no rendered model exists (and `1` only during a disguise).

**Done when**
- [ ] The authoritative character is fully invisible (transparency 1) for every player at all times, including before the rendered model loads.
- [x] Hitbox parts keep their current behaviour (they're already skipped).

**Test in Studio**
- Join with 2 players: only the rendered models are visible, including right after spawning and respawning.

**Notes**
- `CharacterRenderController.everyFrame` now keeps the authoritative character fully invisible (transparency 1, including the face decal) while the rendered model exists or is still loading. It was 0.5 before. Hitbox parts are still skipped.
- `GlobalConfig.AuthoritativeCharacterDebugVisible` (default `false`) brings back the 0.5 view for debugging.
- **Fallback (deviation from "invisible at all times", please confirm):** if a player's rendered model **failed to load**, the authoritative character is shown (transparency 0), so the player doesn't become invisible. Controlled by `GlobalConfig.ShowAuthoritativeCharacterOnRenderFailure` (default `true`). This matters right now: the Studio output log is flooded with `recently failed to load replicated model for Soulsplosion`, i.e. rendered models are failing to load in Studio play-tests. That's worth its own investigation.
- Syntax-checked with `luau-compile`; not play-tested.
- Passed Sol's Studio test (2026-10-02).

---

### T-035 · Manual recall to match the design doc
- **Priority:** P1
- **Owner:** Sol → Agent
- **Area:** Client / Server / Shared
- **Files:** `Client/Core/WeaponController.luau`, `Server/Core/WeaponService.luau`, `Shared/Logics/WeaponLogics/Boomerang.luau`, `Client/UI/Gui/HudButtons/`, `Client/UI/Gui/CustomTouchscreen/`

**Client spec (2026-10-01, supersedes the design-doc analysis below):**
- Recall range around the player: `GlobalConfig.BoomerangRecallRange` (30).
- Out of range when it would start returning: no auto-return. It loses momentum and drops into the dead state (as after a clash). Back in range by then: returns as normal (it can leave range, bounce back and still return).
- Once it starts losing momentum it can't resume auto-return, even back in range (`GlobalConfig.DyingBoomerangCanRecoverInRange`, default false).
- Manual recall works on a dying or dead boomerang: it moves toward the player only **while held**; releasing puts it back into the dead state. Tapping on a live boomerang just recalls it. Rapid press/release must be safe.
- **Pass 1 (done, in Review):** out-of-range death via `Boomerang.autoRecallOrDie` (server decides; the client follows the server's Clashed snapshot). **Pass 2 (done, in Review):** recall press/release goes to the server (`WeaponRecall` true/false). Dying/dead boomerang: `Boomerang.recallFromClashed` (returns while held, rises to hand height) and `Boomerang.stopRecallFromDead` on release; clients follow the server's snapshots. HUD Throw/Recall button is press-and-hold in recall mode. `DyingBoomerangCanRecoverInRange` is wired (hook from Boomerang into Clashed). Dead state now waits until the boomerang has landed.

**Problem / goal**
`docs/GAME_DESIGN.md` §2c: **hold** E / the mobile recall button to pull the boomerang back; releasing stops it where it is; it doesn't pass through walls, takes the fastest valid route, and slides along a surface when the shape allows (otherwise it gets stuck and the player must reposition). Today pressing E fires `WeaponRecall` once (a one-shot recall), and `HudButtons` has a "Recall" entry.

**Open questions (ask Sol first)**
- Hold vs. tap: should a tap still start a full recall, or does recall only move while held?
- Recall speed while held (same as auto-recall return speed?).
- When stuck against a wall with no slide, does it stay stuck until the player moves, or eventually give up and drop?
- Does manual recall still kill players it passes through on the way back?
- Mobile: where exactly does the recall button go (the design sketch puts it above Stab, left of Throw)?

**Done when**
- [ ] Recall behaves as described in GAME_DESIGN.md §2c on PC, gamepad and mobile.
- [ ] Server-authoritative: the server moves the boomerang; the client only sends hold start/stop.

**Notes**
**Agent analysis (2026-10-01): design doc vs. current code**

| Design doc (§2b–2c, §5) | Current code | Gap |
|---|---|---|
| Auto-recall after slicing through a player | Passes through players and keeps going; the "recall on hit" code in `Boomerang.throw` is commented out | **Intentional (Sol): keep it off** |
| Auto-recall after one ricochet | After the first bounce, the distance check switches to `ThrowDistance`, which has usually been reached, so it recalls right away | Matches in practice |
| 2+ surface hits: stops where it runs out of energy and waits for manual recall | When `energy` reaches 0 it calls `Boomerang.recall` (auto-returns). The "Exhausted" slow-down branch exists but only runs when recall transitions are off | Differs |
| **Hold** E / button to recall; releasing stops it where it is | E (or the mobile Throw/Recall button) sends one `WeaponRecall` event; the server runs a full recall to the hand. Releasing does nothing | Differs (the main gap) |
| Doesn't pass through walls; slides along a surface if it can, otherwise stuck until the player repositions | `Boomerang.recall` steers toward the player, slides along obstructions (tries both tangents), and holds still if both are blocked, resuming when the player moves | Matches |
| Fastest valid route | Greedy steering + wall sliding (no pathfinding) | Close enough; true pathfinding not recommended |
| Recall kills players on the way back | `damagedPlayer` runs during recall | Matches (doc doesn't say either way) |

**Suggested implementation**
1. **Hold-to-recall (server-authoritative):** `WeaponRecall` carries a boolean (`true` on press, `false` on release). Press: if the boomerang is out and not already returning, `Boomerang.recall(..., { Manual = true })`. Release: new `Boomerang.stopRecall(player, data)` disconnects the recall loop, sets a new `Resting` state (speed 0) and sends a snapshot. Pressing again resumes from there. Release only stops **manual** recalls, never auto-recalls.
2. **Client sync:** `WeaponController.onSnapshot` already starts a local recall when the state changes to `Returning`; add the reverse (`Returning` → `Resting` calls `stopRecall` locally).
3. **Exhaustion:** when `energy` hits 0, switch to `Exhausted` (let the existing slow-down run) and then `Resting`, instead of auto-recalling.
4. **Inputs:** E: `InputBegan` → press, `InputEnded` → release. Mobile/gamepad: a dedicated recall button that uses press/release (`MouseButton1Down` / `MouseButton1Up` + `InputEnded`). Its placement is Sol's call (ignore the game design doc's sketch). The Throw button's "Recall" mode either becomes hold-based too or goes away.
5. Keep the T-027 speed multiplier and the existing kill-on-return behaviour.

Order: (1)+(2) first (they're the core and can ship alone), then (3), then (4)'s mobile button once Sol decides the layout. Add a Cmdr command to put the boomerang in each state for testing (e.g. out of energy / resting).
- Reviewed and accepted by Sol (2026-10-02).

---

### T-034 · Projectiles go through portals
- **Priority:** P2
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Logics/Environment/Portal.luau`, `Shared/Logics/WeaponLogics/Boomerang.luau`, `Shared/Library/DynamicCollisionLibrary.luau`

**Problem / goal**
Portals currently teleport players only. A thrown boomerang (any projectile) should pass through a portal and come out of the linked one, keeping its speed and direction relative to the exit portal.

**Done when**
- [x] A thrown boomerang entering a portal continues from the paired portal with the same relative direction and speed.
- [x] Recall (auto and manual) still finds its way back, through the portal or by its normal path; describe which in Notes.
- [x] Clients and server agree on the boomerang's position after it passes through (no visible snapping beyond normal replication).

**Test in Studio**
- On a map with portals: throw through a portal and hit a player on the other side; recall it.

**Notes**
- New `Portal.getProjectileExit(origin, direction, distance, radius, lastExitAt?, lastExitPart?)`. Portal pairs are read from the current arena's `Functional` folder (attribute `ClassName = "Portal"`, the same layout `Portal.validate` expects), so the server and clients find the same portals without extra replication.
- `Boomerang.throw`'s step checks it before hits and obstructions. On entry, the boomerang jumps to the paired portal's Attachment (keeping its height) with its direction mapped through the pair: relative to the entry attachment, turned around, then relative to the exit attachment. If that would point back into the exit portal, it goes straight out along the exit attachment's facing. Speed and remaining throw distance are unchanged. A 0.25 s cooldown stops it from re-entering the portal it just left.
- **Convention it relies on:** each portal's Attachment faces *out* of its portal. This is also the direction players face after teleporting.
- Recall: returning boomerangs do not use portals. They take their normal path back to the player (with collision).
- No map in the place currently has a portal, so it couldn't be tried in a level. The math was tested in Studio with in-memory parts (never added to the place): head-on and angled entries, misses, short steps, the re-entry cooldown, and both directions through the pair.
- Syntax-checked with `luau-compile`; not play-tested.
- Passed Sol's Studio test (2026-10-02).

---

### T-028 · Water kills the player, with a splash
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Logics/Environment/Water.luau`, `Shared/Library/CombatLibrary.luau`, `Shared/Library/ParticlesLibrary.luau`, `Shared/Assets/Particles/`

**Problem / goal**
Stepping into water kills the player. A splash effect plays on the player and they fall through the water, so it reads as falling in and dying.
- Use the normal death path (`CombatLibrary` / death reason) so death screens, elim messages and gamemode scoring behave like other environmental deaths (see `DeadlyPart`).
- If there's no splash particle yet, add a placeholder entry and mark it `-- TODO:RELEASE placeholder`.

**Done when**
- [ ] Touching water kills the player once, with a splash effect and the character sinking through the water.
- [ ] The death counts the same way as other environment deaths (death screen shows a non-player cause).

**Test in Studio**
- Walk into water in each map that has it: splash, sink, death screen, respawn where the gamemode allows.

**Notes**
- Water parts are made non-collidable (`CanCollide = false` in `Water.onObjectAdded`), so players always fall through water. `Touched` / `GetTouchingParts` still work (the part has a Touched connection), so the fire/electric `PlayerEnteredWater` effects are unchanged.
- Server-side in `Water.luau` (`Water.init` starts a Heartbeat check): a player drowns once the centre of their body (`HumanoidRootPart`) is inside a water part: within its footprint and below its top surface (down to `MAX_ROOT_DEPTH_BELOW_BOTTOM` = 10 studs under its bottom, to catch fast falls). Feet in the water or standing on the edge is safe.
- Death through the normal path: `Humanoid.Health = 0` + `CombatLibrary.notifyDeathReason` with "Drowned" (setting Health directly also kills through the spawn ForceField). Once per life (`Drowned` attribute). A splash plays on the surface.
- Removed from the previous iteration: the `SinkingPlayers` collision group, the ragdoll change in `CharacterRenderController` and `Dash.isDashing` (no longer needed now water never collides).
- **`TODO:RELEASE placeholder`:** `Shared/Assets/Particles/Splash.rbxmx`, a basic hand-written droplet burst.
- The footprint uses the part's box, so non-box water (MeshPart, wedge, cylinder) counts by its bounding box. Water kills in every phase, lobby included.
- Check in Studio: walk off the edge into water (fall in, splash, death screen "Drowned"); stand with toes over the edge (safe); dash across a gap (safe if you land before your centre drops into the water); die with the spawn shield up.
- Passed Sol's Studio test (2026-10-02).

---

### T-027 · Explosive boomerang: lasts the whole effect and returns 50% faster
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Logics/PickupLogics/ExplosiveBoomerang.luau`, `Shared/Logics/WeaponLogics/Boomerang.luau`

**Problem / goal**
The explosive boomerang currently only explodes once. The effect should stay active after the first explosion (every throw explodes until the pickup effect ends), and while it's active the boomerang returns to the player's hand **50% faster** than now.
- The module is still marked `-- STUD` / `-- TODO`; check what's implemented before changing it.

**Done when**
- [x] Every throw explodes while the effect is active; the effect ends on its normal timer/conditions.
- [x] Return speed while the effect is active is 1.5x the normal return speed, set from a config value, not hard-coded.
- [x] The `-- STUD` / `-- TODO` header is removed if the pickup is now complete, and `Disabled` is removed if set.

**Test in Studio**
- `getpickup ExplosiveBoomerang` (chat) or the Cmdr equivalent: throw several times, each throw explodes; the boomerang comes back visibly faster.

**Notes**
- The effect no longer ends after the first explosion: every throw explodes (at the end of the throw, or on its first kill, once per throw) until the effect times out (`GlobalConfig.GenericEffectTimeout`, 15 s).
- **"Returns 50% faster", two parts (please confirm this matches the client):**
  - After an explosion the boomerang doesn't fly back: it's removed and the weapon is locked, then reappears in hand. That lock is now 3 s / 1.5 = **2 s** (was 3 s).
  - A boomerang that does fly back while the effect is active (e.g. manually recalled before the end of the throw) returns at **1.5x** speed (`Boomerang.recall` checks `PickupLibrary.hasPickupEffectActive`, which is replicated, so client prediction matches).
  - One config value drives both: `GlobalConfig.ExplosiveBoomerangReturnSpeedMultiplier = 1.5`.
- Picking the pickup up again while it's active refreshes its subscriptions instead of doubling them. Removed the `-- STUD` / `-- TODO` header (no `Disabled` flag was set).
- Syntax-checked with `luau-compile`; not play-tested.
- Passed Sol's Studio test (2026-10-02).

---

### T-031 · Allow jumping in the lobby (instead of dash)
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server / Client
- **Files:** `Server/Core/CharacterService/init.luau`, `Shared/Logics/AbilityLogics/Dash.luau`, `Client/Core/AbilityController.luau`, `Server/Core/LobbyService.luau`, `Server/Core/SpawnService.luau`

**Problem / goal**
In the lobby, players can jump and can't dash. In the arena it's the reverse (current behaviour). `CharacterService` currently disables jumping for every character (`SetStateEnabled(Jumping, false)`, `JumpHeight = 0`).

**Done when**
- [x] Jumping is enabled while the player is in the lobby and disabled when they're sent to the arena (and re-enabled when they return).
- [x] Dash can't be used in the lobby. The jump input (Space / mobile jump) jumps in the lobby and dashes in the arena.
- [x] Jump height comes from config.

**Test in Studio**
- In the lobby: Space jumps, no dash. Enter a round: Space dashes, no jump. Return to the lobby: jumping works again. Repeat on mobile.

**Notes**
- New `Shared/Library/LobbyLibrary.isCharacterInLobby(character)` (the lobby-volume check `LobbyController` already used), so both sides can check.
- Jumping: `LobbyController` sets the local humanoid's `JumpHeight` to `GlobalConfig.LobbyJumpHeight` (7.2) and enables the Jumping state while in the lobby, and sets them back to 0/disabled in the arena. This is done on the client because the client simulates its own character; the server still disables jumping at spawn (`CharacterService`).
- Dash: `Dash.canActivate` returns false in the lobby (checked on the client and on the server).
- Input: new `AbilityController.useMovementInput()`: jumps in the lobby, dashes in the arena. Space and the mobile Dash buttons (`CustomTouchscreen`, `HudButtons`) now call it.
- Syntax-checked with `luau-compile`; not play-tested. Check that Roblox's default jump button/keys (if the default control scripts are active in the place) behave the same.
- Passed Sol's Studio test (2026-10-02).

---

### T-006 · Port the template-era economy/item modules to the current save format
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server / Client / Data
- **Files:** `Server/Core/EconomyService.luau`, `Server/Core/ItemService.luau`, `Client/Core/EconomyController.luau`, `Client/Core/ItemController.luau`, `Shared/Constants/ItemConstants.luau`, `Shared/Constants/EquipmentConstants.luau`, `Shared/Constants/EconomyConstants.luau`, `Shared/Utils/EconomyUtil.luau`

**Problem / goal**
These came from the game template and use profile fields that don't exist in `ProfileTemplate` (`Currencies`, `ItemInventory`). They're auto-loaded: `ItemService` writes an `ItemInventory` field into every profile on load, and `EconomyService.transact` would error if called. **Sol's decisions:**
- Update them to the current save format (`Currency`, `Inventory` in `ProfileTemplate`; item data in `Shared/Referential/Items.luau` / `ShopItems.luau`).
- **There is only one currency: `Profile.Currency`, a number.** Remove every multi-currency mention (`Currencies`, `Cash`, `Gems`, `liquidCurrencies`, `{ [Currency]: number }` types...). Prices are a plain number (as in `Items`).

**Done when**
- [x] No auto-loaded module reads or writes profile fields that aren't in `ProfileTemplate`.
- [x] No code mentions more than one currency.
- [x] `ItemConstants` either reads from `Items` or is no longer used, so there's one item list.
- [ ] Existing shop purchases still work.

**Test in Studio**
- Join, buy a shop item with currency: the balance and inventory update and replicate to the client.
- Rejoin: the purchase was saved. No errors from Economy/Item modules on load.

**Notes**
- Committed in 33a8428 ("Normalized handling of saved player currency values...").
- `EconomyService`: `getBalance`, `canAfford`, `addCurrency`, `spendCurrency`, `CurrencyChangedTasks`. `EconomyController`: `getBalance`, `canAfford`, `CurrencyChangedTasks`. `EconomyUtil.getPriceDisplayString(price: number)`.
- `ItemService`: `getAmount`, `hasItem`, `grantItem`, `consumeItem`, `purchaseItem` (returns a ResponseCode), `getInventory`, all on `Profile.Inventory` with item data from `Items`. `ItemController` reads `Inventory` from `PlayerDataController` and fires `ItemGrantedTasks` / `ItemConsumedTasks`.
- Removed: `EconomyConstants`, `ItemConstants`, `EquipmentConstants`, `RemoteCodes.Item` and the `"Item"` remotes (nothing else used them). `PlayerDataService` no longer lists the stale `BanData` field.
- `ProductLogicsUtil.grantGenericItemToPlayer`, `DailyRewardsService` (currency rewards) and the Cmdr `givecurrency` command now go through `ItemService` / `EconomyService`. `grantGenericItemToPlayer` now refuses item ids that aren't in `Items`.
- Decisions made without asking (say if you want them changed): `ShopService.purchaseItem` was left as is so the tested shop flow doesn't change. It duplicates `ItemService.purchaseItem`; making it delegate is a one-line follow-up. Old `ItemInventory` data already saved in some profiles is left alone (it's ignored, never read).
- Syntax-checked with `luau-compile`; not run in Studio.
- Passed Sol's Studio test (2026-10-02).

---

### T-001 · ShopService never loads (file name casing), so the shop can hang the client
- **Priority:** P0 *(if confirmed: the client waits forever for a remote the server never creates)*
- **Owner:** Agent
- **Area:** Server / Client
- **Files:** `src/Server/Core/Shopservice.luau`

**Problem / goal**
The server boot script only loads modules whose name contains `Service` (case-sensitive). The file is named `Shopservice`, so `ShopService.init()` never runs and the `RequestPurchase` RemoteFunction is never created. `ShopController` calls `SimpleRemotes.getFunction("RequestPurchase")` at the top of the module, which on the client is a `WaitForChild` with no timeout. That would block `ShopController`, and the `Shop` GUI that requires it, forever.

**Done when**
- [x] The file is renamed to `ShopService.luau` (nothing else requires it by path; re-check before renaming).
- [x] Notes tell Sol that this is a case-only rename on Windows (`core.ignorecase = true`), so it must be committed with `git mv` (e.g. via a temporary name).

**Test in Studio**
- After Rojo syncs, check that `ServerStorage.Server.Core.ShopService` exists and the old `Shopservice` ModuleScript is gone.
- Open the shop and buy an item with in-game currency: currency goes down, the item is added, and the "item acquired" popup shows.

**Notes**
- Confirmed by Sol: the client showed `Infinite yield possible on 'ReplicatedStorage.__SIMPLEREMOTES.Functions:WaitForChild("RequestPurchase")'`, which blocked the client boot (UIController requires the Shop GUI, which requires ShopController).
- Renamed with `git mv -f`, so git records it as a rename (already staged). Commit it as is.
- Checked every other remote the client waits for: all are created by a server module that loads. (The shared Logics modules create theirs on the server when their services load them.)
- Passed Sol's Studio test (2026-10-02).

---

### T-004 · Clean up the `PickupLogic` type in PickupLibrary
- **Priority:** P2
- **Owner:** Agent
- **Area:** Shared
- **Files:** `src/Shared/Library/PickupLibrary.luau`

**Problem / goal**
`export type PickupLogic` declares `onPickup` twice with two different signatures (the second, `(userId, activationTime)`, is described as the replication/simulation callback) and has a stray `fart: string` field. With duplicate keys only one signature applies, so modules cast to `PickupLibrary.PickupLogic` aren't type-checked as intended.

**Done when**
- [ ] The type has one entry per callback, matching what `PickupService` / `PickupController` really call, with `Disabled: boolean?` included.
- [ ] The stray field is removed. No runtime behaviour changes.

**Test in Studio**
- None needed beyond a normal server start; pick up any pickup to confirm nothing changed.

**Notes**
- Open question answered from the code: there is no separate replication callback. Both `PickupService` and `PickupController` (on replication, for every player) call `onPickup(player, timestamp)`, so the second `onPickup` entry was removed rather than renamed.
- Type now: `onPickup`, `onEnd?`, `canActivate?` (both sides already call it; no pickup implements it yet) and `Disabled: boolean?`. Stray field removed. Type-only change.
- Found, not changed: `PickupController.activate()` is never called, and it calls `onPickup` with a userId instead of a Player (what the old second entry described). Dead code; remove it in a later task if you agree.
- Passed Sol's Studio test (2026-10-02).

---

### T-003 · Remove leftover debug output from boot and ProductService
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server
- **Files:** `src/Server.server.luau`, `src/Server/Core/ProductService/init.luau`

**Problem / goal**
- `Server.server.luau` prints `Requiring <Module>` for every module on every server start (and those two lines are space-indented in a tab-indented file).
- `ProductService.init()` prints four `~~~~~` lines plus the module name and product ID for every product logic.

**Done when**
- [ ] The `Requiring` prints and the `~~~~~` / name / ID prints are removed. The warning for a product logic without an ID stays.
- [ ] Nothing else in those files changes.

**Test in Studio**
- Start a server: the output shows the "Server loaded" line and no per-module spam.

**Notes**
- Removed the two `Requiring` prints from `Server.server.luau` and the `~~~~~` / name / ID prints from `ProductService.init()`. The missing-productId warning stays.
- Passed Sol's Studio test (2026-10-02).

---

### T-002 · Fix `${...}` in interpolated strings (prints a literal `$`)
- **Priority:** P2
- **Owner:** Agent
- **Area:** Server / Client / Shared
- **Files:** `ProductService/init.luau`, `ProductLogics/Template.luau`, `UI/Gui/ElimMessage/init.luau`, `Library/GameTeamLibrary.luau`, `Library/MarketplaceLibrary.luau`, `Library/ParticlesLibrary.luau`, `Logics/Environment/MovingPlatform.luau`, `Logics/Environment/Portal.luau`

**Problem / goal**
Luau interpolation is `` `text {value}` ``. About 17 warn/error/print strings use JavaScript-style `${value}`, so every message shows a stray `$` (e.g. `Player with userId $123 not found`).

**Done when**
- [ ] No `` ` ``-string in `src/Server`, `src/Client` or `src/Shared` contains `${`.
- [ ] Only the `$` is removed; the messages are otherwise unchanged.

**Test in Studio**
- None needed beyond a normal server start with no new errors.

**Notes**
- Removed the `$` from all 17 `${...}` strings in the 8 listed files; nothing else changed. No `${` left in `src/Server`, `src/Client`, `src/Shared`.
- Passed Sol's Studio test (2026-10-02).

---

### T-016 · Move the chat commands to Cmdr (they have no permission check)
- **Priority:** P0 *(before release: any player in a live server can currently end rounds and grant themselves pickups)*
- **Owner:** Agent
- **Area:** Server
- **Files:** `src/Server/Core/CommandService.luau`, `src/Server/Core/RoundCyclingService.luau`, `src/Server/Core/PickupService.luau`, `src/Server/Cmdr/Commands/`

**Problem / goal**
`CommandService` creates TextChatCommands with no permission check: `/printgamestate`, `/endround`, `/setnextgamemode`, `/setnextmap` (RoundCyclingService) and `/getpickup` (PickupService) work for every player in live servers. Move them to Cmdr commands, which are permission-checked by `CmdrService` (T-015).

**Sol's decision:** all chat command functionality moves entirely into Cmdr, and the chat command system becomes obsolete (no chat commands are registered any more). **Don't delete the chat command code yet:** keep `CommandService` and the old `addCommand` blocks in place but disabled (e.g. commented out or behind a clearly named off switch), as a reference in case something goes wrong during the transfer.

**Done when**
- [x] Each command exists in Cmdr with the same behaviour. Gamemode, map and pickup arguments use a custom Cmdr type or autocomplete list, so they can be tab-completed.
- [x] Logic that needs private state (e.g. `endActiveRound`, `nextGamemode`) is exposed through a small public function on the owning service, not duplicated.
- [x] No chat command is registered any more; the old code is kept but disabled, with a comment pointing to the Cmdr replacements.

**Test in Studio**
- F2 → `endround`, `setnextgamemode HotPotato`, `setnextmap <map>`, `getpickup FireBoomerang`, `printgamestate`: each behaves as the chat command did.

**Notes**
- Done (Sol, 2026-10-02): all chat commands are Cmdr commands (`EndRound`, `SetNextGamemode`, `SetNextMap`, `GetPickup`, `PrintGameState`); the chat command system is obsolete, its code kept for reference.
- New Cmdr commands in `Server/Cmdr/Commands/`: `endround`, `setnextgamemode` (alias `nextgamemode`), `setnextmap` (`nextmap`), `getpickup` (`grantpickup`, gives the effect to the person running it), `printgamestate` (`gamestate`; shows the state in the Cmdr console instead of printing to the server output).
- New Cmdr types in `Server/Cmdr/Types/` (registered by `CmdrService`): `gamemode` (from `Gamemodes`), `map` (from `MapData`, since the map models are server-only; the server still checks the name against the loaded maps) and `pickup` (module names in `PickupLogics`; disabled stubs are listed but the server refuses them).
- New public functions: `RoundCyclingService.forceEndRound()`, `.setNextGamemode(id)`, `.setNextMap(name)`. `PickupService.grantPickupClassId` now returns `(success, message)` (it already existed with the same logic as `/getpickup`).
- Chat commands disabled with `CHAT_COMMANDS_ENABLED = false` in `CommandService` (`addCommand` does nothing). The old `addCommand` blocks are untouched, with a comment pointing to the Cmdr replacements.
- Not checked with Selene or the LSP (not available to the agent).

---

### T-033 · Boomerang throws faster and further
- **Priority:** P1
- **Owner:** Agent
- **Area:** Shared
- **Files:** `Shared/Constants/Tools.luau`

*Update 2026-10-01: at Sol's request, `ClassicBoomerang.ThrowDistance` was raised 30 → 45 (+50%). Speed and the other tools are unchanged.*

**Problem / goal**
The client says the boomerang needs to move "way faster" and go decently further: **twice the throw distance and about 50% more speed**. `ClassicBoomerang` is currently `Speed = 60`, `ThrowDistance = 30`.

**Open questions (ask Sol first)**
- Apply the same multipliers to the other throwables (`Shuriken` 80/40, the 50/20 one), or only to `ClassicBoomerang`?

**Done when**
- [ ] `ClassicBoomerang` is `Speed = 90`, `ThrowDistance = 60` (and the others as Sol decides).
- [ ] Anything tuned to the old values (hitbox radius, aim arrow length, auto-recall timing) still looks right; list any you changed.

**Test in Studio**
- Throw on a few maps: the boomerang travels about twice as far and noticeably faster; hits, bounces and recall still work.

**Notes**
- Marked complete by Sol (2026-10-01), with the `ThrowDistance` 30 → 45 change above.

---

