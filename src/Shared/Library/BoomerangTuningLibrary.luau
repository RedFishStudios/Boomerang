--[[
	BoomerangTuningLibrary

	Description:
	Live, per-tool overrides of the boomerang feel values, set from Cmdr (T-054: "tuneboomerang", "resetboomerang").
	Overrides are stored as attributes on ReplicatedStorage, so they replicate to every client and the client's
	prediction keeps matching the server. They last for the server session only (never saved).
	Without an override, each value falls back to its default in Tools / GlobalConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local WalkSpeedLibrary = require(ReplicatedStorage.Shared.Library.WalkSpeedLibrary)

local BoomerangTuningLibrary = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Kept short: Roblox attribute names are limited to 50 characters, and "BoomerangTuning_ClassicBoomerang_RecallAcceleration"
-- // was 51 (T-065). Names look like "BT_ClassicBoomerang_RecallAcceleration".
local ATTRIBUTE_PREFIX = "BT"

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Setting = "ThrowSpeed" | "MinEnergy" | "MaxEnergy" | "EnergyPerStud" | "BounceEnergyCost" | "PlayerHitEnergyCost" | "ClashEnergyCost" | "RecallSpeed" | "RecallAcceleration" | "RecallRampTime" | "RecallRampPower" | "RecallBounceRecovery" | "DyingSpeedMultiplier" | "ChargeTime" | "AimWalkSpeed" | "TelekinesisInfluence"

type SettingInfo = {
	Description: string,
	getDefault: (toolData: Tools.Tool?) -> number,
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-- // Every tunable value, in display order. The names are what Cmdr shows (and autocompletes).
BoomerangTuningLibrary.SETTING_ORDER = { "ThrowSpeed", "MinEnergy", "MaxEnergy", "EnergyPerStud", "BounceEnergyCost", "PlayerHitEnergyCost", "ClashEnergyCost", "RecallSpeed", "RecallAcceleration", "RecallRampTime", "RecallRampPower", "RecallBounceRecovery", "DyingSpeedMultiplier", "ChargeTime", "AimWalkSpeed", "TelekinesisInfluence" } :: { Setting }

BoomerangTuningLibrary.SETTINGS = {
	ThrowSpeed = {
		Description = "maximum throw speed (studs/s)",
		getDefault = function(toolData)
			return toolData.Boomerang.Speed
		end,
	},
	-- // Energy (see GlobalConfig.BoomerangMinEnergy). Min/Max only apply to the next throw; the rest apply live.
	MinEnergy = {
		Description = "energy of a throw with no charge (applies from the next throw)",
		getDefault = function(_toolData)
			return GlobalConfig.BoomerangMinEnergy
		end,
	},
	MaxEnergy = {
		Description = "energy of a throw charged for a full ChargeTime (applies from the next throw)",
		getDefault = function(_toolData)
			return GlobalConfig.BoomerangMaxEnergy
		end,
	},
	EnergyPerStud = {
		Description = "energy lost per stud flown",
		getDefault = function(_toolData)
			return GlobalConfig.BoomerangEnergyPerStud
		end,
	},
	BounceEnergyCost = {
		Description = "energy lost when bouncing off a wall",
		getDefault = function(_toolData)
			return GlobalConfig.BoomerangBounceEnergyCost
		end,
	},
	PlayerHitEnergyCost = {
		Description = "energy lost when striking a player",
		getDefault = function(_toolData)
			return GlobalConfig.BoomerangPlayerHitEnergyCost
		end,
	},
	ClashEnergyCost = {
		Description = "energy lost when striking another boomerang mid-air (a clash)",
		getDefault = function(_toolData)
			return GlobalConfig.BoomerangClashEnergyCost
		end,
	},
	RecallSpeed = {
		Description = "maximum manual recall speed (studs/s)",
		getDefault = function(toolData)
			return toolData.Boomerang.ManualRecallSpeed
		end,
	},
	RecallAcceleration = {
		Description = "how quickly a manual recall turns toward the player (1 = normal recall)",
		getDefault = function(_toolData)
			return GlobalConfig.ManualRecallMomentumMultiplier
		end,
	},
	-- // Manual recall speed-up curve (see GlobalConfig.ManualRecallRampSeconds)
	RecallRampTime = {
		Description = "seconds for a manual recall to build up to max speed",
		getDefault = function(_toolData)
			return GlobalConfig.ManualRecallRampSeconds
		end,
	},
	RecallRampPower = {
		Description = "manual recall speed-up curve (1 = steady, higher = slower start and sharper surge)",
		getDefault = function(_toolData)
			return GlobalConfig.ManualRecallRampPower
		end,
	},
	-- // A returning boomerang's bounce momentum fades back into steering toward the player over this long
	RecallBounceRecovery = {
		Description = "seconds for a returning boomerang's bounce momentum to fade back into heading for the player",
		getDefault = function(_toolData)
			return GlobalConfig.BoomerangRecallBounceRecoverySeconds
		end,
	},
	-- // How fast a dying boomerang stops sliding and falls (Clashed.luau; client and server both read it)
	DyingSpeedMultiplier = {
		Description = "how much faster a dying boomerang loses its slide and falls (1 = original pace)",
		getDefault = function(_toolData)
			return GlobalConfig.DyingSpeedMultiplier
		end,
	},
	-- // T-066: seconds of holding aim until the throw is at max power (also the aim arrow's fill time)
	ChargeTime = {
		Description = "seconds of charging until the throw is at max power",
		getDefault = function(_toolData)
			return GlobalConfig.ChargeTime
		end,
	},
	-- // T-067: the player's walk speed while aiming/charging a throw
	AimWalkSpeed = {
		Description = "player walk speed while aiming/charging (studs/s)",
		getDefault = function(_toolData)
			return WalkSpeedLibrary.getDefault() * GlobalConfig.AimingWalkSpeedMultiplier
		end,
	},
	-- // T-077: how strongly a Telekinesis boomerang turns toward the owner's aim each second (bias, not full control)
	TelekinesisInfluence = {
		Description = "how strongly a Telekinesis boomerang turns toward the owner's aim (per second; a bias, not full control)",
		getDefault = function(_toolData)
			return GlobalConfig.TelekinesisSteerInfluence
		end,
	},
} :: { [Setting]: SettingInfo }

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getAttributeName(toolId: string, setting: Setting): string
	local name = `{ATTRIBUTE_PREFIX}_{toolId}_{setting}`
	assert(#name <= 50, `BoomerangTuningLibrary: attribute name too long ({name}); shorten the tool id or setting name`)
	return name
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The value from Tools / GlobalConfig, ignoring any override
function BoomerangTuningLibrary.getDefault(toolId: string, setting: Setting): number
	return BoomerangTuningLibrary.SETTINGS[setting].getDefault(Tools[toolId])
end

-- // The value currently in use for this tool (the override if there is one, otherwise the default)
function BoomerangTuningLibrary.get(toolId: string, setting: Setting): number
	local override = ReplicatedStorage:GetAttribute(getAttributeName(toolId, setting))
	if type(override) == "number" then
		return override
	end
	return BoomerangTuningLibrary.getDefault(toolId, setting)
end

-- // Like get, but safe for a tool id from the client or with no tool: falls back to the default for an unknown tool.
-- // Only for settings whose default doesn't depend on the tool (ChargeTime, AimWalkSpeed).
function BoomerangTuningLibrary.getForAnyTool(toolId: string?, setting: Setting): number
	if toolId and Tools[toolId] and Tools[toolId].Boomerang then
		return BoomerangTuningLibrary.get(toolId, setting)
	end
	return BoomerangTuningLibrary.SETTINGS[setting].getDefault(nil)
end

function BoomerangTuningLibrary.isOverridden(toolId: string, setting: Setting): boolean
	return ReplicatedStorage:GetAttribute(getAttributeName(toolId, setting)) ~= nil
end

-- // Server only. A nil value removes the override (back to the default).
function BoomerangTuningLibrary.set(toolId: string, setting: Setting, value: number?)
	assert(RunService:IsServer(), "BoomerangTuningLibrary.set is server only")
	assert(Tools[toolId] and Tools[toolId].Boomerang, `BoomerangTuningLibrary: {toolId} is not a boomerang tool`)
	assert(BoomerangTuningLibrary.SETTINGS[setting], `BoomerangTuningLibrary: unknown setting {setting}`)
	ReplicatedStorage:SetAttribute(getAttributeName(toolId, setting), value)
end

return BoomerangTuningLibrary
