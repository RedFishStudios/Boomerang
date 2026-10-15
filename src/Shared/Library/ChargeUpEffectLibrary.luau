--[[
	ChargeUpEffectLibrary

	Description:
	Shared helpers for charge up effects (Shared/Referential/ChargeUpEffects). Works out any player's equipped charge up effect and its
	template from the `EquippedChargeUpEffect` attribute that ChargeUpEffectService sets on the Player (see CosmeticLibrary).
	Safe to use on both server and client.
]]

local ChargeUpEffectLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChargeUpEffects = require(ReplicatedStorage.Shared.Referential.ChargeUpEffects)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

ChargeUpEffectLibrary.ATTRIBUTE_NAME = CosmeticLibrary.ATTRIBUTES.ChargeUpEffect

local LEGACY_TEMPLATE_NAME = "AimArrow" -- // The template's name before charge up effects were cosmetics; a last-resort fallback

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local defaultChargeUpEffectId: string = "DefaultChargeUpEffect"
for chargeUpEffectId, chargeUpEffect in ChargeUpEffects do
	if chargeUpEffect.Default then
		defaultChargeUpEffectId = chargeUpEffectId
		break
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ChargeUpEffectLibrary.getChargeUpEffect(chargeUpEffectId: string?): ChargeUpEffects.ChargeUpEffect?
	return if chargeUpEffectId then ChargeUpEffects[chargeUpEffectId] else nil
end

function ChargeUpEffectLibrary.getDefaultId(): string
	return defaultChargeUpEffectId
end

-- // Charge up effect ids sorted by their Order
function ChargeUpEffectLibrary.getSortedIds(): { string }
	local chargeUpEffectIds = {}
	for chargeUpEffectId in ChargeUpEffects do
		table.insert(chargeUpEffectIds, chargeUpEffectId)
	end
	table.sort(chargeUpEffectIds, function(a, b)
		return ChargeUpEffects[a].Order < ChargeUpEffects[b].Order
	end)
	return chargeUpEffectIds
end

-- // Whether this saved data owns the charge up effect (default arrows are always owned)
function ChargeUpEffectLibrary.dataOwns(data: { OwnedChargeUpEffects: { [string]: boolean } }?, chargeUpEffectId: string): boolean
	local chargeUpEffect = ChargeUpEffects[chargeUpEffectId]
	if not chargeUpEffect then
		return false
	end
	if chargeUpEffect.Default then
		return true
	end
	return data ~= nil and data.OwnedChargeUpEffects ~= nil and data.OwnedChargeUpEffects[chargeUpEffectId] == true
end

-- // The player's equipped charge up effect id; the default while it isn't set yet or isn't a real charge up effect
function ChargeUpEffectLibrary.getEquippedId(player: Player): string
	local chargeUpEffectId = CosmeticLibrary.getEquippedRaw(player, "ChargeUpEffect")
	if chargeUpEffectId and ChargeUpEffects[chargeUpEffectId] then
		return chargeUpEffectId
	end
	return defaultChargeUpEffectId
end

-- // The template (a Model in Shared/Assets/Gui) for a charge up effect id. Falls back to the default arrow's template, then
-- // to the old "AimArrow" template, so a missing asset never breaks aiming.
function ChargeUpEffectLibrary.getTemplate(chargeUpEffectId: string): Model
	local guiAssets = ReplicatedStorage.Shared.Assets.Gui
	local chargeUpEffect = ChargeUpEffects[chargeUpEffectId]
	local template = chargeUpEffect and guiAssets:FindFirstChild(chargeUpEffect.Asset)
	if not template then
		warn(`ChargeUpEffectLibrary: no template for charge up effect {chargeUpEffectId}, using the default`)
		local default = ChargeUpEffects[defaultChargeUpEffectId]
		template = guiAssets:FindFirstChild(default.Asset) or guiAssets:FindFirstChild(LEGACY_TEMPLATE_NAME)
	end
	return template :: Model
end

-- // The template of the charge up effect the player has equipped
function ChargeUpEffectLibrary.getTemplateFor(player: Player): Model
	return ChargeUpEffectLibrary.getTemplate(ChargeUpEffectLibrary.getEquippedId(player))
end

return ChargeUpEffectLibrary
