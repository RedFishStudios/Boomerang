--[[
	CosmeticsShop

	Description:
	The Cosmetics Shop. Tabs: Charge Effects, Strike Effects (elimination effects), Emotes and Taunts. Built by ShopCommon/ShopBuilder.
	Opened by the Shop button (lobby and topbar, MenuButtons). In Studio, N toggles this shop and B the Weapons Shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopBuilder = require(ReplicatedStorage.Client.UI.ShopCommon.ShopBuilder)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local ChargeEffectsTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.ChargeEffects)
local EmotesTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.Emotes)
local ElimEffectsTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.ElimEffects)
local TauntsTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.Taunts)

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
			Icon = "⬆️", -- // Shown only if IconImage is removed
			IconImage = Icons.ChargeUpEffects,
			AutoSelect = true,
			Tab = ChargeEffectsTab,
		},
		{
			Id = "ElimEffects",
			Name = "Strike Effects",
			Icon = "✨", -- // Shown only if IconImage is removed
			IconImage = Icons.Eliminations,
			Tab = ElimEffectsTab,
		},
		{
			Id = "Emotes",
			Name = "Emotes",
			Icon = "🎵", -- // PLACEHOLDER emoji
			Tab = EmotesTab,
		},
		{
			Id = "Taunts",
			Name = "Taunts",
			Icon = "😜", -- // PLACEHOLDER emoji
			Tab = TauntsTab,
		},
	},
})
