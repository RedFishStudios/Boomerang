--[[
	WeaponsShop

	Description:
	The Weapons Shop, opened from its topbar button (MenuButtons). A single window (no tabs) selling weapon crates,
	one per category (Shared/Referential/Crates, ShopCommon/Tabs/Crates); buying one gives a random weapon of that
	category (CrateService on the server). Built by ShopCommon/ShopBuilder.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopBuilder = require(ReplicatedStorage.Client.UI.ShopCommon.ShopBuilder)
local CratesTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.Crates)

return ShopBuilder.create({
	Name = "WeaponsShop",
	Title = "Weapons Shop",
	TestKey = Enum.KeyCode.B,
	-- // One row of three big crate cards (scrolls past three)
	Layout = {
		HideTabs = true,
		GridColumns = 3,
	},
	Tabs = {
		{
			Id = "Crates",
			Name = "Crates",
			AutoSelect = true,
			Tab = CratesTab,
		},
	},
})
