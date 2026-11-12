--[[
	Taunts tab (Inventory)

	Description:
	Inventory tab listing the taunts the player owns (Shared/Referential/Taunts).
	Equip equips the selected taunt. Follows the InventoryTab shape in Inventory/init.luau.
]]

local TauntsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TauntLibrary = require(ReplicatedStorage.Shared.Library.TauntLibrary)
local TauntController = require(ReplicatedStorage.Client.Core.TauntController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_RARITY = "Common" -- // When the taunt has no Rarity

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

TauntsTab.Title = "My Taunts"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function TauntsTab.getItems(includeUnowned: boolean?)
	local equippedId = TauntController.getEquippedId()
	local items = {}

	for _, tauntId in TauntLibrary.getSortedIds() do
		local taunt = TauntLibrary.getTaunt(tauntId)
		if taunt and (TauntController.ownsTaunt(tauntId) or (includeUnowned and not taunt.OffSale)) then
			table.insert(items, {
				Id = tauntId,
				Name = taunt.Name,
				Rarity = taunt.Rarity or DEFAULT_RARITY,
				IconImage = taunt.Icon,
				IconGlyph = taunt.PlaceholderGlyph or "?",
				Owned = TauntController.ownsTaunt(tauntId),
				Equipped = tauntId == equippedId,
				Source = if taunt.Default then "Default" elseif taunt.OffSale then "Special" else "Cosmetics Shop",
			})
		end
	end

	return items
end

-- // Yields until the server answers
function TauntsTab.equipItem(tauntId: string)
	if TauntController.ownsTaunt(tauntId) and TauntController.getEquippedId() ~= tauntId then
		TauntController.requestEquip(tauntId)
	end
end

function TauntsTab.subscribe(onChanged: () -> ())
	TauntController.TauntGrantedTasks:Add(onChanged)
	TauntController.TauntEquippedTasks:Add(onChanged)
end

return TauntsTab
