--[[
	CatchLibrary

	Catching a returning boomerang: which catch it is, and the heavy catch's push.
	  - Normal or heavy: by how fast the boomerang is closing in on the catcher just before contact (its velocity minus the
	    catcher's, along the line from the boomerang to them). At or above the HeavyCatchSpeed tuning setting it's heavy.
	  - Heavy push: a grounded heavy catch shoves the catcher back HeavyCatchPushDistance studs over HeavyCatchPushSeconds,
	    away from the incoming boomerang, fastest at first. With server authority over characters it's run like the dash:
	    on the server for the authoritative catch, and on the catcher's own client for its predicted catch. It's shortened
	    in front of walls and stops short of an edge or water.
]]

local CatchLibrary = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)

local isServer = RunService:IsServer()

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local MIN_TOWARD_DISTANCE = 0.01
local BODY_SIZE = Vector3.new(2, 4, 1) -- // Blockcast for walls in the push's way (torso width, step height to head)
local WALL_MARGIN = 0.3
local GROUND_PROBE_STEP = 0.5 -- // Studs between ground checks along the push
local BODY_BELOW_ROOT = 3 -- // Feet are this far below the root (R6), as in the dash
local GROUND_PROBE_DEPTH = BODY_BELOW_ROOT + 5 -- // Studs below the root a probe looks for ground (any deeper is an edge)
local MIN_GROUND_NORMAL_Y = 0.65

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type CatchInfo = {
	Heavy: boolean,
	ClosingSpeed: number,
	Direction: Vector3, -- // Horizontal unit direction away from the incoming boomerang (the push direction)
}

type Push = {
	Character: Model,
	RootPart: BasePart,
	Direction: Vector3,
	InitialSpeed: number,
	StartedAt: number,
	Duration: number,
	Start: Vector3,
	Distance: number,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local activePushes: { [Player]: Push } = {}
local pushConnection: RBXScriptConnection? = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- // Casts that see what the player's body collides with (the same as the dash's)
local function getCastParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.CollisionGroup = CollisionGroupConstants.Players
	params.RespectCanCollide = true
	return params
end

-- // Lazily required, like the dash (load order)
local WaterLogic = nil
local function getWaterCastParams(): RaycastParams?
	if not WaterLogic then
		WaterLogic = require(ReplicatedStorage.Shared.Logics.Environment.Water)
	end
	local waterParts = WaterLogic.getCurrentWaterParts()
	if #waterParts == 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = waterParts
	return params
end

-- // How far the push can go: up to a wall, and only over standable ground (not water, not off an edge)
local function getSafeDistance(character: Model, rootPart: BasePart, direction: Vector3, distance: number): number
	local params = getCastParams(character)
	local rootPosition = rootPart.Position
	local wall = workspace:Blockcast(CFrame.lookAt(rootPosition, rootPosition + direction), BODY_SIZE, direction * distance, params)
	local safe = if wall then math.max(0, wall.Distance - WALL_MARGIN) else distance

	local waterParams = getWaterCastParams()
	local travelled = GROUND_PROBE_STEP
	while travelled <= safe do
		local probe = rootPosition + direction * travelled
		local hit = workspace:Raycast(probe, Vector3.new(0, -GROUND_PROBE_DEPTH, 0), params)
		local overWater = hit ~= nil and waterParams ~= nil
			and workspace:Raycast(probe, Vector3.new(0, hit.Position.Y - probe.Y - 0.05, 0), waterParams) ~= nil
		if not hit or hit.Normal.Y < MIN_GROUND_NORMAL_Y or overWater then
			return math.max(0, travelled - GROUND_PROBE_STEP)
		end
		travelled += GROUND_PROBE_STEP
	end
	return safe
end

local function stopPush(player: Player)
	local push = activePushes[player]
	if not push then
		return
	end
	activePushes[player] = nil
	if push.RootPart.Parent and not push.RootPart.Anchored then
		local velocity = push.RootPart.AssemblyLinearVelocity
		push.RootPart.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0) -- // Keeps falling/jumping speed
	end
end

local function stepPushes()
	local now = os.clock()
	for player, push in activePushes do
		local humanoid = push.Character:FindFirstChildOfClass("Humanoid")
		if player.Character ~= push.Character or not push.RootPart.Parent or not humanoid or humanoid.Health <= 0 then
			stopPush(player)
			continue
		end
		local remaining = push.Distance - flat(push.RootPart.Position - push.Start):Dot(push.Direction)
		local timeLeft = push.Duration - (now - push.StartedAt)
		if timeLeft <= 0 or remaining <= 0.05 then
			stopPush(player)
			continue
		end
		-- // Strongest at the start, slowing to a stop. Re-aimed every frame at what's left (the Humanoid's own movement drags
		-- // on it), so it still covers the distance; capped so a stuck push can't build up a launch
		local speed = math.min(2 * remaining / timeLeft, push.InitialSpeed * 1.5)
		local velocity = push.RootPart.AssemblyLinearVelocity
		push.RootPart.AssemblyLinearVelocity = Vector3.new(push.Direction.X * speed, velocity.Y, push.Direction.Z * speed)
	end

	if next(activePushes) == nil and pushConnection then
		pushConnection:Disconnect()
		pushConnection = nil
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Which catch this is. `weaponPosition` and `weaponVelocity` (studs/s) are the boomerang's just before contact.
function CatchLibrary.resolve(player: Player, toolId: string?, weaponPosition: Vector3?, weaponVelocity: Vector3?): CatchInfo
	local info: CatchInfo = { Heavy = false, ClosingSpeed = 0, Direction = Vector3.zero }
	local rootPart = player.Character and player.Character.PrimaryPart
	if not rootPart or not weaponPosition or not weaponVelocity then
		return info
	end

	local relative = flat(weaponVelocity - rootPart.AssemblyLinearVelocity)
	local toward = flat(rootPart.Position - weaponPosition)
	if toward.Magnitude < MIN_TOWARD_DISTANCE then
		toward = relative
	end
	if toward.Magnitude < MIN_TOWARD_DISTANCE then
		return info
	end

	info.Direction = toward.Unit
	info.ClosingSpeed = math.max(0, relative:Dot(info.Direction))
	info.Heavy = info.ClosingSpeed >= BoomerangTuningLibrary.getForAnyTool(toolId, "HeavyCatchSpeed")
	return info
end

-- // The heavy catch's push. Server: any player. Client: only the local player (its prediction). Skipped in the air.
function CatchLibrary.push(player: Player, direction: Vector3)
	if not isServer and player ~= Players.LocalPlayer then
		return
	end
	local character = player.Character
	local rootPart = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not rootPart or not humanoid or humanoid.Health <= 0 or rootPart.Anchored then
		return
	end
	if humanoid.FloorMaterial == Enum.Material.Air or direction.Magnitude < MIN_TOWARD_DISTANCE then
		return
	end

	local unit = flat(direction).Unit
	local duration = math.max(GlobalConfig.HeavyCatchPushSeconds, 1 / 60)
	local distance = getSafeDistance(character, rootPart, unit, GlobalConfig.HeavyCatchPushDistance)
	if distance <= 0.05 then
		return
	end

	activePushes[player] = {
		Character = character,
		RootPart = rootPart,
		Direction = unit,
		InitialSpeed = 2 * distance / duration, -- // Slowing linearly to 0 over the duration covers `distance`
		StartedAt = os.clock(),
		Duration = duration,
		Start = rootPart.Position,
		Distance = distance,
	}
	if not pushConnection then
		pushConnection = RunService.Heartbeat:Connect(stepPushes)
	end
end

function CatchLibrary.cancelPush(player: Player)
	stopPush(player)
end

Players.PlayerRemoving:Connect(function(player)
	activePushes[player] = nil
end)

return CatchLibrary
