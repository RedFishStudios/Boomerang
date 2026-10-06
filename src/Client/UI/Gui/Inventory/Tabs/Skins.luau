--[[
	Skins tab (Inventory)

	Description:
	The Skins tab of the Inventory menu: lists every boomerang skin (Shared/Referential/Skins).
	Clicking an owned skin equips it. Follows the InventoryTab shape in Inventory/init.luau.
]]

local SkinsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local SkinController = require(ReplicatedStorage.Client.Core.SkinController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SUBTITLE = "Boomerang Skin" -- // Skins have no rarity yet; shown under the name in the Detail panel

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
		if skin then
			table.insert(items, {
				Id = skinId,
				Name = skin.Name,
				Subtitle = SUBTITLE,
				Owned = SkinController.ownsSkin(skinId),
				Equipped = skinId == equippedSkinId,
			})
		end
	end

	return items
end

-- // Yields until the server answers
function SkinsTab.selectItem(skinId: string)
	if SkinController.ownsSkin(skinId) and SkinController.getEquippedSkinId() ~= skinId then
		SkinController.requestEquip(skinId)
	end
end

function SkinsTab.subscribe(onChanged: () -> ())
	SkinController.SkinGrantedTasks:Add(onChanged)
	SkinController.SkinEquippedTasks:Add(onChanged)
end

return SkinsTab
