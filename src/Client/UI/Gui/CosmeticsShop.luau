--[[
	CosmeticsShop

	Description:
	The Cosmetics Shop. Tabs: Charge Effects (the old Arrows tab, charge up effects), Elim Effects and Emotes.
	Elim Effects has no system behind it yet, so its tab opens blank. Built by ShopCommon/ShopBuilder.
	Nothing opens it yet: the Shop button in MenuButtons opens the Weapons Shop for now (the B key toggles the Weapons
	Shop in Studio, N toggles this one).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopBuilder = require(ReplicatedStorage.Client.UI.ShopCommon.ShopBuilder)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local ChargeEffectsTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.ChargeEffects)
local EmotesTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.Emotes)

local BACKGROUND_IMAGE = 94533454566099 -- // 1024 x 696
local ASPECT_RATIO = 1024 / 696

return ShopBuilder.create({
	Name = "CosmeticsShop",
	Title = "Cosmetics Shop",
	BackgroundImage = BACKGROUND_IMAGE,
	AspectRatio = ASPECT_RATIO,
	TestKey = Enum.KeyCode.N,
	Tabs = {
		{
			Id = "ChargeEffects",
			Name = "Charge Effects",
			Icon = "⬆️", -- // Only shown if IconImage is removed
			IconImage = Icons.ChargeUpEffects, -- // Same icon as the Inventory's Charges tab
			AutoSelect = true,
			Tab = ChargeEffectsTab,
		},
		{
			Id = "ElimEffects",
			Name = "Elim Effects",
			Icon = "✨", -- // PLACEHOLDER emoji, replace with an image later
			-- // No Tab: eliminations have no effects system yet, so this tab stays empty
		},
		{
			Id = "Emotes",
			Name = "Emotes",
			Icon = "🎵", -- // PLACEHOLDER emoji, replace with an image later
			Tab = EmotesTab,
		},
	},
})
