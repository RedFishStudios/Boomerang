--[[
	WeaponsShop

	Description:
	The Weapons Shop, opened from the Shop button in the left lobby menu (MenuButtons). Tabs: Boomerangs, Fans and
	Shurikens; a weapon's tab is the Category of its tool in Shared/Constants/Tools (the tab lists the skins on sale whose
	model has that Category, see ShopCommon/Tabs/WeaponCategory). Built by ShopCommon/ShopBuilder.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopBuilder = require(ReplicatedStorage.Client.UI.ShopCommon.ShopBuilder)
local WeaponCategory = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.WeaponCategory)

local BACKGROUND_IMAGE = 95152882623490 -- // 1024 x 696
local ASPECT_RATIO = 1024 / 696

return ShopBuilder.create({
	Name = "WeaponsShop",
	Title = "Weapons Shop",
	BackgroundImage = BACKGROUND_IMAGE,
	AspectRatio = ASPECT_RATIO,
	TestKey = Enum.KeyCode.B,
	Tabs = {
		{
			Id = "Boomerangs",
			Name = "Boomerangs",
			Icon = "🪃", -- // PLACEHOLDER emoji, replace with an image later
			AutoSelect = true,
			Tab = WeaponCategory.create("Boomerang"),
		},
		{
			Id = "Fans",
			Name = "Fans",
			Icon = "🪭", -- // PLACEHOLDER emoji, replace with an image later
			Tab = WeaponCategory.create("Fan"),
		},
		{
			Id = "Shurikens",
			Name = "Shurikens",
			Icon = "⭐", -- // PLACEHOLDER emoji, replace with an image later
			Tab = WeaponCategory.create("Shuriken"),
		},
	},
})
