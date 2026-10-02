--[[
	ItemController

	Description:
	Client-side view of the local player's `Inventory` (item id -> amount owned), kept up to date by PlayerDataController.
	Item data comes from Shared/Referential/Items.

	Author:
	@SixthAtom
]]

local ItemController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ItemEventTask = (itemId: string, deltaAmount: number) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-- // Last known amounts, since UpdatedTasks only provides the new value
local knownAmounts: { [string]: number } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ItemController.ItemGrantedTasks = TasksList.new() :: TasksList.TasksList<ItemEventTask>
ItemController.ItemConsumedTasks = TasksList.new() :: TasksList.TasksList<ItemEventTask>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ItemController.getInventory(): { [string]: number }
	local data = PlayerDataController.get()
	return if data then data.Inventory else {}
end

function ItemController.getAmount(itemId: string): number
	return ItemController.getInventory()[itemId] or 0
end

function ItemController.hasItem(itemId: string): boolean
	return ItemController.getAmount(itemId) > 0
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ItemController.init()
	PlayerDataController.getAsync(function(data)
		for itemId, amount in data.Inventory do
			knownAmounts[itemId] = amount
		end
	end)

	PlayerDataController.UpdatedTasks:Add(function(index, value, path)
		if path[1] ~= "Inventory" or #path ~= 1 or type(index) ~= "string" then
			return
		end

		local previous = knownAmounts[index] or 0
		local current = if type(value) == "number" then value else 0
		knownAmounts[index] = if current > 0 then current else nil

		if current > previous then
			ItemController.ItemGrantedTasks:Execute("parallel", index, current - previous)
		elseif current < previous then
			ItemController.ItemConsumedTasks:Execute("parallel", index, previous - current)
		end
	end)
end

return ItemController
