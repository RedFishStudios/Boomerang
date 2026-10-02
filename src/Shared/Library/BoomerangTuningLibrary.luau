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

local BoomerangTuningLibrary = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local ATTRIBUTE_PREFIX = "BoomerangTuning"

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Setting = "ThrowSpeed" | "ThrowDistance" | "RecallSpeed" | "RecallAcceleration"

type SettingInfo = {
	Description: string,
	getDefault: (toolData: Tools.Tool) -> number,
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-- // Every tunable value, in display order. The names are what Cmdr shows (and autocompletes).
BoomerangTuningLibrary.SETTING_ORDER = { "ThrowSpeed", "ThrowDistance", "RecallSpeed", "RecallAcceleration" } :: { Setting }

BoomerangTuningLibrary.SETTINGS = {
	ThrowSpeed = {
		Description = "maximum throw speed (studs/s)",
		getDefault = function(toolData)
			return toolData.Boomerang.Speed
		end,
	},
	ThrowDistance = {
		Description = "maximum throw distance (studs)",
		getDefault = function(toolData)
			return toolData.Boomerang.ThrowDistance
		end,
	},
	RecallSpeed = {
		Description = "maximum manual recall speed (x ThrowSpeed)",
		getDefault = function(_toolData)
			return GlobalConfig.ManualRecallSpeedMultiplier
		end,
	},
	RecallAcceleration = {
		Description = "how quickly a manual recall reaches its max speed (1 = normal recall)",
		getDefault = function(_toolData)
			return GlobalConfig.ManualRecallMomentumMultiplier
		end,
	},
} :: { [Setting]: SettingInfo }

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getAttributeName(toolId: string, setting: Setting): string
	return `{ATTRIBUTE_PREFIX}_{toolId}_{setting}`
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
