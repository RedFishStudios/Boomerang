--[[
	Skins tab (Inventory)

	Description:
	The Skins tab of the Inventory menu: lists the boomerang skins the player owns (Shared/Referential/Skins).
	A skin's rarity is the Rarity of its model's entry in Shared/Constants/Tools.
	Equip equips the selected skin. Follows the InventoryTab shape in Inventory/init.luau.
]]

local SkinsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local SkinController = require(ReplicatedStorage.Client.Core.SkinController)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_RARITY = "Common" -- // When the skin's tool has no Rarity

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SkinsTab.Title = "Your Skins"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SkinsTab.getItems()
	local equippedSkinId = SkinController.getEquippedSkinId()
	local items = {}

	for _, skinId in SkinLibrary.getSortedSkinIds() do
		local skin = SkinLibrary.getSkin(skinId)
		if skin and SkinController.ownsSkin(skinId) then
			local tool = Tools[skin.Model]
			table.insert(items, {
				Id = skinId,
				Name = skin.Name,
				Rarity = (tool and tool.Rarity) or DEFAULT_RARITY,
				ModelName = skin.Model,
				Owned = true,
				Equipped = skinId == equippedSkinId,
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
