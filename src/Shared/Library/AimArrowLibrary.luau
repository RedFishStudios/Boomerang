--[[
	AimArrowLibrary

	Description:
	Shared helpers for aim arrows (Shared/Referential/AimArrows). Works out any player's equipped aim arrow and its
	template from the `EquippedAimArrow` attribute that AimArrowService sets on the Player (see CosmeticLibrary).
	Safe to use on both server and client.
]]

local AimArrowLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimArrows = require(ReplicatedStorage.Shared.Referential.AimArrows)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

AimArrowLibrary.ATTRIBUTE_NAME = CosmeticLibrary.ATTRIBUTES.AimArrow

local LEGACY_TEMPLATE_NAME = "AimArrow" -- // The template's name before aim arrows were cosmetics; a last-resort fallback

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local defaultAimArrowId: string = "DefaultAimArrow"
for aimArrowId, aimArrow in AimArrows do
	if aimArrow.Default then
		defaultAimArrowId = aimArrowId
		break
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function AimArrowLibrary.getAimArrow(aimArrowId: string?): AimArrows.AimArrow?
	return if aimArrowId then AimArrows[aimArrowId] else nil
end

function AimArrowLibrary.getDefaultId(): string
	return defaultAimArrowId
end

-- // Aim arrow ids sorted by their Order
function AimArrowLibrary.getSortedIds(): { string }
	local aimArrowIds = {}
	for aimArrowId in AimArrows do
		table.insert(aimArrowIds, aimArrowId)
	end
	table.sort(aimArrowIds, function(a, b)
		return AimArrows[a].Order < AimArrows[b].Order
	end)
	return aimArrowIds
end

-- // Whether this saved data owns the aim arrow (default arrows are always owned)
function AimArrowLibrary.dataOwns(data: { OwnedAimArrows: { [string]: boolean } }?, aimArrowId: string): boolean
	local aimArrow = AimArrows[aimArrowId]
	if not aimArrow then
		return false
	end
	if aimArrow.Default then
		return true
	end
	return data ~= nil and data.OwnedAimArrows ~= nil and data.OwnedAimArrows[aimArrowId] == true
end

-- // The player's equipped aim arrow id; the default while it isn't set yet or isn't a real aim arrow
function AimArrowLibrary.getEquippedId(player: Player): string
	local aimArrowId = CosmeticLibrary.getEquippedRaw(player, "AimArrow")
	if aimArrowId and AimArrows[aimArrowId] then
		return aimArrowId
	end
	return defaultAimArrowId
end

-- // The template (a Model in Shared/Assets/Gui) for an aim arrow id. Falls back to the default arrow's template, then
-- // to the old "AimArrow" template, so a missing asset never breaks aiming.
function AimArrowLibrary.getTemplate(aimArrowId: string): Model
	local guiAssets = ReplicatedStorage.Shared.Assets.Gui
	local aimArrow = AimArrows[aimArrowId]
	local template = aimArrow and guiAssets:FindFirstChild(aimArrow.Asset)
	if not template then
		warn(`AimArrowLibrary: no template for aim arrow {aimArrowId}, using the default`)
		local default = AimArrows[defaultAimArrowId]
		template = guiAssets:FindFirstChild(default.Asset) or guiAssets:FindFirstChild(LEGACY_TEMPLATE_NAME)
	end
	return template :: Model
end

-- // The template of the aim arrow the player has equipped
function AimArrowLibrary.getTemplateFor(player: Player): Model
	return AimArrowLibrary.getTemplate(AimArrowLibrary.getEquippedId(player))
end

return AimArrowLibrary
