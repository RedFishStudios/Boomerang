--[[
	Arrows tab (Inventory)

	Description:
	The Arrows tab of the Inventory menu: lists the aim arrows the player owns (Shared/Referential/AimArrows).
	Equip equips the selected arrow. Aim arrows have no GUI image yet, so their listings show a placeholder label
	(ItemViewport.setImagePlaceholder) until an arrow's Icon is set. Follows the InventoryTab shape in Inventory/init.luau.
]]

local ArrowsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimArrowLibrary = require(ReplicatedStorage.Shared.Library.AimArrowLibrary)
local AimArrowController = require(ReplicatedStorage.Client.Core.AimArrowController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_RARITY = "Common" -- // When the aim arrow has no Rarity

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ArrowsTab.Title = "Your Aim Arrows"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ArrowsTab.getItems()
	local equippedId = AimArrowController.getEquippedId()
	local items = {}

	for _, aimArrowId in AimArrowLibrary.getSortedIds() do
		local aimArrow = AimArrowLibrary.getAimArrow(aimArrowId)
		if aimArrow and AimArrowController.ownsAimArrow(aimArrowId) then
			table.insert(items, {
				Id = aimArrowId,
				Name = aimArrow.Name,
				Rarity = aimArrow.Rarity or DEFAULT_RARITY,
				IconImage = aimArrow.Icon,
				IconGlyph = aimArrow.PlaceholderGlyph or "?",
				Owned = true,
				Equipped = aimArrowId == equippedId,
			})
		end
	end

	return items
end

-- // Yields until the server answers
function ArrowsTab.equipItem(aimArrowId: string)
	if AimArrowController.ownsAimArrow(aimArrowId) and AimArrowController.getEquippedId() ~= aimArrowId then
		AimArrowController.requestEquip(aimArrowId)
	end
end

function ArrowsTab.subscribe(onChanged: () -> ())
	AimArrowController.AimArrowGrantedTasks:Add(onChanged)
	AimArrowController.AimArrowEquippedTasks:Add(onChanged)
end

return ArrowsTab
