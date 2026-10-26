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
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)

local ObstructionCastLibrary = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local HEIGHT_ATTRIBUTE = "BoomerangCastHeight"
local BLOCKCAST_DEPTH = 0.2
local BLOCKCAST_WIDTH_SCALE = 1.4
local UP_VECTOR = Vector3.new(0, 1, 0)

-- // The cast origin is pulled back by this much so consecutive steps overlap (no tunnelling through thin walls or concave corners)
ObstructionCastLibrary.BLOCKCAST_SKIN = 1

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

-- // The flat block every obstruction cast uses (flying, dying slides and line of sight): hitbox-wide, cast-height tall
function ObstructionCastLibrary.getCastSize(hitboxRadius: number): Vector3
	return Vector3.new(hitboxRadius * BLOCKCAST_WIDTH_SCALE, ObstructionCastLibrary.getHeight(), BLOCKCAST_DEPTH)
end

function ObstructionCastLibrary.getCastCFrame(rayOrigin: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(rayOrigin, rayOrigin + direction, UP_VECTOR)
end

-- // Sweeps the flat, horizontal block along direction for collidable obstructions. Shared by flying and dying weapons, so a
-- // dying weapon is stopped by exactly the walls a flying one bounces off. Also returns the cast (for visualizers).
function ObstructionCastLibrary.blockcast(
	rayOrigin: Vector3,
	direction: Vector3,
	rayDistance: number,
	hitboxRadius: number,
	raycastParams: RaycastParams
): (RaycastResult?, CFrame, Vector3, number)
	rayDistance = math.max(rayDistance, hitboxRadius)
	local skin = ObstructionCastLibrary.BLOCKCAST_SKIN
	local castCFrame = ObstructionCastLibrary.getCastCFrame(rayOrigin - direction * skin, direction)
	local castSize = ObstructionCastLibrary.getCastSize(hitboxRadius)
	local castDistance = rayDistance + skin
	local result = RaycastsUtility.blockcastProjectileObstruction(castCFrame, castSize, direction, castDistance, raycastParams)
	return result, castCFrame, castSize, castDistance
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
