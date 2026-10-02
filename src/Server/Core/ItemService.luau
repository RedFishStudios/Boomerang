--[[
	ItemService

	Description:
	Handles server-side item operations on the player's `Inventory` (item id -> amount owned).
	Item data comes from Shared/Referential/Items. Changes replicate to the client through the data proxy.

	Author:
	@SixthAtom
]]

local ItemService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local Items = require(ReplicatedStorage.Shared.Referential.Items)
local ResponseCodes = require(ReplicatedStorage.Shared.Networking.ResponseCodes)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ItemEventTask = (player: Player, itemId: Items.ItemClassId, deltaAmount: number) -> ()

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ItemService.ItemGrantedTasks = TasksList.new() :: TasksList.TasksList<ItemEventTask>
ItemService.ItemConsumedTasks = TasksList.new() :: TasksList.TasksList<ItemEventTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Returns the player's Inventory proxy, or nil if the data isn't loaded or the item doesn't exist
local function getInventoryForItem(player: Player, itemId: string)
	if not Items[itemId] then
		return nil
	end

	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end

	return data.Inventory
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ItemService.getAmount(player: Player, itemId: string): number
	local inventory = getInventoryForItem(player, itemId)
	if not inventory then
		return 0
	end

	return inventory[itemId] or 0
end

function ItemService.hasItem(player: Player, itemId: string): boolean
	return ItemService.getAmount(player, itemId) > 0
end

--- Adds `amount` (default 1) of an item. Returns false if the item doesn't exist or the data isn't loaded.
function ItemService.grantItem(player: Player, itemId: string, amount: number?): boolean
	local inventory = getInventoryForItem(player, itemId)
	if not inventory then
		return false
	end

	local addAmount = math.max(1, amount or 1)
	inventory[itemId] = (inventory[itemId] or 0) + addAmount
	ItemService.ItemGrantedTasks:Execute("parallel", player, itemId, addAmount)

	return true
end

--- Removes `amount` (default 1) of an item. Returns false if the player doesn't have enough.
function ItemService.consumeItem(player: Player, itemId: string, amount: number?): boolean
	local inventory = getInventoryForItem(player, itemId)
	if not inventory then
		return false
	end

	local takeAmount = math.max(1, amount or 1)
	local currentAmount = inventory[itemId] or 0
	if currentAmount < takeAmount then
		return false
	end

	local nextAmount = currentAmount - takeAmount
	inventory[itemId] = if nextAmount > 0 then nextAmount else nil
	ItemService.ItemConsumedTasks:Execute("parallel", player, itemId, takeAmount)

	return true
end

--- Buys one of an item with Currency. Returns a ResponseCode.
function ItemService.purchaseItem(player: Player, itemId: string): number
	local itemData = Items[itemId]
	if not itemData or itemData.OffSale then
		return ResponseCodes.NotFound
	end

	if not PlayerDataService.get(player) then
		return ResponseCodes.ServiceUnavailable
	end

	if not EconomyService.spendCurrency(player, itemData.Price) then
		return ResponseCodes.UnprocessableEntity -- // Can't afford
	end

	ItemService.grantItem(player, itemId, 1)
	return ResponseCodes.Ok
end

--- Returns the player's Inventory proxy (item id -> amount), or nil if the data isn't loaded.
function ItemService.getInventory(player: Player)
	local data = PlayerDataService.get(player)
	return if data then data.Inventory else nil
end

return ItemService
