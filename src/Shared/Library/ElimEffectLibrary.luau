--[[
	ElimEffectLibrary

	Description:
	Shared helpers for elimination effects ("Strike Effects", Shared/Referential/ElimEffects). Works out any player's
	equipped effect from the `EquippedElimEffect` attribute that ElimEffectService sets on the Player (see
	CosmeticLibrary).
	A lethal hit by another player marks the victim's Humanoid with the eliminator's effect (markLethalHit, called by
	CombatLibrary.applyDamageToHumanoid before the damage). The mark replicates with the Humanoid, so every client knows
	before it sees the death: CharacterRenderController skips the ragdoll for a marked body, and ElimEffectService plays
	the effect when the Humanoid dies.
	Safe to use on both server and client.
]]

local ElimEffectLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ElimEffects = require(ReplicatedStorage.Shared.Referential.ElimEffects)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

ElimEffectLibrary.ATTRIBUTE_NAME = CosmeticLibrary.ATTRIBUTES.ElimEffect
ElimEffectLibrary.HUMANOID_ATTRIBUTE = "ElimEffect" -- // On the eliminated player's Humanoid: the effect id that will play

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isServer = RunService:IsServer()

local defaultElimEffectId: string = "DefaultElimEffect"
for elimEffectId, elimEffect in ElimEffects do
	if elimEffect.Default then
		defaultElimEffectId = elimEffectId
		break
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ElimEffectLibrary.getElimEffect(elimEffectId: string?): ElimEffects.ElimEffect?
	return if elimEffectId then ElimEffects[elimEffectId] else nil
end

function ElimEffectLibrary.getDefaultId(): string
	return defaultElimEffectId
end

-- // Elimination effect ids sorted by their Order
function ElimEffectLibrary.getSortedIds(): { string }
	local elimEffectIds = {}
	for elimEffectId in ElimEffects do
		table.insert(elimEffectIds, elimEffectId)
	end
	table.sort(elimEffectIds, function(a, b)
		return ElimEffects[a].Order < ElimEffects[b].Order
	end)
	return elimEffectIds
end

-- // Whether this saved data owns the effect (the default is always owned)
function ElimEffectLibrary.dataOwns(data: { OwnedElimEffects: { [string]: boolean } }?, elimEffectId: string): boolean
	local elimEffect = ElimEffects[elimEffectId]
	if not elimEffect then
		return false
	end
	if elimEffect.Default then
		return true
	end
	return data ~= nil and data.OwnedElimEffects ~= nil and data.OwnedElimEffects[elimEffectId] == true
end

-- // The player's equipped effect id; the default while it isn't set yet or isn't a real effect
function ElimEffectLibrary.getEquippedId(player: Player): string
	local elimEffectId = CosmeticLibrary.getEquippedRaw(player, "ElimEffect")
	if elimEffectId and ElimEffects[elimEffectId] then
		return elimEffectId
	end
	return defaultElimEffectId
end

-- // Whether an effect id plays something (the default doesn't)
function ElimEffectLibrary.playsEffect(elimEffectId: string?): boolean
	return elimEffectId ~= nil and ElimEffects[elimEffectId] ~= nil and elimEffectId ~= defaultElimEffectId
end

-- // The effect marked on a Humanoid by a lethal hit, or nil
function ElimEffectLibrary.getMarked(humanoid: Humanoid): string?
	local elimEffectId = humanoid:GetAttribute(ElimEffectLibrary.HUMANOID_ATTRIBUTE)
	return if type(elimEffectId) == "string" and ElimEffectLibrary.playsEffect(elimEffectId) then elimEffectId else nil
end

-- // Server only. Called before damage is applied: if the hit will eliminate the Humanoid and comes from another
-- // player with an effect equipped, marks the Humanoid with that effect.
function ElimEffectLibrary.markLethalHit(humanoid: Humanoid, damageAmount: number, killer: Player?)
	if not isServer or not killer or humanoid.Health <= 0 or damageAmount < humanoid.Health then
		return
	end
	local character = humanoid.Parent
	if character and character:FindFirstChildOfClass("ForceField") then
		return -- // TakeDamage does nothing through a ForceField
	end
	local elimEffectId = ElimEffectLibrary.getEquippedId(killer)
	if ElimEffectLibrary.playsEffect(elimEffectId) then
		humanoid:SetAttribute(ElimEffectLibrary.HUMANOID_ATTRIBUTE, elimEffectId)
	end
end

return ElimEffectLibrary
