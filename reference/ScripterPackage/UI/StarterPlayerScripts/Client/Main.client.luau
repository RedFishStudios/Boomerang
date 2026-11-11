--@localscript
-- Client UI entry point (a LocalScript: a RunContext=Client Script in StarterPlayerScripts would run twice). Mounts the
-- UI modules from ReplicatedStorage.UI, connects each HUD button to its panel, and keeps the panels in step with the
-- player attributes the server sets. Taunts and kill effects start from their own scripts (StartTaunts,
-- StartKillEffects), so each system can be installed on its own.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local LeftHud = require(UI:WaitForChild("LeftHud"))
local InventoryScreen = require(UI:WaitForChild("InventoryScreen"))
local ShopScreen = require(UI:WaitForChild("ShopScreen"))
local QuestsScreen = require(UI:WaitForChild("QuestsScreen"))
local StatsScreen = require(UI:WaitForChild("StatsScreen"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local QuestData = require(Shared:WaitForChild("QuestData"))
local ShopData = require(Shared:WaitForChild("ShopData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Calls fn now and whenever the player attribute changes.
local function watch(attribute: string, fn: (value: any) -> ())
	player:GetAttributeChangedSignal(attribute):Connect(function()
		fn(player:GetAttribute(attribute))
	end)
	fn(player:GetAttribute(attribute))
end

-- Screens ------------------------------------------------------------------------------------------------------

local inventory = InventoryScreen.mount(playerGui, {
	onEquip = function(categoryId: string, itemId: string)
		Remotes.event(Remotes.Equip):FireServer(categoryId, itemId)
	end,
})

local index = InventoryScreen.mount(playerGui, {}, "index")

local shop = ShopScreen.mount(playerGui, {
	onBuy = function(offerIndex: number)
		local offer = ShopData.Offers[offerIndex]
		if offer.productId then
			MarketplaceService:PromptProductPurchase(player, offer.productId)
		else
			warn(`[BoomerangUI] Shop offer {offerIndex} ({offer.skinId}) has no Developer Product id yet`)
		end
	end,
	onGift = function(offerIndex: number)
		-- TODO: gifting needs a friend picker and a server purchase flow.
		print(`[BoomerangUI] Gift offer {offerIndex} (not built yet)`)
	end,
})

local quests = QuestsScreen.mount(playerGui, {
	onClaim = function(questId: string)
		Remotes.event(Remotes.ClaimQuest):FireServer(questId)
	end,
})

-- Only one popup at a time: opening one closes the rest; pressing its tile again closes it.
local stats = StatsScreen.mount(playerGui)
stats.setPlayer(player)

local popups = { inventory, index, shop, quests, stats }
local function toggle(screen)
	if screen.isOpen() then
		screen.close()
		return
	end
	for _, other in popups do
		if other ~= screen then
			other.close()
		end
	end
	screen.open()
end

local hud = LeftHud.mount(playerGui, {
	onInventory = function()
		toggle(inventory)
	end,
	onShop = function()
		toggle(shop)
	end,
	onIndex = function()
		toggle(index)
	end,
	onQuests = function()
		toggle(quests)
	end,
	onStats = function()
		toggle(stats)
	end,
	onAfkChanged = function(isAfk: boolean)
		-- The button flips right away; the server's attribute confirms it (or resets it) below.
		Remotes.event(Remotes.SetAfk):FireServer(isAfk)
	end,
})

-- Server state ---------------------------------------------------------------------------------------------------

-- Equipped cosmetics (Server.Inventory).
for _, category in Cosmetics.list do
	watch(category.attribute, function(itemId)
		if typeof(itemId) == "string" then
			inventory.setEquipped(category.id, itemId)
			index.setEquipped(category.id, itemId)
		end
	end)
end

-- Quest progress (Server.Quests).
for id in QuestData.byId do
	local function sync()
		quests.setProgress(
			id,
			player:GetAttribute("Quest_" .. id) or 0,
			player:GetAttribute("QuestClaimed_" .. id) == true
		)
	end
	player:GetAttributeChangedSignal("Quest_" .. id):Connect(sync)
	player:GetAttributeChangedSignal("QuestClaimed_" .. id):Connect(sync)
	sync()
end

-- AFK (Server.Afk). Coins and Gems come from attributes until the game's data layer exists.
watch("AFK", function(value)
	hud.setAfk(value == true)
end)
watch("Coins", function(value)
	hud.setCoins(value or 0)
end)
watch("Gems", function(value)
	shop.setGems(value or 0)
end)

-- Stats (Server.Stats): current match and all-time counters, live.
for _, attribute in { "MatchElims", "MatchDefeats", "Elims", "Defeats", "Wins", "Losses" } do
	watch(attribute, function(value)
		stats.setValues({ [attribute] = if typeof(value) == "number" then value else 0 })
	end)
end
player:GetPropertyChangedSignal("DisplayName"):Connect(function()
	stats.setPlayer(player)
end)

print("[BoomerangUI] client started")
