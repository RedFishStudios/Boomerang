--[[
	Skins tab (Inventory)

	Description:
	Inventory tab listing the boomerang skins the player owns (Shared/Referential/Skins).
	A skin's rarity is the Rarity of its model's entry in Shared/Constants/Tools.
	Equip equips the selected skin. Follows the InventoryTab shape in Inventory/init.luau.
]]

local SkinsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local SkinController = require(ReplicatedStorage.Client.Core.SkinController)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local CrateLibrary = require(ReplicatedStorage.Shared.Library.CrateLibrary)

-- // Where a weapon comes from (shown in the Index): the crate that can give it, else how else it's owned
local function getSource(skinId: string): string
	local skin = SkinLibrary.getSkin(skinId)
	if skin and skin.Default then
		return "Default"
	end
	for _, crateId in CrateLibrary.getSortedCrateIds() do
		local crate = CrateLibrary.getCrate(crateId)
		if crate and not crate.OffSale then
			for _, entry in CrateLibrary.getEntries(crateId) do
				if entry.SkinId == skinId then
					return crate.Name
				end
			end
		end
	end
	return if skin and skin.OffSale then "Special" else "Unavailable"
end

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_RARITY = "Common" -- // When the skin's tool has no Rarity

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SkinsTab.Title = "My Weapons"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SkinsTab.getItems(includeUnowned: boolean?)
	local equippedSkinId = SkinController.getEquippedSkinId()
	local items = {}

	for _, skinId in SkinLibrary.getSortedSkinIds() do
		local skin = SkinLibrary.getSkin(skinId)
		if skin and (SkinController.ownsSkin(skinId) or (includeUnowned and not skin.OffSale)) then
			local tool = Tools[skin.Model]
			table.insert(items, {
				Id = skinId,
				Name = skin.Name,
				Rarity = (tool and tool.Rarity) or DEFAULT_RARITY,
				ModelName = skin.Model,
				Owned = SkinController.ownsSkin(skinId),
				Equipped = skinId == equippedSkinId,
				Source = getSource(skinId),
			})
		end
	end

	return items
end

-- // Yields until the server answers
function SkinsTab.equipItem(skinId: string)
	if SkinController.ownsSkin(skinId) and SkinController.getEquippedSkinId() ~= skinId then
		SkinController.requestEquip(skinId)
	end
end

function SkinsTab.subscribe(onChanged: () -> ())
	SkinController.SkinGrantedTasks:Add(onChanged)
	SkinController.SkinEquippedTasks:Add(onChanged)
end

return SkinsTab
