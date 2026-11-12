--[[
	ClientArt Assets

	Description:
	Image ids of the client's UI art ("Official Boomerang! UI" mockups), from the client's scripter package
	(reference/ScripterPackage, Shared.Assets; sources in Downloads/Boomerang-ScripterPackage/SourceAssets/UIArtwork).
	Uploaded by the client's Roblox account (Sol, 2026-11-11: use these ids as they are). If one stops loading, re-upload
	the PNG under the group and replace its id here.
]]

return {
	-- // Left HUD (MenuButtons): coin plank, four tiles (background / icon / ribbon layers), AFK slide toggle, Stats
	LeftHud = {
		Coins = "rbxassetid://92623373586205",
		Inventory = {
			Bg = "rbxassetid://107933567065556",
			Icon = "rbxassetid://87222260817902",
			Ribbon = "rbxassetid://115409735230432",
		},
		Shop = {
			Bg = "rbxassetid://107809823827340",
			Icon = "rbxassetid://139232895555907",
			Ribbon = "rbxassetid://124188475504187",
		},
		Index = {
			Bg = "rbxassetid://88400410898617",
			Icon = "rbxassetid://108417862179805",
			Ribbon = "rbxassetid://104670735977469",
		},
		Quests = {
			Bg = "rbxassetid://82982471343448",
			Icon = "rbxassetid://81494824168101",
			Ribbon = "rbxassetid://138863946360885",
		},
		Stats = "rbxassetid://87777044350124", -- // Wood frame and vines, teal interior, bar-chart icon, "Stats"
		AfkFrame = "rbxassetid://109934974740266", -- // Wooden frame with "AFK" and an empty slot for the toggle
		AfkTrackOn = "rbxassetid://128081804518008", -- // Green track
		AfkTrackOff = "rbxassetid://140404332176286", -- // Red track
		AfkKnob = "rbxassetid://85483530910661",
		-- // Blank pieces made from the client's art (Sol approved, uploaded to the group 2026-11-11; sources in
		-- // Projects/Boomerang/Assets/ArtPipeline/HudUI). No text or icons painted in: those are instances.
		RibbonBlank = "rbxassetid://84048326857216", -- // Tile ribbon, no label (decal 124770894646124)
		CoinsBlank = "rbxassetid://121015077879334", -- // Coin plank, no coins (decal 72613805244743)
		AfkFrameBlank = "rbxassetid://86482601617503", -- // No "AFK" (decal 113107929392068)
		StatsBlank = "rbxassetid://100091781409398", -- // Teal button, no icon or "Stats" (decal 84108479099038)
		IconCoins = "rbxassetid://139285801889097", -- // The client's coin icon (decal 104975043270108)
		IconStats = "rbxassetid://96402700613329", -- // The client's bar-chart icon (decal 126596162842988)
	},

	-- // Inventory (and Index). Blank pieces made from the client's art (Sol approved, uploaded to the group 2026-11-11;
	-- // sources in Projects/Boomerang/Assets/ArtPipeline/InventoryUI): the window with its painted tabs and badge
	-- // removed, and 5 tab buttons redrawn blank. Tab icons and labels are instances.
	InventoryScreen = {
		Window = "rbxassetid://95342522239169", -- // Blank ribbon, no badge (decal 127693540784571)
		TabWeapons = "rbxassetid://104470389661279", -- // Purple (decal 93535809841315)
		TabEmotes = "rbxassetid://95318017172558", -- // Green (decal 98553801748384)
		TabCharges = "rbxassetid://97480453072272", -- // Yellow (decal 135328828759361)
		TabStrikes = "rbxassetid://70952811695340", -- // Red (decal 71054766095276)
		TabTaunts = "rbxassetid://127122996185733", -- // Teal (decal 130342524204446)
		-- // Tab icons: the client's item icons (Weapons uses the Stats boomerang, StatsScreen.IconElims)
		IconTaunt = "rbxassetid://95015399525254", -- // Laughing figure, Emotes and Taunts (decal 132804332134419)
		IconCharge = "rbxassetid://102385757405683", -- // Cream arrow (decal 108994969519196)
		IconStrike = "rbxassetid://125895051003768", -- // Skull (decal 74646763313831)
		-- // The client's own uploads
		Close = "rbxassetid://80939948956702",
		Equip = "rbxassetid://132460269560761", -- // Text painted out
		Equipped = "rbxassetid://98784855760472", -- // Grey copy of Equip
		CardNormal = "rbxassetid://116087380238399",
		CardSelected = "rbxassetid://99224325157096",
		CardEquipped = "rbxassetid://92633980617370",
		Check = "rbxassetid://103175301119608", -- // Equipped badge
	},

	-- // Stats menu: blank window and card icons made from the client's Stats art (Sol approved, uploaded to the group
	-- // 2026-11-11; sources in Projects/Boomerang/Assets/ArtPipeline/StatsUI). Titles, headers, labels and numbers are
	-- // instances. Close is the client's own upload.
	StatsScreen = {
		Window = "rbxassetid://78889924364694", -- // (decal 88993017209910)
		Close = "rbxassetid://99387041915365",
		IconElims = "rbxassetid://121421234003952", -- // Boomerang (decal 96451088103144)
		IconDefeats = "rbxassetid://115317449494823", -- // Broken shield (decal 106974828345175)
		IconWins = "rbxassetid://112602315457811", -- // Trophy with laurels (decal 83075288880331)
		IconLosses = "rbxassetid://110184146477831", -- // Red flag (decal 131876269322029)
	},

	-- // Quests menu: blank pieces made from the client's Quests art (Sol approved, uploaded to the group 2026-11-11; sources in
	-- // Projects/Boomerang/Assets/ArtPipeline/QuestsUI). No text, pictures or icons are painted in: those are instances.
	QuestsScreen = {
		Window = "rbxassetid://78889150296184", -- // Frame, blank ribbon (decal 84702135989032)
		Card = "rbxassetid://140351739945319", -- // Quest card: blue picture area + cream panel (decal 97830752685452)
		ProgressTrack = "rbxassetid://95965897865817", -- // (decal 133451808661104)
		TabOn = "rbxassetid://106912657786737", -- // Blue (decal 81853756394493)
		TabOff = "rbxassetid://105871291966317", -- // Brown (decal 134088098120919)
		TimerPill = "rbxassetid://120463473178963", -- // (decal 131291387486580)
		CloseBlank = "rbxassetid://128672243656040", -- // (decal 138197375252098)
		IconClose = "rbxassetid://123889382158521", -- // X (decal 70842151483207)
		IconClock = "rbxassetid://94571370410645", -- // (decal 74364736211234)
		IconCalendar = "rbxassetid://78940266549548", -- // (decal 108687862133996)
		IconSeason = "rbxassetid://98310102306740", -- // (decal 92803166890777)
		ButtonGreen = "rbxassetid://87354740878901", -- // The client's own (already blank)
		ButtonGrey = "rbxassetid://131710866567888", -- // The client's own (already blank)
	},
}
