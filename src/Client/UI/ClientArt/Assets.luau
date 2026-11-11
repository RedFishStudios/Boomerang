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
	},

	-- // Inventory (and Index). Window and tabs are placeholders made from the client's art (Sol approved, uploaded to the
	-- // group 2026-11-11; sources in Projects/Boomerang/Assets/ArtPipeline/InventoryUI): the window with its 4 painted
	-- // tabs removed, and 5 tabs with their text removed (labels are drawn in-game).
	InventoryScreen = {
		Window = "rbxassetid://100569610070069", -- TODO:RELEASE placeholder (decal 80287353389307)
		TabWeapons = "rbxassetid://115928986191252", -- TODO:RELEASE placeholder (decal 87673002689740)
		TabEmotes = "rbxassetid://109084628721490", -- TODO:RELEASE placeholder (decal 113081464936121; green copy of Taunts)
		TabCharges = "rbxassetid://110034879992377", -- TODO:RELEASE placeholder (decal 77204615083214)
		TabStrikes = "rbxassetid://123322721123126", -- TODO:RELEASE placeholder (decal 132962245504393)
		TabTaunts = "rbxassetid://137405929782054", -- TODO:RELEASE placeholder (decal 127549647543447)
		-- // The client's own uploads
		Close = "rbxassetid://80939948956702",
		Equip = "rbxassetid://132460269560761", -- // Text painted out
		Equipped = "rbxassetid://98784855760472", -- // Grey copy of Equip
		CardNormal = "rbxassetid://116087380238399",
		CardSelected = "rbxassetid://99224325157096",
		CardEquipped = "rbxassetid://92633980617370",
		Check = "rbxassetid://103175301119608", -- // Equipped badge
	},

	-- // Stats menu (the client's own uploads): the window has its labels and icons painted in; numbers are live text
	StatsScreen = {
		Window = "rbxassetid://117972552516440",
		Close = "rbxassetid://99387041915365",
	},
}
