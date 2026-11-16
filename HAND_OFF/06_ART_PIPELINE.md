# 06 · GUI art: where it comes from and how it's uploaded

## Where the art is

- **In the game:** every image is a Roblox asset id. The new-style GUI art ids are in `src/Client/UI/ClientArt/Assets.luau` (grouped by screen: `StatsPanel`, `Touch`, `RoundResults`...). Icons are in `src/Shared/Constants/Icons.luau` (pickups and HUD), and in each cosmetic's entry in `src/Shared/Referential/*.luau` (e.g. `ElimEffects.luau`'s `Icon`). Art ids from the client's scripter package are listed in `reference/ScripterPackage/AssetManifest.csv`.
- **Working files** (source PNGs and scripts) were kept **outside the repo**, at `C:\MY FILES\Projects\Boomerang\Assets\ArtPipeline\` on the previous developer's PC: one folder per screen (`DailyUI`, `ElimEffectsUI`, `GamemodeHudUI`, `HudUI`, `InventoryUI`, `ItemAcquiredUI`, `PickupsUI`, `QuestsUI`, `RoundResultsUI`, `SettingsUI`, `StatsUI`, `TouchUI`, `VoteUI`), `Shared/` (reusable pieces, e.g. `boomerang_hd.png`, a large clean version of the client's boomerang icon), and `_Scripts/` with a README. About 150 files, 44 MB. **Ask whoever handed you the repo for a copy.** Without it, the uploaded art keeps working; you'd only need to redo art you want to change.
- **The client's original art** came in the scripter package (`SourceAssets/UIArtwork`) and as loose images (old icons such as `Slash.png`).

## How the new-style art was made

The client supplied GUI mockups and a few finished pieces (e.g. a Stats window). Every other window, ribbon, button and icon was derived from those pieces with small Python scripts (numpy, run with Blender's bundled Python because that PC had no other image tools), not drawn by hand:
- recolouring and cutting parts out of the approved client art (flood fills, HSV shifts),
- drawing panels and shapes as signed-distance-field rounded rectangles instead of stretching slices,
- building a window's interior separately and cross-fading the side seams,
- placing the client's boomerang icon over old icons to restyle them.

You don't have to keep this method. Any image editor works, as long as the result matches the client's style: cream lettering with a dark outline, wooden planks and parchment panels, red ribbons, a reddish-brown rim, the client's boomerang.

**One rule that matters with any tool:** before uploading a PNG with transparency, make sure the **colour under transparent and semi-transparent pixels isn't black**. Roblox filters textures, so black hidden under transparent pixels shows up as a dark fringe around the image. The fix the previous developer used: if colours were stored premultiplied, divide by alpha, then give every transparent pixel the colour of the nearest visible pixel (`unpremul.py`, `defringe.py` in the pipeline). Many editors have an equivalent ("bleed", "solidify" or "alpha padding").

## Uploading

1. Get the client's (or your own) approval on the **final** file before uploading. This includes re-uploading an existing asset for a fix that's hard to see. It was a firm project rule.
2. Upload as a **Decal** owned by the group **293180599** (Creator Dashboard, Studio's Asset Manager, or Open Cloud `POST /assets/v1/assets` with `creationContext.creator.groupId`).
3. A Decal's asset id isn't the image id. Get the image id in Studio with `game:GetService("InsertService"):LoadAsset(decalId)` and read the `Texture` of the Decal inside, or use the id the Asset Manager shows for the image.
4. Put the id in `ClientArt/Assets.luau`, `Icons.luau` or the right `Referential` entry, as `rbxassetid://<id>` or a number, matching its neighbours.

## Kit and Theme (how art is used in code)

New GUIs are built in code with `src/Client/UI/ClientArt/Kit.luau` (helpers such as `Kit.create`, `Kit.label` for the cream outlined lettering, `Kit.setText`, `Kit.pressable` for button press animations) and `Theme.luau` (colours, fonts and text sizes). Most screens lay out on a fixed canvas (e.g. 900 px wide) scaled with the screen by a `UIScale` (reference 1280 × 720). `PendingPlayers` and `GameAboutToStart` are short, readable examples.
