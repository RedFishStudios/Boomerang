--[[
	ChargeUpEffectLibrary

	Description:
	Shared helpers for charge up effects (Shared/Referential/ChargeUpEffects). Works out any player's equipped charge up effect
	and its logic module from the `EquippedChargeUpEffect` attribute that ChargeUpEffectService sets on the Player (see
	CosmeticLibrary). A charge up effect id is also the name of the module in Shared/Logics/ChargeUpEffects that animates it.
	Safe to use on both server and client (the logic modules are only required where something asks for them).
]]

local ChargeUpEffectLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChargeUpEffects = require(ReplicatedStorage.Shared.Referential.ChargeUpEffects)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // What a charge up effect is told every frame while its player is charging
export type ChargeUpFrame = {
	Alpha: number, -- // Charge progress, 0 (just started) to 1 (full charge)
	RootPart: BasePart, -- // The rendered character's HumanoidRootPart
	AimCFrame: CFrame, -- // The direction the player is aiming (their facing)
}

-- // A running charge up effect. Removed when the player stops charging (throw, cancel, death...); it must clean up everything it made.
export type ChargeUpEffectHandle = {
	update: (self: ChargeUpEffectHandle, frame: ChargeUpFrame) -> (),
	remove: (self: ChargeUpEffectHandle) -> (),
}

-- // The shape of a module in Shared/Logics/ChargeUpEffects. `apply` is called when a player begins charging, on every
-- // client (it only creates visuals; nothing here is authoritative), and returns the handle that animates and removes it.
export type ChargeUpEffectLogic = {
	apply: (player: Player, character: Model) -> ChargeUpEffectHandle,
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

ChargeUpEffectLibrary.ATTRIBUTE_NAME = CosmeticLibrary.ATTRIBUTES.ChargeUpEffect


-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local logicCache: { [string]: ChargeUpEffectLogic } = {}

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

-- // The logic module of a charge up effect id (Shared/Logics/ChargeUpEffects/<id>). An unknown id, or an effect without a
-- // module, uses the default effect's module, so a missing module never breaks aiming.
function ChargeUpEffectLibrary.getLogic(chargeUpEffectId: string): ChargeUpEffectLogic
	local cached = logicCache[chargeUpEffectId]
	if cached then
		return cached
	end

	local logicsFolder = ReplicatedStorage.Shared.Logics.ChargeUpEffects
	local logicModule = if ChargeUpEffects[chargeUpEffectId] then logicsFolder:FindFirstChild(chargeUpEffectId) else nil
	if not (logicModule and logicModule:IsA("ModuleScript")) then
		warn(`ChargeUpEffectLibrary: no logic module for charge up effect {chargeUpEffectId}, using the default`)
		logicModule = logicsFolder:FindFirstChild(defaultChargeUpEffectId)
	end

	local logic = require(logicModule :: ModuleScript) :: ChargeUpEffectLogic
	logicCache[chargeUpEffectId] = logic
	return logic
end

-- // The logic module of the charge up effect the player has equipped
function ChargeUpEffectLibrary.getLogicFor(player: Player): ChargeUpEffectLogic
	return ChargeUpEffectLibrary.getLogic(ChargeUpEffectLibrary.getEquippedId(player))
end

return ChargeUpEffectLibrary
