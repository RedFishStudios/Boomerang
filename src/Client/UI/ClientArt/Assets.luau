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
}
