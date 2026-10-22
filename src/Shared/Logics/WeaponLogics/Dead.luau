--[[

Manages the logics of dying and dead weapons
Any weapon type, when it dies (runs out of energy out of line of sight), converts to this logic

]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local AuthorityViewLibrary = require(ReplicatedStorage.Shared.Library.AuthorityViewLibrary)
local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)

local isServer = RunService:IsServer()

local DeadWeaponLogic = {}
-- // Hooks set by Boomerang.luau (this module can't require it). checkRecallWhileDying returns true if it started a recall.
-- // (checkRecallWhileDying: (player, deadWeaponData, position) -> boolean)

local ToolController, AnimationController
if not isServer then
	ToolController = require(ReplicatedStorage.Client.Core.ToolController)
	AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
end

local Characters = game.Workspace.Characters

local REPLICATION_RATE = 1 / 20
local DEAD_FALL_ACCELERATION = 120 -- // Times the DeadWeaponDeceleration tuning value (default GlobalConfig.DeadWeaponDeceleration)

-- ============================================================================================================================
-- INTERNAL CONFIG: dying slide "on ice" (T-098)
-- ============================================================================================================================
-- // A dying boomerang drops to the ground, then glides on with its momentum, slowing gradually (like sliding on ice), so a fast
-- // boomerang slides further than a slow one. Its spin winds down gradually too. Each frame the speed loses DRAG x speed (the
-- // gradual, momentum-based part) plus FRICTION (so it does come to a stop). Every value below is multiplied by the
-- // DeadWeaponDeceleration tuning value (GlobalConfig.DeadWeaponDeceleration, default 4; Cmdr `tune DeadWeaponDeceleration`), so the
-- // effective values at the default are 4x these. At the default a boomerang dying at full throw speed (75) travels about 17 studs
-- // (about 11 of them sliding on the ground, over about 0.8 s); one dying at 25 travels about 5. (Before T-098: about 9 and 1.)
local DEAD_AIR_DRAG = 0.375 -- // Per second, while still dropping to the ground (effective 1.5)
local DEAD_AIR_FRICTION = 5 -- // Studs/s per second, while still dropping to the ground (effective 20)
local DEAD_LANDING_SPEED_KEPT = 0.8 -- // Fraction of its speed kept when it hits the ground (not scaled by the multiplier)
local DEAD_ICE_DRAG = 1 -- // Per second, while sliding on the ground (effective 4)
local DEAD_ICE_FRICTION = 2.5 -- // Studs/s per second, while sliding on the ground (effective 10)
local DEAD_SPIN_DRAG = 0.5 -- // Per second: the spin (starting at the flight spin rate) winds down (effective 2)
local DEAD_SPIN_FRICTION = math.rad(75) -- // Radians/s per second (effective 300 degrees/s per second); stops in about 1 s at default
local DEAD_MAX_FALL_SPEED = 80
local DEAD_GROUND_RAY_DISTANCE = 10
local DEAD_GROUND_MAX_IGNORE_ITERATIONS = 16
local DEAD_GROUND_EPSILON = 0.02
local DEAD_OBSTRUCTION_RADIUS = 2
local DEAD_PICKUP_DISTANCE = 3
local DEAD_OVERLAP_CHECK_SIZE = Vector3.new(0.01, 0.01, 0.01)
local SNAPSHOT_PACKET_SIZE = 1 + 8 + 12 + 12 + 4 + 1 + 8
local DESPAWN_PACKET_SIZE = 8 + 1
local WEAPON_UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable
local BOOMERANG_SPIN_SPEED = math.rad(1080)

export type DeathInitOptions = {
	Direction: Vector3,
	Speed: number?,
	Position: Vector3?,
}

-- // One frame of the dying slow-down (T-098): proportional drag (the gradual "ice" glide) plus a constant friction so it stops.
-- // Used for the slide speed (air or ground values) and for the visual spin rate.
local function getSlowedValue(value: number, deltaTime: number, drag: number, friction: number): number
	return math.max(0, value * math.exp(-drag * deltaTime) - friction * deltaTime)
end

local function getNextDyingSpeed(speed: number, deltaTime: number, isGrounded: boolean, dyingSpeedMultiplier: number): number
	if isGrounded then
		return getSlowedValue(speed, deltaTime, DEAD_ICE_DRAG * dyingSpeedMultiplier, DEAD_ICE_FRICTION * dyingSpeedMultiplier)
	end
	return getSlowedValue(speed, deltaTime, DEAD_AIR_DRAG * dyingSpeedMultiplier, DEAD_AIR_FRICTION * dyingSpeedMultiplier)
end

local function getHorizontalDirection(direction: Vector3): Vector3
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude <= 1e-5 then
		return Vector3.new(0, 0, -1)
	end
	return horizontal.Unit
end

local function getHorizontalDistance(fromPosition: Vector3, toPosition: Vector3): number
	local delta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	return delta.Magnitude
end

-- // True if the player is close enough to pick up a boomerang lying at this position (Dead, or Dying once it has hit the ground)
local function isWithinPickupDistance(player: Player, position: Vector3): boolean
	local character = player.Character
	local rootPart = character and character.PrimaryPart
	return rootPart ~= nil and getHorizontalDistance(position, rootPart.Position) <= DEAD_PICKUP_DISTANCE
end

local function getWeaponCFrame(deadWeaponData: DeadWeapons.Data): CFrame?
	local host = deadWeaponData.Host
	if host and host.Parent then
		return host:GetPivot()
	end
	return deadWeaponData.CFrame
end

-- // Returns true if the instance hit by a raycast under a boomerang is viable as an obstruction or if the boomerang should pass through it or not land on it
local function isViableDeadGroundObstruction(hitInstance: Instance): boolean
	if not hitInstance:IsA("BasePart") then
		return false
	end
	return hitInstance.CanCollide and hitInstance.Transparency < 1
end

-- // Get resting height when a dying boomerang falls
local function getDeadRestingY(deadWeaponData: DeadWeapons.Data, position: Vector3, raycastParams: RaycastParams): number?
	local host = deadWeaponData.Host
	if host and not host.Parent then
		host = nil
	end

	local ignoreList = table.clone(raycastParams.FilterDescendantsInstances or {})
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.IgnoreWater = raycastParams.IgnoreWater
	castParams.CollisionGroup = raycastParams.CollisionGroup

	local result
	for _ = 1, DEAD_GROUND_MAX_IGNORE_ITERATIONS do
		castParams.FilterDescendantsInstances = ignoreList
		local castResult = workspace:Raycast(position, Vector3.new(0, -DEAD_GROUND_RAY_DISTANCE, 0), castParams)
		if not castResult then
			return nil
		end
		if isViableDeadGroundObstruction(castResult.Instance) then
			result = castResult
			break
		end
		table.insert(ignoreList, castResult.Instance)
	end

	if not result then
		return nil
	end

	local pivotToBottom = 0
	if host then
		local boundsCFrame, boundsSize
		if host:IsA("Model") then
			boundsCFrame, boundsSize = host:GetBoundingBox()
		else
			boundsCFrame, boundsSize = host.CFrame, host.Size
		end

		local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
		pivotToBottom = math.max(0, position.Y - bottomY)
	end

	return result.Position.Y + pivotToBottom + DEAD_GROUND_EPSILON
end

-- // Moves horizontally without entering obstructions, sliding along the struck face
--    Returns the new position, the direction to keep travelling in, and whether the weapon is blocked head-on
local function resolveHorizontalMovement(
	position: Vector3,
	direction: Vector3,
	travelDistance: number,
	raycastParams: RaycastParams
): (Vector3, Vector3, boolean)
	if travelDistance <= 0 then
		return position, direction, false
	end

	local rayDistance = travelDistance + DEAD_OBSTRUCTION_RADIUS
	local obstruction = RaycastsUtility.raycastProjectileObstruction(position, direction, rayDistance, raycastParams)
	if not obstruction then
		return position + direction * travelDistance, direction, false
	end

	local approachDistance = math.clamp((obstruction.Position - position).Magnitude - DEAD_OBSTRUCTION_RADIUS, 0, travelDistance)
	local nextPosition = position + direction * approachDistance
	local remainingDistance = travelDistance - approachDistance

	local normal = Vector3.new(obstruction.Normal.X, 0, obstruction.Normal.Z)
	if normal.Magnitude <= 1e-5 then
		return nextPosition, direction, true
	end
	normal = normal.Unit

	local slideDirection = direction - normal * direction:Dot(normal)
	if slideDirection.Magnitude <= 1e-2 then
		return nextPosition, direction, true
	end
	slideDirection = slideDirection.Unit

	if remainingDistance > 0 then
		local slideObstruction = RaycastsUtility.raycastProjectileObstruction(
			nextPosition,
			slideDirection,
			remainingDistance + DEAD_OBSTRUCTION_RADIUS,
			raycastParams
		)
		if slideObstruction then
			remainingDistance = math.clamp(
				(slideObstruction.Position - nextPosition).Magnitude - DEAD_OBSTRUCTION_RADIUS,
				0,
				remainingDistance
			)
		end
		nextPosition += slideDirection * remainingDistance
	end

	return nextPosition, slideDirection, false
end

-- // Failsafe; if a weapon ends up dying inside an obstruction, immediately return it to the player
local function isPositionInsideCollidablePart(deadWeaponData: DeadWeapons.Data, position: Vector3): boolean
	local overlapParams = OverlapParams.new()
   overlapParams.CollisionGroup = CollisionGroupConstants.ArenaFloorDetector
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local filter = {Characters}
	if deadWeaponData.Host then
		table.insert(filter, 1, deadWeaponData.Host)
	end
	overlapParams.FilterDescendantsInstances = filter

	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(position + Vector3.new(0, DEAD_OVERLAP_CHECK_SIZE.Y+1, 0)), DEAD_OVERLAP_CHECK_SIZE, overlapParams)) do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency < 1 then
         --[[local a = Instance.new("Part")
         a.Color = Color3.new(1, 0, 0)
         a.Material = "Neon"
         a.Parent = game.Workspace
         a.Position = position + Vector3.new(0, DEAD_OVERLAP_CHECK_SIZE.Y+1, 0)]]
			return true
		end
	end

	return false
end

local function setWeaponCFrame(deadWeaponData: DeadWeapons.Data, cframe: CFrame, deltaTime: number?)
	deadWeaponData.LastPosition = deadWeaponData.CFrame and deadWeaponData.CFrame.Position or cframe.Position
	deadWeaponData.CFrame = cframe
	AuthorityViewLibrary.update(deadWeaponData.OwnerUserId, deadWeaponData.ToolId, cframe.Position) -- // Server only (no-op elsewhere)

	local host = deadWeaponData.Host
	if host and host.Parent then
		if not isServer then
			local direction = deadWeaponData.Direction
			if direction and direction.Magnitude > 1e-5 then
				-- // T-098: the spin rate winds down while dying (SpinRate, set and slowed in applyDeath)
				local visualRotation = (deadWeaponData.VisualRotation or 0) + ((deadWeaponData.SpinRate or 0) * (deltaTime or 0))
				deadWeaponData.VisualRotation = visualRotation

				local faceDirection = getHorizontalDirection(direction)
				local baseCFrame = CFrame.new(cframe.Position, cframe.Position + faceDirection)
				local spinCFrame = CFrame.Angles(0, visualRotation, 0)
				host:PivotTo(baseCFrame * spinCFrame)
			else
				host:PivotTo(cframe)
			end
		else
			host:PivotTo(cframe)
		end
	end
end

local function isFullyVisibleObstruction(hitInstance: Instance): boolean
	if hitInstance:IsA("BasePart") then
		return (hitInstance.Transparency + hitInstance.LocalTransparencyModifier) <= 0
	end

	return true
end

local function isCameraObstructedToPoint(cameraPosition: Vector3, targetPosition: Vector3, filter: {Instance}?): boolean
	local toTarget = targetPosition - cameraPosition
	local distance = toTarget.Magnitude
	if distance <= 1e-5 then
		return false
	end

	local direction = toTarget.Unit
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
   raycastParams.CollisionGroup = CollisionGroupConstants.Camera
	raycastParams.IgnoreWater = true

	local excludedInstances = filter or {}
	raycastParams.FilterDescendantsInstances = excludedInstances
	for _ = 1, 12 do
		local raycastResult = workspace:Raycast(cameraPosition, direction * distance, raycastParams)
		if not raycastResult then
			return false
		end

		if isFullyVisibleObstruction(raycastResult.Instance) then
			return true
		end

		table.insert(excludedInstances, raycastResult.Instance)
		raycastParams.FilterDescendantsInstances = excludedInstances
	end

	return false
end

local function updateOwnWeaponHighlight(player: Player, deadWeaponData: DeadWeapons.Data, position: Vector3)
	if isServer or not ToolController or player ~= Players.LocalPlayer then
		return
	end

	local camera = workspace.CurrentCamera
	local host = deadWeaponData.Host
	local character = player.Character
	local obstructionFilter = {}
	if character then
		table.insert(obstructionFilter, character)
	end
	if host then
		table.insert(obstructionFilter, host)
	end
	local isObstructed = camera ~= nil and host ~= nil
		and isCameraObstructedToPoint(camera.CFrame.Position, position, obstructionFilter)
		or false
	ToolController.applyHighlight(isObstructed, true)
end

local function fireSnapshot(ownerUserId: number, position: Vector3, direction: Vector3, speed: number, state: number)
	if not isServer then
		return
	end

	local payload = buffer.create(SNAPSHOT_PACKET_SIZE)
	local offset = 0
	offset = BufferUtil.writeu8(payload, offset, WEAPON_UNRELIABLE_CODES.BoomerangSnapshot)
	offset = BufferUtil.writeUserId(payload, offset, ownerUserId)
	offset = BufferUtil.writeVector3_96(payload, offset, position)
	offset = BufferUtil.writeVector3_96(payload, offset, direction)
	offset = BufferUtil.writef32(payload, offset, speed)
	offset = BufferUtil.writeu8(payload, offset, state)
	BufferUtil.writef64(payload, offset, workspace:GetServerTimeNow())

	SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication"):FireAllClients(payload)
end

local function fireDespawned(ownerUserId: number, returnToPlayer: boolean)
	if not isServer then
		return
	end
	local payload = buffer.create(DESPAWN_PACKET_SIZE)
	local offset = BufferUtil.writeUserId(payload, 0, ownerUserId)
	BufferUtil.writeu8(payload, offset, if returnToPlayer then 1 else 0)
	SimpleRemotes.getEvent("ThrownBoomerangDespawned"):FireAllClients(payload)
end

-- // True if there is ground beneath the position that a dying boomerang could land on (the same test the dying fall uses:
-- // a collidable, visible part within DEAD_GROUND_RAY_DISTANCE below). Used by Boomerang's 0-energy decision, which only lets a
-- // boomerang die over ground.
function DeadWeaponLogic.hasGroundBelow(position: Vector3, host: Instance?): boolean
	local filter: { Instance } = { Characters }
	if host then
		table.insert(filter, host)
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = filter
	raycastParams.IgnoreWater = true
	raycastParams.CollisionGroup = CollisionGroupConstants.Camera
	return getDeadRestingY({ Host = host } :: any, position, raycastParams) ~= nil
end

-- // Where a boomerang dying right now would be over the next lookaheadSeconds, one position per stepSeconds. Runs the same
-- // deceleration and wall sliding as the real dying loop (applyDeath) so a prediction can't drift from what would happen.
-- // Used by Boomerang before it commits to dying, to see if the player would be in sight and in range along the slide.
function DeadWeaponLogic.predictSlidePositions(position: Vector3, direction: Vector3, speed: number, host: Instance?, toolId: string?, lookaheadSeconds: number, stepSeconds: number): { Vector3 }
	local positions: { Vector3 } = {}
	local slideDirection = getHorizontalDirection(direction)
	local filter: { Instance } = { Characters }
	local groundFilter: { Instance } = { Characters }
	if host then
		table.insert(filter, 1, host)
		table.insert(groundFilter, 1, host)
	end
	local obstructionParams = RaycastsUtility.getProjectileObstructionParams(filter)
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.FilterDescendantsInstances = groundFilter
	groundParams.IgnoreWater = true
	groundParams.CollisionGroup = CollisionGroupConstants.Camera

	local dyingSpeedMultiplier = BoomerangTuningLibrary.getForAnyTool(toolId, "DeadWeaponDeceleration")
	local startY = position.Y -- // Ground checks use the starting height (the host isn't moved, so its bounds stay at this height)
	local currentPosition = position
	local currentSpeed = speed
	local fallSpeed = 0
	local isGrounded = false
	local elapsed = 0
	while elapsed + stepSeconds <= lookaheadSeconds + 1e-4 and currentSpeed > 0 do
		elapsed += stepSeconds
		local nextSpeed = getNextDyingSpeed(currentSpeed, stepSeconds, isGrounded, dyingSpeedMultiplier)
		local travelDistance = (currentSpeed + nextSpeed) * 0.5 * stepSeconds
		local nextPosition, nextDirection, isBlocked = resolveHorizontalMovement(currentPosition, slideDirection, travelDistance, obstructionParams)
		local restingY = if isGrounded then nil else getDeadRestingY({ Host = host } :: any, Vector3.new(nextPosition.X, startY, nextPosition.Z), groundParams)
		if isGrounded or restingY or isBlocked then
			currentSpeed = nextSpeed
		else
			-- // Nothing to land on: it keeps its momentum (as in the real loop)
			nextPosition, nextDirection = resolveHorizontalMovement(currentPosition, slideDirection, currentSpeed * stepSeconds, obstructionParams)
		end
		-- // Drop to the ground as in the real loop; landing costs some speed (T-098)
		if not isGrounded and restingY then
			fallSpeed = math.min(DEAD_MAX_FALL_SPEED, fallSpeed + DEAD_FALL_ACCELERATION * dyingSpeedMultiplier * stepSeconds)
			local nextY = nextPosition.Y - fallSpeed * stepSeconds
			if nextY <= restingY then
				nextY = restingY
				isGrounded = true
				currentSpeed *= DEAD_LANDING_SPEED_KEPT
			end
			nextPosition = Vector3.new(nextPosition.X, nextY, nextPosition.Z)
		end
		slideDirection = nextDirection
		currentPosition = nextPosition
		table.insert(positions, currentPosition)
	end
	return positions
end

function DeadWeaponLogic.removeFromField(player: Player, deadWeaponData: DeadWeapons.Data, returnToPlayer: boolean?)
	local shouldReturnToPlayer = returnToPlayer ~= false
	local shouldReattachLocally = shouldReturnToPlayer and (not isServer) and deadWeaponData.ReuseEquippedHost == true

	if not isServer and ToolController and player == Players.LocalPlayer then
		ToolController.applyHighlight(false, false)
	end

	if shouldReturnToPlayer and AnimationController then
		AnimationController.playCoreAnimation(player, "Catch")
	end

	if deadWeaponData.Host and not shouldReattachLocally then
		deadWeaponData.Host:Destroy()
	end
	AuthorityViewLibrary.clear(deadWeaponData.OwnerUserId)
	if deadWeaponData.MovementConnection then
		deadWeaponData.MovementConnection:Disconnect()
		deadWeaponData.MovementConnection = nil
	end

	DeadWeapons.Data[player] = nil

	if isServer then
		fireDespawned(player.UserId, shouldReturnToPlayer)
		if shouldReturnToPlayer then
			SimpleRemotes.getEvent("WeaponEquipState"):FireAllClients(player.UserId, "SetVisible", true)
		end
	elseif shouldReturnToPlayer then
		SoundLibrary.play(deadWeaponData.InstanceId, Sounds.Data.BoomerangCatch.Name, player.Character)
		if shouldReattachLocally and ToolController then
			ToolController.finishToolThrow(player)
		end
	end
end

-- // Boomerang has reached final resting point and died there (rip)
function DeadWeaponLogic.setDead(player: Player, deadWeaponData: DeadWeapons.Data, position: Vector3?)
	local pivot = getWeaponCFrame(deadWeaponData)
	if not pivot then
		return
	end

	if position then
		local deadPosition = Vector3.new(position.X, pivot.Position.Y, position.Z)
		setWeaponCFrame(deadWeaponData, (pivot - pivot.Position) + deadPosition)
	end

	deadWeaponData.State = DeadWeapons.StateEnum.Dead
	deadWeaponData.HasBeenDead = true -- // Permanent: see DeadWeapons.Data.HasBeenDead
	deadWeaponData.Speed = 0
	deadWeaponData.SyncTargetPosition = nil

	-- // A resting boomerang stops its flight loop (started in Boomerang.throw on the same channel). On the server this
	-- // replicates the stop to every client; clients also stop it locally when they receive the Dead snapshot.
	SoundLibrary.stop(deadWeaponData.InstanceId)

	local deadPivot = getWeaponCFrame(deadWeaponData)

	if deadPivot and isPositionInsideCollidablePart(deadWeaponData, deadPivot.Position) then
		DeadWeaponLogic.removeFromField(player, deadWeaponData)
		return
	end

	if isServer then
		if deadPivot then
			fireSnapshot(player.UserId, deadPivot.Position, deadWeaponData.Direction or Vector3.zero, 0, deadWeaponData.State)
		end
	end
end

function DeadWeaponLogic.applyServerSnapshot(player: Player, position: Vector3, direction: Vector3, speed: number, state: number, serverTime: number)
	local deadWeaponData = DeadWeapons.Data[player]
	if not deadWeaponData or not deadWeaponData.Host or not deadWeaponData.Host.Parent then
		return
	end
	if state ~= DeadWeapons.StateEnum.Dying and state ~= DeadWeapons.StateEnum.Dead then
		return
	end

	if state == DeadWeapons.StateEnum.Dead then
		DeadWeaponLogic.setDead(player, deadWeaponData, position)
		return
	end

	local catchup = math.clamp(workspace:GetServerTimeNow() - serverTime, 0, 0.35)
	deadWeaponData.ServerDirection = direction
	deadWeaponData.ServerSpeed = speed
	deadWeaponData.Direction = direction
	deadWeaponData.Speed = speed
	deadWeaponData.SyncTargetPosition = position + direction * speed * catchup
end

function DeadWeaponLogic.updateSmoothing(deltaTime: number)
	for _, deadWeaponData in pairs(DeadWeapons.Data) do
		if not deadWeaponData.SyncTargetPosition then
			continue
		end
		if not deadWeaponData.Host or not deadWeaponData.Host.Parent then
			continue
		end

		local host = deadWeaponData.Host
		local currentPivot = host:GetPivot()
		local currentPosition = currentPivot.Position
		local targetPosition = Vector3.new(deadWeaponData.SyncTargetPosition.X, currentPosition.Y, deadWeaponData.SyncTargetPosition.Z)
		local errorDistance = (targetPosition - currentPosition).Magnitude

		if errorDistance <= 0.05 then
			deadWeaponData.SyncTargetPosition = nil
			continue
		end

		local alpha = math.clamp(deltaTime * 14, 0, 1)
		local correctedPosition = currentPosition:Lerp(targetPosition, alpha)
		local correctedCFrame = (currentPivot - currentPivot.Position) + correctedPosition
		deadWeaponData.CFrame = correctedCFrame
		host:PivotTo(correctedCFrame)
	end
end

-------------------------------------------------------------------------------
-- RECALL CHARGE (T-090)
-- A dead boomerang only returns after its owner has held the manual recall for GlobalConfig.RecallCharge seconds. While
-- charging it lifts straight up to hand height (Y only), arriving exactly when the charge completes; releasing early drops it
-- back down. The server owns the state; the start/cancel are broadcast with server timestamps (RecallCharge event) and every
-- machine derives the height from those timestamps, so the lift is smooth everywhere without streaming positions.
-- Boomerang.luau sets DeadWeaponLogic.onRecallCharged (this module can't require it) to start the actual recall.
-------------------------------------------------------------------------------

local RECALL_CHARGE_EVENT = "RecallCharge"

-- ============================================================================================================================
-- INTERNAL CONFIG: how a dead boomerang rises while its manual recall charges (T-096). The rise ends exactly at the target
-- height (GlobalConfig.BoomerangFlightHeight) when the charge is complete (GlobalConfig.RecallCharge).
-- ============================================================================================================================
local RISE_OVERSHOOT = 0.3 -- // How far past the target it goes at the top, as a fraction of the rise (0.3 = 30% of the distance risen)
local RISE_PEAK_AT = 0.62 -- // Fraction of the charge time at which it reaches that top: slow at first, then a fast quart-in climb
local RISE_SETTLE_BOBS = 1.5 -- // How many half-swings it makes around the target while settling (it dips just under it once, then rests on it)

local function smoothstep(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

-- // 0 -> 1 over the charge, with 1 = the target height. Rises with a quart-in (gradual to fast), overshoots the target at RISE_PEAK_AT,
-- // then settles back with a damped bob and lands on the target exactly at the end.
local function getRiseCurve(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	if alpha < RISE_PEAK_AT then
		local riseAlpha = alpha / RISE_PEAK_AT
		return (1 + RISE_OVERSHOOT) * riseAlpha ^ 4
	end
	local settleAlpha = (alpha - RISE_PEAK_AT) / (1 - RISE_PEAK_AT)
	return 1 + RISE_OVERSHOOT * math.cos(settleAlpha * math.pi * RISE_SETTLE_BOBS) * (1 - settleAlpha) ^ 2
end

-- // The height the boomerang should be at right now (nil = not charging or dropping: leave it where it is)
local function getChargeHeight(deadWeaponData: DeadWeapons.Data, now: number): number?
	local cancelAt = deadWeaponData.RecallCancelAt
	if cancelAt then
		local fromY = deadWeaponData.RecallCancelFromY
		local restY = deadWeaponData.RecallRestY
		if not fromY or not restY then
			return nil
		end
		local alpha = math.clamp((now - cancelAt) / math.max(GlobalConfig.RecallChargeCancelDropSeconds, 0.01), 0, 1)
		return fromY + (restY - fromY) * alpha * alpha -- // Accelerates downward, like falling
	end

	local startAt = deadWeaponData.RecallChargeStart
	local startY = deadWeaponData.RecallChargeStartY
	local targetY = deadWeaponData.RecallChargeTargetY
	if not startAt or not startY or not targetY then
		return nil
	end
	local alpha = (now - startAt) / DeadWeaponLogic.getRecallChargeSeconds(deadWeaponData)
	return startY + (targetY - startY) * getRiseCurve(alpha)
end

-- // T-097: how long this boomerang's recall charge lasts (tunable live with `tune recallchargetime`; default GlobalConfig.RecallCharge)
function DeadWeaponLogic.getRecallChargeSeconds(deadWeaponData: DeadWeapons.Data): number
	return math.max(BoomerangTuningLibrary.getForAnyTool(deadWeaponData.ToolId, "RecallChargeTime"), 0.01)
end

local function clearChargeFields(deadWeaponData: DeadWeapons.Data)
	deadWeaponData.RecallChargeStart = nil
	deadWeaponData.RecallChargeStartY = nil
	deadWeaponData.RecallChargeTargetY = nil
	deadWeaponData.RecallCancelAt = nil
	deadWeaponData.RecallCancelFromY = nil
end

local function setHeight(deadWeaponData: DeadWeapons.Data, y: number)
	local pivot = getWeaponCFrame(deadWeaponData)
	if not pivot then
		return
	end
	local position = pivot.Position
	setWeaponCFrame(deadWeaponData, (pivot - position) + Vector3.new(position.X, y, position.Z), 0)
end

-- // True while the recall is being held on a dead boomerang (not cancelled, not yet returning)
function DeadWeaponLogic.isRecallCharging(deadWeaponData: DeadWeapons.Data): boolean
	return deadWeaponData.RecallChargeStart ~= nil and deadWeaponData.RecallCancelAt == nil
end

-- // True while the player's recall visuals should show: charging a dead boomerang, or a charged one flying back to them
-- // (the SelectionRing, the Summon animation and the dimmer beam all follow this)
function DeadWeaponLogic.isRecallChargeActive(player: Player): boolean
	local deadWeaponData = DeadWeapons.Data[player]
	if deadWeaponData then
		return DeadWeaponLogic.isRecallCharging(deadWeaponData)
	end
	local thrownWeaponData = ThrownWeapons.Data[player]
	return thrownWeaponData ~= nil and thrownWeaponData.RecallFromDead == true
end

-- // Both sides: record a charge start/cancel (server calls it for itself, clients call it from the RecallCharge event)
function DeadWeaponLogic.applyRecallChargeEvent(player: Player, action: string, serverTime: number, a: number?, b: number?, c: number?)
	local deadWeaponData = DeadWeapons.Data[player]
	if not deadWeaponData then
		return
	end
	if action == "Start" then
		deadWeaponData.RecallChargeStart = serverTime
		deadWeaponData.RecallChargeStartY = a
		deadWeaponData.RecallChargeTargetY = b
		deadWeaponData.RecallRestY = c
		deadWeaponData.RecallCancelAt = nil
		deadWeaponData.RecallCancelFromY = nil
	elseif action == "Cancel" then
		-- // Released before the charge finished (T-093): it drops back to where it rested (T-096)
		if deadWeaponData.RecallChargeStart then
			deadWeaponData.RecallCancelAt = serverTime
			deadWeaponData.RecallCancelFromY = a
		end
	end
end

-- // Server only: the owner pressed recall on a boomerang that is Dead: start lifting it
function DeadWeaponLogic.beginRecallCharge(player: Player, deadWeaponData: DeadWeapons.Data)
	if not isServer or DeadWeapons.Data[player] ~= deadWeaponData or deadWeaponData.State ~= DeadWeapons.StateEnum.Dead then
		return
	end
	if DeadWeaponLogic.isRecallCharging(deadWeaponData) then
		return
	end
	local pivot = getWeaponCFrame(deadWeaponData)
	local rootPart = player.Character and player.Character.PrimaryPart
	if not pivot or not rootPart then
		return
	end

	local now = workspace:GetServerTimeNow()
	-- // Pressing again while it is still dropping resumes from where it is (the full charge time still applies)
	local startY = getChargeHeight(deadWeaponData, now) or pivot.Position.Y
	local restY = deadWeaponData.RecallRestY or pivot.Position.Y
	local targetY = GlobalConfig.BoomerangFlightHeight -- // The exact height a thrown boomerang flies at, independent of the player (walls are only hit within a thin band around it)

	DeadWeaponLogic.applyRecallChargeEvent(player, "Start", now, startY, targetY, restY)
	SimpleRemotes.getEvent(RECALL_CHARGE_EVENT):FireAllClients(player.UserId, "Start", now, startY, targetY, restY)
end

-- // Server only: the owner released recall before the charge finished: it drops back to the ground
function DeadWeaponLogic.cancelRecallCharge(player: Player, deadWeaponData: DeadWeapons.Data)
	if not isServer or DeadWeapons.Data[player] ~= deadWeaponData or not DeadWeaponLogic.isRecallCharging(deadWeaponData) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local currentY = getChargeHeight(deadWeaponData, now) or deadWeaponData.RecallRestY or 0
	DeadWeaponLogic.applyRecallChargeEvent(player, "Cancel", now, currentY)
	SimpleRemotes.getEvent(RECALL_CHARGE_EVENT):FireAllClients(player.UserId, "Cancel", now, currentY)
end

-- // The charge lifts the boomerang again (T-096, client feedback; T-092 had kept it on the ground). Moves it to getChargeHeight each frame
-- // and finishes a cancelled drop.
local function applyRecallChargeLift(deadWeaponData: DeadWeapons.Data, now: number)
	local height = getChargeHeight(deadWeaponData, now)
	if not height then
		return
	end
	setHeight(deadWeaponData, height)

	local cancelAt = deadWeaponData.RecallCancelAt
	if cancelAt and now - cancelAt >= GlobalConfig.RecallChargeCancelDropSeconds then
		clearChargeFields(deadWeaponData) -- // Back on the ground
	end
end

-- // Every frame, on the server and on clients' copy of the data. The server starts a charge for a HELD recall once the boomerang has
-- // landed, and starts the return when the charge time is up. Releasing the button before that cancels the charge (T-093).
function DeadWeaponLogic.updateRecallCharges(_deltaTime: number)
	local now = workspace:GetServerTimeNow()
	for player, deadWeaponData in pairs(DeadWeapons.Data) do
		if deadWeaponData.State ~= DeadWeapons.StateEnum.Dead then
			continue
		end

		if isServer and deadWeaponData.RecallHeld and not deadWeaponData.RecallChargeStart then
			DeadWeaponLogic.beginRecallCharge(player, deadWeaponData)
		end

		applyRecallChargeLift(deadWeaponData, now)

		if isServer and not deadWeaponData.RecallCancelAt and deadWeaponData.RecallChargeStart and now - deadWeaponData.RecallChargeStart >= DeadWeaponLogic.getRecallChargeSeconds(deadWeaponData) then
			if DeadWeaponLogic.onRecallCharged then
				DeadWeaponLogic.onRecallCharged(player, deadWeaponData)
			else
				clearChargeFields(deadWeaponData)
			end
		end
	end
end

function DeadWeaponLogic.applyDeath(player: Player, deadWeaponData: DeadWeapons.Data, options: DeathInitOptions)
	local pivot = getWeaponCFrame(deadWeaponData)
	if not pivot then
		return
	end

	if deadWeaponData.MovementConnection then
		deadWeaponData.MovementConnection:Disconnect()
		deadWeaponData.MovementConnection = nil
	end

	local direction = getHorizontalDirection(options.Direction)
	local speed = options.Speed or deadWeaponData.Speed or 0
	local nextReplicationAt = 0
	local fallSpeed = 0
	local isGrounded = false
	local noGroundSlideTime = 0 -- // How long it has kept sliding with nothing to land on (T-062)
	local nextRecallCheckAt = 0 -- // Next time the dying boomerang looks for its player (see checkRecallWhileDying)
	local groundRaycastParams = RaycastParams.new()
	groundRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	groundRaycastParams.FilterDescendantsInstances = {deadWeaponData.Host, Characters}
	groundRaycastParams.IgnoreWater = true
	groundRaycastParams.CollisionGroup = CollisionGroupConstants.Camera

	local obstructionFilter = {Characters}
	if deadWeaponData.Host then
		table.insert(obstructionFilter, 1, deadWeaponData.Host)
	end
	local obstructionRaycastParams = RaycastsUtility.getProjectileObstructionParams(obstructionFilter)

	deadWeaponData.State = DeadWeapons.StateEnum.Dying
	deadWeaponData.SpinRate = BOOMERANG_SPIN_SPEED -- // T-098: starts at the flight spin rate and winds down (visual, clients)
	deadWeaponData.Direction = direction
	deadWeaponData.Speed = speed
	deadWeaponData.SyncTargetPosition = nil

	if options.Position then
		local initialPosition = Vector3.new(options.Position.X, pivot.Position.Y, options.Position.Z)
		setWeaponCFrame(deadWeaponData, (pivot - pivot.Position) + initialPosition)
	end

	deadWeaponData.DeathOrigin = options.Position or pivot.Position

	local deathPivot = getWeaponCFrame(deadWeaponData)
	if deathPivot then
		updateOwnWeaponHighlight(player, deadWeaponData, deathPivot.Position)
		if isServer then
			fireSnapshot(player.UserId, deathPivot.Position, direction, speed, deadWeaponData.State)
		end
	end

	deadWeaponData.MovementConnection = RunService.Stepped:Connect(function(time, deltaTime)
		if DeadWeapons.Data[player] ~= deadWeaponData then
			return
		end

		local currentPivot = getWeaponCFrame(deadWeaponData)
		if not currentPivot then
			return
		end

		-- // Clients keep running until the spin has also wound down (it can outlast the slide a little)
		if not isServer and speed <= 0 and isGrounded and (deadWeaponData.SpinRate or 0) <= 0 then
			updateOwnWeaponHighlight(player, deadWeaponData, currentPivot.Position)
			return
		end

		-- // Live tuning: read every frame, on the server and on clients, so both simulate the same dying pace
		local dyingSpeedMultiplier = BoomerangTuningLibrary.getForAnyTool(deadWeaponData.ToolId, "DeadWeaponDeceleration")
		if not isServer then
			deadWeaponData.SpinRate = getSlowedValue(deadWeaponData.SpinRate or 0, deltaTime, DEAD_SPIN_DRAG * dyingSpeedMultiplier, DEAD_SPIN_FRICTION * dyingSpeedMultiplier)
		end
		-- // T-098: "on ice": a gentle slow-down while dropping, then a gradual glide on the ground (see INTERNAL CONFIG)
		local nextSpeed = getNextDyingSpeed(speed, deltaTime, isGrounded, dyingSpeedMultiplier)
		local travelDistance = (speed + nextSpeed) * 0.5 * deltaTime
		local nextPosition, nextDirection, isBlocked = resolveHorizontalMovement(currentPivot.Position, direction, travelDistance, obstructionRaycastParams)

		local restingY = if isGrounded then nil else getDeadRestingY(deadWeaponData, nextPosition, groundRaycastParams)

		if isGrounded or restingY or isBlocked then
			speed = nextSpeed
			noGroundSlideTime = 0
		else
			-- Nothing to land on: keep the frame's momentum instead of decelerating or falling
			nextPosition, nextDirection =
				resolveHorizontalMovement(currentPivot.Position, direction, speed * deltaTime, obstructionRaycastParams)
			noGroundSlideTime += deltaTime
		end

		direction = nextDirection
		deadWeaponData.Direction = direction

		if not isGrounded then
			if restingY then
				fallSpeed = math.min(DEAD_MAX_FALL_SPEED, fallSpeed + DEAD_FALL_ACCELERATION * dyingSpeedMultiplier * deltaTime)
				local nextY = nextPosition.Y - fallSpeed * deltaTime
				if nextY <= restingY then
					nextY = restingY
					fallSpeed = 0
					isGrounded = true
					speed *= DEAD_LANDING_SPEED_KEPT -- // T-098: hitting the ground costs a little speed, then it glides on
					-- // T-099: the flight spin loop (Boomerang.throw, same channel) stops when it hits the ground, not when it comes to
					-- // rest. SoundLibrary.stop fades it out (0.25 s) on every client, so it never cuts off abruptly.
					if isServer then
						SoundLibrary.stop(deadWeaponData.InstanceId)
					end
					-- // Insertion point: "clunk" when the boomerang hits the ground. Played from the server so every player hears it.
					local clunkSound = Sounds.Data.BoomerangClunk
					if isServer and clunkSound and clunkSound.Id ~= 0 then
						SoundLibrary.play(`{deadWeaponData.InstanceId}_Clunk`, clunkSound.Name, Vector3.new(nextPosition.X, nextY, nextPosition.Z))
					end
				end
				nextPosition = Vector3.new(nextPosition.X, nextY, nextPosition.Z)
			else
				fallSpeed = 0
			end
		end

		-- // T-062: it keeps sliding with nowhere to land: instead of snapping back to the player, it flies back on its own
		-- // (automatic recall). Based on time only, never on distance. Server decides; clients follow its Returning snapshot.
		if noGroundSlideTime >= GlobalConfig.DyingBoomerangNoGroundRecallSeconds and isServer then
			if DeadWeaponLogic.onSlidingAway then
				DeadWeaponLogic.onSlidingAway(player, deadWeaponData)
			else
				DeadWeaponLogic.removeFromField(player, deadWeaponData)
			end
			return
		end

		-- // Still dying: keep checking whether the player is in sight and close. If so the recall resumes even at 0 energy
		-- // (the hook decides and starts the recall; clients follow its Returning snapshot). Server only, throttled.
		if isServer and DeadWeaponLogic.checkRecallWhileDying and time >= nextRecallCheckAt then
			nextRecallCheckAt = time + GlobalConfig.DyingBoomerangRecallCheckSeconds
			if DeadWeaponLogic.checkRecallWhileDying(player, deadWeaponData, nextPosition) then
				return
			end
		end

		setWeaponCFrame(deadWeaponData, (currentPivot - currentPivot.Position) + nextPosition, deltaTime)
		deadWeaponData.Speed = speed
		updateOwnWeaponHighlight(player, deadWeaponData, nextPosition)

		-- // T-099: once it has hit the ground it can be picked up, even while it is still sliding (not while flying or dropping)
		if isServer and isGrounded and isWithinPickupDistance(player, nextPosition) then
			DeadWeaponLogic.removeFromField(player, deadWeaponData)
			return
		end

		if isServer and time >= nextReplicationAt then
			nextReplicationAt = time + REPLICATION_RATE
			fireSnapshot(player.UserId, nextPosition, direction, speed, deadWeaponData.State)
		end

		-- // Only dead once it has actually landed (or there's nothing below to land on): a slow boomerang dropped from
		-- // hand height (e.g. a released manual recall) must finish falling instead of freezing mid-air
		if speed <= 0 and isServer and (isGrounded or not restingY) then
			DeadWeaponLogic.setDead(player, deadWeaponData)
			if DeadWeapons.Data[player] ~= deadWeaponData then
				return
			end

			local movementConnection = deadWeaponData.MovementConnection
			if movementConnection then
				movementConnection:Disconnect()
				deadWeaponData.MovementConnection = nil
			end

			deadWeaponData.MovementConnection = RunService.Heartbeat:Connect(function()
				if DeadWeapons.Data[player] ~= deadWeaponData then
					if deadWeaponData.MovementConnection then
						deadWeaponData.MovementConnection:Disconnect()
						deadWeaponData.MovementConnection = nil
					end
					return
				end

				local deadPivot = getWeaponCFrame(deadWeaponData)
				if deadPivot and isWithinPickupDistance(player, deadPivot.Position) then
					DeadWeaponLogic.removeFromField(player, deadWeaponData)
				end
			end)
		end
	end)
end

return DeadWeaponLogic