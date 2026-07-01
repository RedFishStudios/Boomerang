--[[
  Serverside handling of equipping and unequipping tools
  Original author:
  @SixthAtom 13-03-2026
  Modified by
  @soulsplosion
]]

local EquipmentToolService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterService = require(ServerStorage.Server.Core.CharacterService)
local EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
local EquipmentService = require(ServerStorage.Server.Core.EquipmentService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SLOTS = EquipmentConstants.Slots

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Slot = EquipmentConstants.Slot
type SlotHandlers = { Apply: (player: Player, itemName: string) -> (), Remove: (player: Player, itemName: string) -> () }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local assets = ReplicatedStorage.Shared.Assets

local slotHandlers = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function removeFromBackpack(player: Player, itemName: string)
	for _, parent in next, { player:FindFirstChild("Backpack"), player.Character } do
		if not parent then
			continue
		end
		for _, v in next, parent:QueryDescendants(">Tool") do
			if v.Name == itemName then
				v:Destroy()
			end
		end
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EquipmentToolService.init()
	EquipmentService.ItemEquippedTasks:Add(function(player, slot, itemName)
		local handler = slotHandlers[slot]
		if handler then
			handler.Apply(player, itemName)
		end
	end)

	EquipmentService.ItemUnequippedTasks:Add(function(player, slot, itemName)
		local handler = slotHandlers[slot]
		if handler then
			handler.Remove(player, itemName)
		end
	end)

	CharacterService.CharacterAddedTasks:Add(function(_, player)
		for slot, handler in slotHandlers do
			local itemName = EquipmentService.getEquippedItemName(player, slot)
			if itemName then
				handler.Apply(player, itemName)
			end
		end
	end)
end

function EquipmentToolService.start()

end

function EquipmentToolService.test()

end

return EquipmentToolService
