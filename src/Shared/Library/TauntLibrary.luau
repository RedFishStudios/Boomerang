--[[
	TauntLibrary

	Description:
	Shared helpers for taunts (Shared/Referential/Taunts). Works out any player's equipped taunt from the `EquippedTaunt`
	attribute that TauntService sets on the Player (see CosmeticLibrary), and when taunting is allowed: only in the
	RoundEnded phase (round over, players still in the arena), with enough of it left for the whole taunt.
	Safe to use on both server and client.
]]

local TauntLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Taunts = require(ReplicatedStorage.Shared.Referential.Taunts)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

TauntLibrary.ATTRIBUTE_NAME = CosmeticLibrary.ATTRIBUTES.Taunt
TauntLibrary.DURATION = 6 -- // Every taunt lasts this long (the modules in Client/Core/TauntController/Taunts)
TauntLibrary.CHARACTER_ATTRIBUTE = "Taunting" -- // On the character while it taunts: the taunt id

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local defaultTauntId: string = "TooEasy"
for tauntId, taunt in Taunts do
	if taunt.Default then
		defaultTauntId = tauntId
		break
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function TauntLibrary.getTaunt(tauntId: string?): Taunts.Taunt?
	return if tauntId then Taunts[tauntId] else nil
end

function TauntLibrary.getDefaultId(): string
	return defaultTauntId
end

-- // Taunt ids sorted by their Order
function TauntLibrary.getSortedIds(): { string }
	local tauntIds = {}
	for tauntId in Taunts do
		table.insert(tauntIds, tauntId)
	end
	table.sort(tauntIds, function(a, b)
		return Taunts[a].Order < Taunts[b].Order
	end)
	return tauntIds
end

-- // Whether this saved data owns the taunt (the default is always owned)
function TauntLibrary.dataOwns(data: { OwnedTaunts: { [string]: boolean } }?, tauntId: string): boolean
	local taunt = Taunts[tauntId]
	if not taunt then
		return false
	end
	if taunt.Default then
		return true
	end
	return data ~= nil and data.OwnedTaunts ~= nil and data.OwnedTaunts[tauntId] == true
end

-- // The player's equipped taunt id; the default while it isn't set yet or isn't a real taunt
function TauntLibrary.getEquippedId(player: Player): string
	local tauntId = CosmeticLibrary.getEquippedRaw(player, "Taunt")
	if tauntId and Taunts[tauntId] then
		return tauntId
	end
	return defaultTauntId
end

-- // Whether a taunt can start now: in the RoundEnded phase, with at least DURATION of it left
function TauntLibrary.canTauntNow(): boolean
	local gameStateData = GameStateLibrary.getGameStateData()
	if gameStateData.GameplayPhase:Get() ~= GameplayPhases.RoundEnded then
		return false
	end
	local endsAt = gameStateData.CurrentTimerEndsAt:Get()
	return endsAt == nil or endsAt - workspace:GetServerTimeNow() >= TauntLibrary.DURATION
end

return TauntLibrary
