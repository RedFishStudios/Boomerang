--[[
	WalkSpeedLibrary

	Description:
	The game's default player walk speed. The value comes from GlobalConfig.DefaultWalkSpeed unless it was changed with
	the Cmdr command `setdefaultwalkspeed`, which stores an override as an attribute on ReplicatedStorage so it replicates
	to every client (the client's prediction keeps matching the server). Overrides last for the server session only.

	Everything that sets a player's WalkSpeed to "normal" (spawning, returning from aiming, ending a speed boost...)
	must use WalkSpeedLibrary.getDefault() instead of reading GlobalConfig.DefaultWalkSpeed or hardcoding a number.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

local WalkSpeedLibrary = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local OVERRIDE_ATTRIBUTE = "DefaultWalkSpeedOverride"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The default walk speed currently in use (the override if there is one, otherwise GlobalConfig.DefaultWalkSpeed)
function WalkSpeedLibrary.getDefault(): number
	local override = ReplicatedStorage:GetAttribute(OVERRIDE_ATTRIBUTE)
	if type(override) == "number" and override > 0 then
		return override
	end
	return GlobalConfig.DefaultWalkSpeed
end

function WalkSpeedLibrary.isOverridden(): boolean
	return type(ReplicatedStorage:GetAttribute(OVERRIDE_ATTRIBUTE)) == "number"
end

-- // Server only. A nil value removes the override (back to GlobalConfig.DefaultWalkSpeed).
function WalkSpeedLibrary.setDefault(value: number?)
	assert(RunService:IsServer(), "WalkSpeedLibrary.setDefault is server only")
	assert(value == nil or value > 0, "WalkSpeedLibrary: the default walk speed must be greater than 0")
	ReplicatedStorage:SetAttribute(OVERRIDE_ATTRIBUTE, value)
end

return WalkSpeedLibrary
