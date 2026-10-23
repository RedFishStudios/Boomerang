--[[
	WeaponsShop

	Description:
	The Weapons Shop, opened from the Shop button in the left lobby menu (MenuButtons). T-112: a single window (no tabs)
	selling weapon crates, one per category (Shared/Referential/Crates, ShopCommon/Tabs/Crates): buying one gives a random
	weapon of that category (CrateService on the server). Built by ShopCommon/ShopBuilder.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopBuilder = require(ReplicatedStorage.Client.UI.ShopCommon.ShopBuilder)
local CratesTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.Crates)

local BACKGROUND_IMAGE = 125528869499843 -- // 1024 x 696, no tab strip
local ASPECT_RATIO = 1024 / 696

return ShopBuilder.create({
	Name = "WeaponsShop",
	Title = "Weapons Shop",
	BackgroundImage = BACKGROUND_IMAGE,
	AspectRatio = ASPECT_RATIO,
	TestKey = Enum.KeyCode.B,
	-- // Fitted to the new frame art: the listings fill the parchment panel, a 3 x 2 grid (scrolls past 6 crates)
	Layout = {
		HideTabs = true,
		ListingsPosition = UDim2.fromScale(0.12, 0.2),
		ListingsSize = UDim2.fromScale(0.76, 0.6),
		GridColumns = 3,
		GridRows = 2,
	},
	Tabs = {
		{
			Id = "Crates",
			Name = "Crates",
			Icon = "",
			AutoSelect = true,
			Tab = CratesTab,
		},
	},
})
