--[[
	Strikes tab (Inventory)

	Description:
	Inventory tab listing the elimination effects ("Strike Effects") the player owns (Shared/Referential/ElimEffects).
	Equip equips the selected effect. Follows the InventoryTab shape in Inventory/init.luau.
]]

local StrikesTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElimEffectLibrary = require(ReplicatedStorage.Shared.Library.ElimEffectLibrary)
local ElimEffectController = require(ReplicatedStorage.Client.Core.ElimEffectController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_RARITY = "Common" -- // When the effect has no Rarity

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

StrikesTab.Title = "My Strike Effects"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function StrikesTab.getItems()
	local equippedId = ElimEffectController.getEquippedId()
	local items = {}

	for _, elimEffectId in ElimEffectLibrary.getSortedIds() do
		local elimEffect = ElimEffectLibrary.getElimEffect(elimEffectId)
		if elimEffect and ElimEffectController.ownsElimEffect(elimEffectId) then
			table.insert(items, {
				Id = elimEffectId,
				Name = elimEffect.Name,
				Rarity = elimEffect.Rarity or DEFAULT_RARITY,
				IconImage = elimEffect.Icon,
				IconGlyph = elimEffect.PlaceholderGlyph or "?",
				Owned = true,
				Equipped = elimEffectId == equippedId,
			})
		end
	end

	return items
end

-- // Yields until the server answers
function StrikesTab.equipItem(elimEffectId: string)
	if ElimEffectController.ownsElimEffect(elimEffectId) and ElimEffectController.getEquippedId() ~= elimEffectId then
		ElimEffectController.requestEquip(elimEffectId)
	end
end

function StrikesTab.subscribe(onChanged: () -> ())
	ElimEffectController.ElimEffectGrantedTasks:Add(onChanged)
	ElimEffectController.ElimEffectEquippedTasks:Add(onChanged)
end

return StrikesTab
