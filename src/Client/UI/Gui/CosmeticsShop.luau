--[[
	CosmeticsShop

	Description:
	The Cosmetics Shop. Tabs: Charges (charge up effects), Strikes (elimination effects), Emotes and Taunts, named and
	iconed as in the Inventory. Built by ShopCommon/ShopBuilder.
	Opened by the Shop button (lobby and topbar, MenuButtons). In Studio, N toggles this shop and B the Weapons Shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopBuilder = require(ReplicatedStorage.Client.UI.ShopCommon.ShopBuilder)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).InventoryScreen
local ChargeEffectsTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.ChargeEffects)
local EmotesTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.Emotes)
local ElimEffectsTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.ElimEffects)
local TauntsTab = require(ReplicatedStorage.Client.UI.ShopCommon.Tabs.Taunts)

return ShopBuilder.create({
	Name = "CosmeticsShop",
	Title = "Cosmetics Shop",
	TestKey = Enum.KeyCode.N,
	Tabs = {
		{
			Id = "ChargeEffects",
			Name = "Charges",
			IconImage = Art.IconCharge,
			AutoSelect = true,
			Tab = ChargeEffectsTab,
		},
		{
			Id = "ElimEffects",
			Name = "Strikes",
			IconImage = Art.IconStrike,
			Tab = ElimEffectsTab,
		},
		{
			Id = "Emotes",
			Name = "Emotes",
			IconImage = Art.IconTaunt,
			Tab = EmotesTab,
		},
		{
			Id = "Taunts",
			Name = "Taunts",
			IconImage = Art.IconTaunt,
			Tab = TauntsTab,
		},
	},
})
