--[[
	Arrows tab (Inventory)

	Description:
	The Arrows tab of the Inventory menu: lists the charge up effects the player owns (Shared/Referential/ChargeUpEffects).
	Equip equips the selected arrow. Charge up effects have no GUI image yet, so their listings show a placeholder label
	(ItemViewport.setImagePlaceholder) until an arrow's Icon is set. Follows the InventoryTab shape in Inventory/init.luau.
]]

local ArrowsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChargeUpEffectLibrary = require(ReplicatedStorage.Shared.Library.ChargeUpEffectLibrary)
local ChargeUpEffectController = require(ReplicatedStorage.Client.Core.ChargeUpEffectController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_RARITY = "Common" -- // When the charge up effect has no Rarity

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ArrowsTab.Title = "My Charge Up Effects"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ArrowsTab.getItems()
	local equippedId = ChargeUpEffectController.getEquippedId()
	local items = {}

	for _, chargeUpEffectId in ChargeUpEffectLibrary.getSortedIds() do
		local chargeUpEffect = ChargeUpEffectLibrary.getChargeUpEffect(chargeUpEffectId)
		if chargeUpEffect and ChargeUpEffectController.ownsChargeUpEffect(chargeUpEffectId) then
			table.insert(items, {
				Id = chargeUpEffectId,
				Name = chargeUpEffect.Name,
				Rarity = chargeUpEffect.Rarity or DEFAULT_RARITY,
				IconImage = chargeUpEffect.Icon,
				IconGlyph = chargeUpEffect.PlaceholderGlyph or "?",
				Owned = true,
				Equipped = chargeUpEffectId == equippedId,
			})
		end
	end

	return items
end

-- // Yields until the server answers
function ArrowsTab.equipItem(chargeUpEffectId: string)
	if ChargeUpEffectController.ownsChargeUpEffect(chargeUpEffectId) and ChargeUpEffectController.getEquippedId() ~= chargeUpEffectId then
		ChargeUpEffectController.requestEquip(chargeUpEffectId)
	end
end

function ArrowsTab.subscribe(onChanged: () -> ())
	ChargeUpEffectController.ChargeUpEffectGrantedTasks:Add(onChanged)
	ChargeUpEffectController.ChargeUpEffectEquippedTasks:Add(onChanged)
end

return ArrowsTab
