--[[
	ObstructionCastLibrary

	Description:
	Live settings for how a boomerang detects obstructions, set from Cmdr:
	- The CAST HEIGHT (`setboomerangcastheight`): the height of the flat block used both for the bounce blockcast while the
	  boomerang flies and for the line-of-sight cast to the player's Hitbox when it runs out of energy. One value, so what
	  makes the boomerang bounce is exactly what blocks its line of sight. Default: GlobalConfig.BoomerangRaycastHeight.
	  Stored as an attribute on ReplicatedStorage so every client's prediction keeps matching the server.
	- The LINE-OF-SIGHT VISUALIZER (`togglelosvisualizer`): server-side flag, default GlobalConfig.LineOfSightVisualizerEnabled.
	Both last for the server session only (never saved).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

local ObstructionCastLibrary = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local HEIGHT_ATTRIBUTE = "BoomerangCastHeight"

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local losVisualizerEnabled: boolean = GlobalConfig.LineOfSightVisualizerEnabled

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ObstructionCastLibrary.getDefaultHeight(): number
	return GlobalConfig.BoomerangRaycastHeight
end

-- // The height in use right now (the override if there is one, otherwise the GlobalConfig default)
function ObstructionCastLibrary.getHeight(): number
	local override = ReplicatedStorage:GetAttribute(HEIGHT_ATTRIBUTE)
	if type(override) == "number" and override > 0 then
		return override
	end
	return GlobalConfig.BoomerangRaycastHeight
end

function ObstructionCastLibrary.isHeightOverridden(): boolean
	return ReplicatedStorage:GetAttribute(HEIGHT_ATTRIBUTE) ~= nil
end

-- // Server only. A nil value removes the override (back to the default).
function ObstructionCastLibrary.setHeight(value: number?)
	assert(RunService:IsServer(), "ObstructionCastLibrary.setHeight is server only")
	ReplicatedStorage:SetAttribute(HEIGHT_ATTRIBUTE, value)
end

function ObstructionCastLibrary.isLosVisualizerEnabled(): boolean
	return losVisualizerEnabled
end

-- // Server only.
function ObstructionCastLibrary.setLosVisualizerEnabled(value: boolean)
	assert(RunService:IsServer(), "ObstructionCastLibrary.setLosVisualizerEnabled is server only")
	losVisualizerEnabled = value
end

return ObstructionCastLibrary
