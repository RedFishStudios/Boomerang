--[[
  Handles equipping/unequipping of tools to the character
  - Boomerangs, shuricans, fans, special weapons, etc
]]

local ToolService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ItemService = require(ServerStorage.Server.Core.ItemService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local RoundService = require(ServerStorage.Server.Core.RoundService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ToolTask = (player: Player, itemName: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ToolService.ToolEquippedTasks = TasksList.new() :: TasksList.Id<ToolTask>
ToolService.ToolUnequippedTasks = TasksList.new() :: TasksList.Id<ToolTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ToolService.equipItem(player: Player, itemName: string): boolean
	if not ItemService.hasItem(player, itemName) then
      print("player doesn't own item: "..itemName)
		return false -- RETURN: Item isn't owned
	end

	local item = ItemConstants.getItem(itemName)
	if not item then
      print("invalid item: "..itemName)
		return false -- RETURN: Invalid item
	end

	local slot = item.EquipmentSlot
	if not slot then
      print("item is not equipable: "..itemName)
		return false -- RETURN: Item is not equipable
	end

	if ToolService.getEquippedItemName(player, slot) == itemName then
      print("item already equipped: "..itemName)
		return false -- RETURN: Already equipped
	end

	local data = PlayerDataService.get(player)
	if not data then
      print("no player data available for: "..player.Name)
		return false -- RETURN: No player data available
	end

	local previousItemName = data.EquippedItems[slot]
	if previousItemName then
		data.EquippedItems[slot] = nil
		ToolService.ToolUnequippedTasks:Execute("parallel", player, previousItemName)
	end

	data.EquippedItems[slot] = itemName
	ToolService.ToolEquippedTasks:Execute("parallel", player, itemName)

	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ToolService.init()
	ItemService.ItemAcquiredTasks:Add(function(player, itemName)
		local item = ItemConstants.getItem(itemName)
		if item and item.EquipmentSlot then
			ToolService.equipItem(player, itemName)
		end
	end)

   -- // Grant items to newly added players
   PlayerDataService.ProfileAddedTasks:Add(function(player: Player, data: ProfileTemplate.Template)
      if RoundService.isInRound() then
         if RoundService.canSpawnIntoRound(player) then
            -- TODO: read data to get their skin
            -- TODO: equip other tools besides boomerang
            ToolService.equipItem(player, "Boomerang")
         end
      end
   end)
end

function ToolService.start() end

function ToolService.test() end

return ToolService
