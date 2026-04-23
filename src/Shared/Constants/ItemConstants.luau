local ItemConstants = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConstants = require(ReplicatedStorage.Shared.Constants.EconomyConstants)
local EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
local CRC32C = require(ReplicatedStorage.Shared.Hashing.CRC32C)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CURRENCIES = EconomyConstants.Currencies
local EQUIPMENT_SLOTS = EquipmentConstants.Slots

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ItemId = string
export type Category = keyof<typeof(ItemConstants.Categories)>
export type OwnershipMode = keyof<typeof(ItemConstants.OwnershipModes)>

export type ItemBase = {
	Name: string,
	DisplayName: string,
	Category: Category,
	OwnershipMode: OwnershipMode,
	Price: EconomyConstants.Price,
	EquipmentSlot: EquipmentConstants.Slot?,

	Description: string?,
	Icon: string?,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local categories = {
	Car = "Car",
	Skin = "Skin",
	Cosmetic = "Cosmetic",
	Gun = "Gun",
}

local ownershipModes = {
	Permanent = "Permanent",
	Consumable = "Consumable",
}

local itemsByCategory: { [Category]: { [string]: ItemBase } } = {}
local itemsByHash: { [number]: ItemBase } = {}

local itemsByName: { [string]: ItemBase } = {
	--[[
      
      -- Cars
      Test = {
         Name = "Test",
         DisplayName = "Test Car",
         Category = categories.Car,
         OwnershipMode = ownershipModes.Permanent,
         Price = { Currency = CURRENCIES.Free },
      },

      Lada = {
         Name = "Lada",
         DisplayName = "Lada",
         Category = categories.Car,
         OwnershipMode = ownershipModes.Permanent,
         Price = { Currency = CURRENCIES.Free },
      },

      -- Guns
      M1911 = {
         Name = "M1911",
         DisplayName = "M1911",
         Category = categories.Gun,
         EquipmentSlot = EQUIPMENT_SLOTS.Gun,
         OwnershipMode = ownershipModes.Permanent,
         Price = { Currency = CURRENCIES.Free },
      },
      
   --]]
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ItemConstants.Categories = categories
ItemConstants.OwnershipModes = ownershipModes

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ItemConstants.getItem(itemName: string)
	return itemsByName[itemName]
end

function ItemConstants.getItemFromHash(hash: number)
	return itemsByHash[hash]
end

function ItemConstants.getItemsInCategory(category: Category)
	return itemsByCategory[category]
end

function ItemConstants.getAllItems()
	return itemsByName
end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

for itemName, item in itemsByName do
	local bucket = itemsByCategory[item.Category]
	if not bucket then
		bucket = {}
		itemsByCategory[item.Category] = bucket
	end

	local hash = CRC32C(buffer.fromstring(itemName))
	if itemsByHash[hash] then
		error(`Duplicate hash {hash} on {itemName} & {itemsByHash[hash].Name}`)
	end

	itemsByHash[hash] = item
	bucket[itemName] = item
end

return ItemConstants
