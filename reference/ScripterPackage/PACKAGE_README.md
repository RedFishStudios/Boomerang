# Boomerang! — scripter package

The finished UI, taunts, kill effects and fan trails from the working project, exported as editable Roblox packages.
They're the exact scripts, clips, props and settings the project runs. Everything here was installed into a **separate
test place** with only these files and played there (see [Verification](#verification)).

## What's in this folder

| File | Contents |
|---|---|
| `Packages/SharedDependencies.rbxm` | Shared modules (`Theme`, `Assets`, `Cosmetics`, `Remotes`, `QuestData`, `ShopData`), the server `Inventory` (equipped cosmetics) and its `StartInventory` script, and an `R15Rig` for opening the clips. **Import this first: every other package except Trails needs it.** |
| `Packages/UI.rbxm` | All UI: screen modules (`LeftHud`, `InventoryScreen` (also used for Index), `ShopScreen`, `QuestsScreen`, `StatsScreen`, `Kit`), the client `Main` script that builds the screens and connects buttons to panels, the server modules behind them (`Afk`, `Quests`, `Stats`, server `Main`), and `BuiltScreens` (snapshots of the built ScreenGuis, for viewing and editing). |
| `Packages/Taunts.rbxm` | Too Easy, Nap Time, Royal Treatment and Bonk!: the client `Taunts` module with its taunt modules and helpers (`Pose`, `Props`, `Effects`), the `StartTaunts` scripts (client and server), the server `Taunts` module, four **KeyframeSequence clips** (`Animations`) and the three **prop models** (`PropModels`: `DeckChair`, `RoyalCrown`, `TauntBoomerang`). |
| `Packages/KillEffects.rbxm` | Stone, Ashes (fire), Sakura and Shark: the client `KillEffects` module and its effect modules plus helpers (`Fx`, `Rig`), `DefaultDeathSound`, the `StartKillEffects` scripts (client and server), the server `KillEffects` module, and the shark kit modules (`SharkModel`, `SharkKitData`, `SharkKitBody`, `SharkKitJaw`). |
| `Packages/Trails.rbxm` | The six fan trails: `FanTrails` (ModuleScript with `Ribbon`, `Decor` and `Styles/<six styles>`) and `FanTrailsExample`, a **disabled** LocalScript showing one way to connect it. Standalone: no dependencies. |
| `Testing/TrailTestBench.rbxm` | **Testing only, not for production.** The temporary throw/recall/reset bench (`FanTrailTest`) and the copies of the fan models it throws (`FanWeapons`). |
| `Install.luau` | A Command Bar snippet that moves each package's contents into place (below). |
| `AssetManifest.csv` | Every exported object (file, path inside the package, destination, purpose, dependencies) and every image and sound asset id. |
| `SourceAssets/` | Editable sources: `Animations/` (the clips as `.rbxmx` plus the raw 30 fps joint recordings they were built from), `Models/` (the props as `.rbxmx`; `SharkKit/` = the supplied shark kit `.fbx/.glb/.blend`), `UIArtwork/` and `KillEffectTextures/` (all PNG sources), `Tools/` (the generators used: HUD button repaint, clip export, shark converter, flame/icon generators). |
| `Verification/` | Screenshots from the test place, taken with only these packages installed. |

## Installing (import order matters)

1. Open the destination place in Studio (Edit mode).
2. *Model* tab > *Insert from File…*, in this order: `SharedDependencies.rbxm`, `UI.rbxm`, `Taunts.rbxm`,
   `KillEffects.rbxm`, `Trails.rbxm`. They appear as folders in Workspace. Scripts don't run in Edit mode, so nothing
   starts yet.
3. Open *View* > *Command Bar*, paste the whole of `Install.luau`, and press Enter. It:
   - merges each package's `ReplicatedStorage`, `StarterPlayerScripts` and `ServerScriptService` folders into those
     services (same-named folders merge; a same-named script is replaced and reported in Output);
   - moves the reference material (`Animations`, `PropModels`, `BuiltScreens`, `Rigs`) to
     `ServerStorage.BoomerangAssets.<Package>`, where nothing runs.

   You can do the same by hand: drag each package's children into the service they're named after.
4. Save, then press Play.

After installing everything, the place has:

```
ReplicatedStorage
  Shared/        Theme, Assets, Cosmetics, Remotes, QuestData, ShopData,
                 FanTrails (Trails), SharkModel + SharkKitData/Body/Jaw (KillEffects)
  UI/            LeftHud, InventoryScreen, ShopScreen, QuestsScreen, StatsScreen, Kit
  Remotes/       (created by the server at run time)
StarterPlayer.StarterPlayerScripts
  Client/        Main (UI), StartTaunts + Taunts/, StartKillEffects + KillEffects/ + DefaultDeathSound,
                 FanTrailsExample (disabled)
ServerScriptService
  Server/        Main (UI data: Afk, Quests, Stats), StartInventory + Inventory,
                 StartTaunts + Taunts, StartKillEffects + KillEffects
ServerStorage
  BoomerangAssets/  Taunts/Animations, Taunts/PropModels, UI/BuiltScreens, SharedDependencies/Rigs
```

**Names and places matter.** The scripts find each other by these exact names (`ReplicatedStorage.Shared`,
`ReplicatedStorage.UI`, `StarterPlayerScripts.Client`, `ServerScriptService.Server`). If you rename or move them,
update the `WaitForChild` paths at the top of each script.

**If your place already has folders with these names,** they're merged; scripts with the same names are replaced.
Check the Output window for `[Install] replacing` lines.

## Systems and how to drive them

All functions below exist in the exported code, with these exact names and arguments.

### Shared dependencies

- `Shared.Remotes`: RemoteEvent names. `Remotes.event(name)` creates it on the server, or waits for it on the client.
  - Names: `SetAfk`, `Equip`, `ClaimQuest`, `KillEffect`, `Taunt`, `PlayTaunt`.
  - They live in `ReplicatedStorage.Remotes`.
- `Shared.Cosmetics`: the cosmetic categories and items.
  - Each category stores the equipped item id in a player attribute: `EquippedSkin` (default `Default`),
    `EquippedTaunt` (default `TooEasy`), `EquippedArrow` (default `Classic`), `EquippedKillEffect` (default `Skull`).
  - Taunt items name their taunt module (`taunt = "NapTime"`), and kill-effect items their effect
    (`effect = "Stone"`).
- `Server.Inventory`, started by `StartInventory`: sets each player's equipped attributes to the defaults and handles
  the `Equip` remote.
  - Functions: `Inventory.equipped(player, categoryId)` and `Inventory.equip(player, categoryId, itemId)`.
  - `Inventory.owns(player, categoryId, itemId)` currently returns **true for everything** (there's no ownership data
    yet). Connect it to your data system.

### UI

- **Started by:** `Client.Main` (LocalScript). It mounts every screen into `PlayerGui` and wires them up. Server data
  comes from `Server.Main`, which starts `Afk`, `Quests` and `Stats`.
- **Buttons to panels:** in `Client.Main`, `LeftHud.mount(playerGui, { onInventory, onShop, onIndex, onQuests, onStats,
  onAfkChanged })`.
  - Each tile's callback calls `toggle(screen)`. That opens the panel and closes the others, and a second press
    closes it.
  - To add a button or panel, mount the screen and add it to the `popups` list in `Client.Main`.
- **Screen modules** (`ReplicatedStorage.UI`). Each returns a handle with `open()`, `close()`, `isOpen()`,
  `onOpen(fn)` and `destroy()`.
  - `InventoryScreen.mount(parent, { onEquip = function(categoryId, itemId) }, mode)`: `mode` is `"inventory"` or
    `"index"`. Extra functions: `showCategory(categoryId)`, `setEquipped(categoryId, itemId)`.
  - `ShopScreen.mount(parent, { onBuy = function(offerIndex), onGift = function(offerIndex) })`: extra function
    `setGems(amount)`.
  - `QuestsScreen.mount(parent, { onClaim = function(questId) })`: extra function
    `setProgress(questId, progress, claimed)`.
  - `StatsScreen.mount(parent)`: extra functions `setPlayer(player)`, `setValues({ [name] = number })`,
    `setAvatar(image)`.
  - `LeftHud` handle: `setCoins(amount)`, `setAfk(isAfk)`, `isAfk()`, `destroy()`.
- **Dynamic values.** `Client.Main` reads them from **player attributes** the server sets. To use your own data
  system, either set the same attributes from it, or replace the `watch(...)` calls in `Client.Main` with your data
  events.
  - `Coins`, `Gems`: currency. Nothing in this package sets them yet.
  - `AFK`: set by `Server.Afk` (`Afk.set(player, bool)`, `Afk.isAfk(player)`, `Afk.activePlayers()`).
  - `Quest_<id>` and `QuestClaimed_<id>`: set by `Server.Quests`.
    - Your game code reports progress with `Quests.addProgress(player, stat, amount)`. The stat names are in
      `Shared.QuestData`.
    - `Quests.claim(player, questId)` is wired to the Claim button.
  - `MatchElims`, `MatchDefeats`, `Elims`, `Defeats`, `Wins`, `Losses`: set by `Server.Stats`.
    - Deaths and eliminations are counted automatically. The killer is read from the classic `creator` ObjectValue
      under the victim's Humanoid.
    - Your round code calls `Stats.startMatch()` and `Stats.endMatch(winners)`.
    - All-time values are saved in the DataStore `PlayerStats_v1`.
  - The equipped attributes listed under Shared dependencies, set by `Server.Inventory`.
- **Shop purchases:** `ShopData.Offers[i].productId` is **nil for every offer**. Set your Developer Product ids;
  until then Buy only warns in Output. **Gift** only prints, because it isn't built.
- **There is no separate scoreboard** in this project. The Stats panel shows the current match (player, elims,
  defeats) and all-time totals.
- **Fonts:** `Theme.Font` is the built-in FredokaOne, so nothing needs uploading.
- **Different screen sizes:**
  - The HUD scales with the viewport height (`LeftHud`: `DESIGN_VIEWPORT_HEIGHT`, `MIN_SCALE`/`MAX_SCALE`), and
    windows scale the same way (`Kit`).
  - It was checked at the test viewport and with the HUD enlarged, not on real phones or tablets (see Verification).

### Taunts

- **Started by:** `StartTaunts` on both client and server.
- **Trigger:**
  - The player presses **T**, gamepad **Y**, or the on-screen Taunt button on touch devices.
  - That fires `Remotes.Taunt`. Server code can call `Taunts.play(player)` directly; it returns `true` if it
    started.
  - The server checks the player is alive and **R15**, reads `EquippedTaunt`, and locks movement for
    `Taunts.DURATION` (6 s): WalkSpeed, JumpHeight and JumpPower go to 0 and AutoRotate is turned off.
  - It also sets the character attribute `Taunting = <taunt id>` for the duration, then tells every client:
    `PlayTaunt(character, tauntId, skinId)`.
- **Client:** `Taunts.play(character, tauntId, skinId)` plays it locally, on each client, for any character.
  - Each taunt module is `function(character, folder, skinId) -> duration`.
  - Effects and props go under `Workspace.Taunts`.
- **Stop and clean-up:** automatic. Every prop, effect, text and face change belongs to an `Effects.session`, which
  removes everything when the taunt ends, when the character dies, or when it's removed (respawn).
  - There's no "cancel" function. To cut a taunt short, kill or respawn the character, which runs the same
    clean-up.
- **The four taunts, with their exact timing and contents:**
  - **Too Easy:**
    - yawn with a breath puff (0–1 s);
    - hands behind the head (1–4 s);
    - shoulder brushes with hand-following dust puffs (4–5.6 s);
    - a big outlined "EZ" (4.78–5.58 s).
  - **Bonk!:**
    - twirl (0–1.2 s);
    - a 3-stud cosmetic copy of the equipped boomerang skin flies a wide return arc;
    - forehead contact, head recoil and impact burst at 2.6 s;
    - wobble with three big circling stars (2.65–5 s); catch (3.3 s).
  - **Royal Treatment:**
    - an oversized gold crown with a finished base (plate, rim and recess), held tilted, lifted over the head,
      turned upright and lowered on (0–2.5 s);
    - a golden "admire me" pose with outline, aura, sparkles and four ray bursts (2.5–5.5 s).
  - **Nap Time:**
    - the striped beach chair with headrest appears;
    - reclined sleeping pose; eyes closed (eyelids or a face overlay);
    - large blue Zzz (1.4–4.7 s);
    - waking, standing up with leg IK, and the chair removed (5.7 s).
  - Event times are also named markers in each clip.
- **Animation:**
  - **The game plays the taunts procedurally:** `Pose.run` writes the joints every frame from the keyframe tables in
    each taunt module (`KEYS`). No animation upload is needed.
  - The four `KeyframeSequence` clips were recorded frame by frame from those exact scripts (30 fps, 6 s, joints the
    taunt doesn't drive at weight 0) and carry event markers.
  - To switch a taunt to a published animation, follow the steps under Publishing below.
  - Nap Time's seat position lives in the clip's LowerTorso pose and was recorded on a 5-stud avatar. The scripted
    version adapts to any size.
- **Props:** the game builds them at run time (`Props.deckChair`, `Props.crown`, `Props.boomerang`). The models in
  `PropModels` are the same props built once, with the attachments the scripts use:
  - `DeckChair`: `ChairRoot.Ground`, and `ChairRoot.SeatPelvis` (reclined 55°, 5-stud character).
  - `RoyalCrown`: `CrownRoot.HatAttachment`, `RimGripLeft`, `RimGripRight` (2.7× a 1.2-stud head).
  - `TauntBoomerang`: a `Grip` attachment, Default skin, 3 studs.

### Kill effects

- **Started by:** `StartKillEffects` on both client and server.
- **Trigger:** automatic on every death.
  - The server sets `BreakJointsOnDeath = false` on each character, so the body stays whole for the effect.
  - It picks the **killer's** `EquippedKillEffect`, read from the `creator` ObjectValue under the victim's Humanoid,
    otherwise the victim's own.
  - It anchors the body and fires `KillEffect(character, effectName)` to all clients.
  - Server code can call `KillEffects.play(character, effectName)` directly, or `KillEffects.effectFor(victim,
    humanoid)` to look up the effect name.
- **Client:** `KillEffects.play(character, effectName)`, where `effectName` is `Stone`, `Ashes`, `Sakura` or `Shark`.
  - Each effect is 3 s, built under `Workspace.KillEffects`, and removes everything when it finishes.
  - `Skull` (the default item) plays no effect.
- **Sounds and preload:**
  - `DefaultDeathSound.start()` mutes Roblox's built-in death sound on every life.
  - At start the client preloads every kill-effect texture and sound, so the first death already shows them.
- **Shark:** built on each client at run time from `SharkKitData` with **EditableMesh**. See Publishing.

### Trails (existing weapons)

- **No setup objects on the weapon:** nothing is placed on the fan. You call the API from client code with the
  thrown weapon.
  - Style by model name: `BambooFan` = Bamboo, `SunsetFan` = SunsetPop, `Surge` / `SurgeFan` = TidalSurge,
    `SakuraFan` = SakuraDrift, `MoonsongFan` = Moonsong, `SunfireFan` / `SunfireFan_01` / `SunFire1` =
    SunfirePhoenix (`FanTrails.StyleForFan`).
  - Or pass the style name yourself.
- **Calls:**
  ```lua
  local FanTrails = require(game.ReplicatedStorage.Shared.FanTrails)
  local trail = FanTrails.new(weaponModelOrPart)        -- or FanTrails.new(weapon, "TidalSurge", { Span = 13.8 })
  trail:Start()    -- on release; keep it running for the whole flight, out and back
  trail:Stop()     -- caught / landed / stopped: no new sections, the rest shrinks and fades (~0.35 s)
  trail:Reset()    -- teleport / reset / respawn: clears everything at once
  trail:SetWeapon(newInstance)   -- if the projectile instance changes mid-flight
  trail:IsBusy()   -- true while anything is still visible
  trail:Destroy()  -- free it (after Stop() + FadeTime)
  FanTrails.destroyAll()
  ```
- **How it behaves:**
  - It follows the centre of the weapon part, sampled every frame after the camera, so it starts exactly at the
    weapon.
  - It keeps at most `Length` = 2 fan spans of the travelled path, cut every frame, so it never reaches the hand.
  - A jump of more than `TeleportDistance` (3 spans) in one frame clears it.
  - Options for `new`: `Span` (the fan's tip-to-tip size, measured if omitted), `Parent` (default
    `Workspace.FanTrailsFx`), `WidthScale`.
- **Where to call it:** in client code, on every client.
  - `FanTrailsExample` shows one way: set a `FanState` attribute on the projectile (`Flying` / `Caught` / `Landed` /
    `Teleport`) before parenting it to Workspace.
  - Enable it only if your weapon code works that way.
- **Settings:** one ModuleScript per trail in `FanTrails/Styles`.
  - Colours, width, length, lifetime, emission spacing and particle size are named and commented.
  - All sizes are fractions of the fan span.
- **Weapons:** use your **existing weapon models in the destination place**. The `FanWeapons` copies in
  `Testing/TrailTestBench.rbxm` exist only for the bench; they aren't a production dependency.
- **Bamboo leaf mesh:** the Bamboo leaf is an EditableMesh built at run time (see Publishing). If that isn't
  available, a thin part-based leaf is used automatically.

## Publishing, permissions and setup still to do

None of these are done for the destination experience. Each one is needed when it applies.

1. **Images:** all images (UI art, kill-effect textures, skin art) were uploaded by the project's Roblox account. Ids
   are in `Shared.Assets` and `AssetManifest.csv`.
   - If the destination experience is owned by a **group** or another account and an image doesn't show, re-upload
     the PNG from `SourceAssets/UIArtwork` or `SourceAssets/KillEffectTextures` under the owner.
   - Then replace the id in `Shared.Assets`.
2. **Audio:** the kill-effect sounds are Creator Store ids (listed in the manifest). They loaded in the test place,
   but confirm each one is usable by the destination experience (public, or permission granted).
3. **EditableMesh (shark and bamboo leaf):** these use `AssetService:CreateEditableMesh` / `CreateMeshPartAsync` at
   run time.
   - Make sure EditableMesh is allowed for the published experience. Roblox gates the Mesh/Image APIs behind an
     experience setting and owner requirements; check *Game Settings > Security*.
   - Test the shark once published. If EditableMesh is unavailable, the shark effect can't build its model. The leaf
     falls back to parts.
4. **DataStores:** `Stats` saves to `PlayerStats_v1`. Publish the place, and enable API access in *Game Settings >
   Security* to test saving in Studio. Without it, stats work but aren't saved.
5. **Developer Products:** set `productId` for each `ShopData.Offers` entry.
6. **Animations (optional):** nothing is published, because the taunts are scripted. To use published animations
   instead:
   1. Put `Rigs/R15Rig` in Workspace and move a clip into its `AnimSaves`.
   2. Publish the clip from the Animation Editor under the **experience owner**: the group, for a group game.
      Animations owned by someone else won't play.
   3. Replace `Pose.run(...)` in that taunt with an `Animation` played on the character's `Animator` (priority
      Action). Keep the props/effects code, synced through `GetMarkerReachedSignal` and the clip markers.
7. **Meshes:** the fan weapon meshes belong to your `Fans.rbxm` and aren't part of these packages. The shark kit FBX
   in `SourceAssets/Models/SharkKit` is only needed if you want it as a regular mesh asset.
8. **R15 only:** taunts need R15 characters. Kill effects work on R15 and classic rigs.

## Testing tools (separate from production)

`Testing/TrailTestBench.rbxm` adds a **FAN TRAIL TEST (temporary)** panel for throwing any fan with its trail:
- Curved or straight throw, Recall, Stop/land, Teleport, Throw all six, RESET.
- Speed and size, and light or dark backgrounds.
- It doesn't change the camera, and it doesn't touch gameplay.

Install it with `Install.luau` (it's in the install list) only in a test copy. To remove it, delete
`StarterPlayerScripts.Client.FanTrailTest` and `ReplicatedStorage.FanWeapons`.

## Verification

**How it was tested:**
1. A copy of the place had all project folders deleted, leaving a bare baseplate.
2. Only these `.rbxm` files were inserted, then `Install.luau` was run.
3. The test place was then played. Screenshots are in `Verification/`.

| Check | Result |
|---|---|
| Install | The six packages inserted with all their objects (SharedDependencies 289, UI 385, Taunts 12,515, KillEffects 21, Trails 15, bench 26); `Install.luau` left nothing behind in Workspace. The installed scripts are the same set as the working project's. No errors in Output. |
| UI | HUD built with the corrected button art. Clicking Inventory, Shop, Index, Quests and Stats each opened its own panel and closed the previous one; clicking again closed it. The AFK toggle round-tripped to the server attribute. The Stats panel showed live player data. After respawns there's still exactly one of each screen. |
| Taunts | All four played from the packages (screenshots 03–06): about 23, 42, 252 and 117 effect objects, all removed after 6.0–6.1 s. Dying mid-Nap-Time removed everything within 0.3 s. |
| Kill effects | Stone, Ashes, Sakura and Shark played and cleaned up (screenshots 07–09). All 14 sounds load (0.3–7 s each). The default death sound is muted. On the first run, before the preload fix, the flames showed as white sprites while their textures downloaded; the package now preloads them. With the fix, Output is clean. |
| Trails | All six thrown together and each up close in real Roblox renders (screenshots 10–14). In the test place, every frame stayed within 2 fan spans for Bamboo, Tidal Surge, Moonsong and Phoenix, and Bamboo used the mesh leaves. Catch, stop/land, teleport and reset clean-up were measured in the working project with the same code: zero gap at the fan, gone about 0.4 s after a catch, nothing drawn across a teleport. |
| Respawn / camera | The character respawns normally and the camera stays the normal player camera. Nothing in the packages overrides it. |

**Not tested or not included:**
- The `.rbxm` files were inserted with `SerializationService` (what Insert from File uses under the hood), not by
  clicking *Insert from File*.
- The KeyframeSequence clips weren't opened in the Animation Editor or published.
- The HUD wasn't checked on real phones or tablets.
- Nothing was tested in a published experience (DataStores, EditableMesh permission, audio permission, group-owned
  images).
- Multiplayer wasn't tested: everything is per-client, driven by server remotes.
- Two small trail tweaks came after screenshots 13–14: Moonsong's orbs are bluer and its feathers larger, and the
  Phoenix has finer segments. Both are in the packages.
- **Not in the project, so not exported:** a separate scoreboard, shop gifting (prints only), currency sources
  (`Coins` and `Gems` aren't set by anything here), and item ownership (`Inventory.owns` returns true).
