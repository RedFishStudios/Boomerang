--[[

Manages the logics of clashed weapons
Any weapon type, when it clashes, converts to this logic

]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClashedWeapons = require(ReplicatedStorage.Shared.Referential.ClashedWeapons)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)

local isServer = RunService:IsServer()

local ClashedWeaponLogic = {}

local ToolController, AnimationController
if not isServer then
	ToolController = require(ReplicatedStorage.Client.Core.ToolController)
	AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
end

local Characters = game.Workspace.Characters

local REPLICATION_RATE = 1 / 20
local CLASH_DECELERATION = 120
CLASH_DECELERATION = 80
local CLASH_FALL_ACCELERATION = 120
local CLASH_MAX_FALL_SPEED = 80
local CLASH_GROUND_RAY_DISTANCE = 10
local CLASH_GROUND_MAX_IGNORE_ITERATIONS = 16
local CLASH_GROUND_EPSILON = 0.02
local CLASH_OBSTRUCTION_RADIUS = 2
local CLASH_MAX_HORIZONTAL_DISTANCE = 100
local DEAD_PICKUP_DISTANCE = 3
local DEAD_OVERLAP_CHECK_SIZE = Vector3.new(0.01, 0.01, 0.01)
local SNAPSHOT_PACKET_SIZE = 1 + 8 + 12 + 12 + 4 + 1 + 8
local DESPAWN_PACKET_SIZE = 8 + 1
local WEAPON_UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable
local BOOMERANG_SPIN_SPEED = math.rad(1080)

export type ClashInitOptions = {
	Direction: Vector3,
	Speed: number?,
	Position: Vector3?,
}

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

local function getWeaponCFrame(clashedWeaponData: ClashedWeapons.Data): CFrame?
	local host = clashedWeaponData.Host
	if host and host.Parent then
		return host:GetPivot()
	end
	return clashedWeaponData.CFrame
end

-- // Returns true if the instance hit by a raycast under a boomerang is viable as an obstruction or if the boomerang should pass through it or not land on it
local function isViableClashGroundObstruction(hitInstance: Instance): boolean
	if not hitInstance:IsA("BasePart") then
		return false
	end
	return hitInstance.CanCollide and hitInstance.Transparency < 1
end

-- // Get resting height when a clashed boomerang falls
local function getClashRestingY(clashedWeaponData: ClashedWeapons.Data, position: Vector3, raycastParams: RaycastParams): number?
	local host = clashedWeaponData.Host
	if host and not host.Parent then
		host = nil
	end

	local ignoreList = table.clone(raycastParams.FilterDescendantsInstances or {})
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.IgnoreWater = raycastParams.IgnoreWater
	castParams.CollisionGroup = raycastParams.CollisionGroup

	local result
	for _ = 1, CLASH_GROUND_MAX_IGNORE_ITERATIONS do
		castParams.FilterDescendantsInstances = ignoreList
		local castResult = workspace:Raycast(position, Vector3.new(0, -CLASH_GROUND_RAY_DISTANCE, 0), castParams)
		if not castResult then
			return nil
		end
		if isViableClashGroundObstruction(castResult.Instance) then
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

	return result.Position.Y + pivotToBottom + CLASH_GROUND_EPSILON
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

	local rayDistance = travelDistance + CLASH_OBSTRUCTION_RADIUS
	local obstruction = RaycastsUtility.raycastProjectileObstruction(position, direction, rayDistance, raycastParams)
	if not obstruction then
		return position + direction * travelDistance, direction, false
	end

	local approachDistance = math.clamp((obstruction.Position - position).Magnitude - CLASH_OBSTRUCTION_RADIUS, 0, travelDistance)
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
			remainingDistance + CLASH_OBSTRUCTION_RADIUS,
			raycastParams
		)
		if slideObstruction then
			remainingDistance = math.clamp(
				(slideObstruction.Position - nextPosition).Magnitude - CLASH_OBSTRUCTION_RADIUS,
				0,
				remainingDistance
			)
		end
		nextPosition += slideDirection * remainingDistance
	end

	return nextPosition, slideDirection, false
end

-- // Failsafe; if a weapon ends up dying inside an obstruction, immediately return it to the player
local function isPositionInsideCollidablePart(clashedWeaponData: ClashedWeapons.Data, position: Vector3): boolean
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local filter = {Characters}
	if clashedWeaponData.Host then
		table.insert(filter, 1, clashedWeaponData.Host)
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

local function setWeaponCFrame(clashedWeaponData: ClashedWeapons.Data, cframe: CFrame, deltaTime: number?)
	clashedWeaponData.LastPosition = clashedWeaponData.CFrame and clashedWeaponData.CFrame.Position or cframe.Position
	clashedWeaponData.CFrame = cframe

	local host = clashedWeaponData.Host
	if host and host.Parent then
		if not isServer then
			local direction = clashedWeaponData.Direction
			if direction and direction.Magnitude > 1e-5 then
				local visualRotation = (clashedWeaponData.VisualRotation or 0) + (BOOMERANG_SPIN_SPEED * (deltaTime or 0))
				clashedWeaponData.VisualRotation = visualRotation

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

local function updateOwnWeaponHighlight(player: Player, clashedWeaponData: ClashedWeapons.Data, position: Vector3)
	if isServer or not ToolController or player ~= Players.LocalPlayer then
		return
	end

	local camera = workspace.CurrentCamera
	local host = clashedWeaponData.Host
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

function ClashedWeaponLogic.removeFromField(player: Player, clashedWeaponData: ClashedWeapons.Data, returnToPlayer: boolean?)
	local shouldReturnToPlayer = returnToPlayer ~= false
	local shouldReattachLocally = shouldReturnToPlayer and (not isServer) and clashedWeaponData.ReuseEquippedHost == true

	if not isServer and ToolController and player == Players.LocalPlayer then
		ToolController.applyHighlight(false, false)
	end

	if shouldReturnToPlayer and AnimationController then
		AnimationController.playCoreAnimation(player, "Catch")
	end

	if clashedWeaponData.Host and not shouldReattachLocally then
		clashedWeaponData.Host:Destroy()
	end
	if clashedWeaponData.MovementConnection then
		clashedWeaponData.MovementConnection:Disconnect()
		clashedWeaponData.MovementConnection = nil
	end

	for _, part in ipairs(clashedWeaponData.TestRaycastVisualizers) do
		if part and part.Parent then
			part:Destroy()
		end
	end

	ClashedWeapons.Data[player] = nil

	if isServer then
		fireDespawned(player.UserId, shouldReturnToPlayer)
		if shouldReturnToPlayer then
			SimpleRemotes.getEvent("WeaponEquipState"):FireAllClients(player.UserId, "SetVisible", true)
		end
	elseif shouldReturnToPlayer then
		SoundLibrary.play(clashedWeaponData.InstanceId, Sounds.Data.BoomerangCatch.Name, player.Character)
		if shouldReattachLocally and ToolController then
			ToolController.finishToolThrow(player)
		end
	end
end

-- // Boomerang has reached final resting point and died there (rip)
function ClashedWeaponLogic.setDead(player: Player, clashedWeaponData: ClashedWeapons.Data, position: Vector3?)
	local pivot = getWeaponCFrame(clashedWeaponData)
	if not pivot then
		return
	end

	if position then
		local deadPosition = Vector3.new(position.X, pivot.Position.Y, position.Z)
		setWeaponCFrame(clashedWeaponData, (pivot - pivot.Position) + deadPosition)
	end

	clashedWeaponData.State = ClashedWeapons.StateEnum.Dead
	clashedWeaponData.Speed = 0
	clashedWeaponData.SyncTargetPosition = nil

	local deadPivot = getWeaponCFrame(clashedWeaponData)

	if deadPivot and isPositionInsideCollidablePart(clashedWeaponData, deadPivot.Position) then
		ClashedWeaponLogic.removeFromField(player, clashedWeaponData)
		return
	end

	if isServer then
		if deadPivot then
			fireSnapshot(player.UserId, deadPivot.Position, clashedWeaponData.Direction or Vector3.zero, 0, clashedWeaponData.State)
		end
	end
end

function ClashedWeaponLogic.applyServerSnapshot(player: Player, position: Vector3, direction: Vector3, speed: number, state: number, serverTime: number)
	local clashedWeaponData = ClashedWeapons.Data[player]
	if not clashedWeaponData or not clashedWeaponData.Host or not clashedWeaponData.Host.Parent then
		return
	end
	if state ~= ClashedWeapons.StateEnum.Clashed and state ~= ClashedWeapons.StateEnum.Dead then
		return
	end

	if state == ClashedWeapons.StateEnum.Dead then
		ClashedWeaponLogic.setDead(player, clashedWeaponData, position)
		return
	end

	local catchup = math.clamp(workspace:GetServerTimeNow() - serverTime, 0, 0.35)
	clashedWeaponData.ServerDirection = direction
	clashedWeaponData.ServerSpeed = speed
	clashedWeaponData.Direction = direction
	clashedWeaponData.Speed = speed
	clashedWeaponData.SyncTargetPosition = position + direction * speed * catchup
end

function ClashedWeaponLogic.updateSmoothing(deltaTime: number)
	for _, clashedWeaponData in pairs(ClashedWeapons.Data) do
		if not clashedWeaponData.SyncTargetPosition then
			continue
		end
		if not clashedWeaponData.Host or not clashedWeaponData.Host.Parent then
			continue
		end

		local host = clashedWeaponData.Host
		local currentPivot = host:GetPivot()
		local currentPosition = currentPivot.Position
		local targetPosition = Vector3.new(clashedWeaponData.SyncTargetPosition.X, currentPosition.Y, clashedWeaponData.SyncTargetPosition.Z)
		local errorDistance = (targetPosition - currentPosition).Magnitude

		if errorDistance <= 0.05 then
			clashedWeaponData.SyncTargetPosition = nil
			continue
		end

		local alpha = math.clamp(deltaTime * 14, 0, 1)
		local correctedPosition = currentPosition:Lerp(targetPosition, alpha)
		local correctedCFrame = (currentPivot - currentPivot.Position) + correctedPosition
		clashedWeaponData.CFrame = correctedCFrame
		host:PivotTo(correctedCFrame)
	end
end

function ClashedWeaponLogic.applyClash(player: Player, clashedWeaponData: ClashedWeapons.Data, options: ClashInitOptions)
	local pivot = getWeaponCFrame(clashedWeaponData)
	if not pivot then
		return
	end

	if clashedWeaponData.MovementConnection then
		clashedWeaponData.MovementConnection:Disconnect()
		clashedWeaponData.MovementConnection = nil
	end

	local direction = getHorizontalDirection(options.Direction)
	local speed = options.Speed or clashedWeaponData.Speed or 0
	local nextReplicationAt = 0
	local fallSpeed = 0
	local isGrounded = false
	local groundRaycastParams = RaycastParams.new()
	groundRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	groundRaycastParams.FilterDescendantsInstances = {clashedWeaponData.Host, Characters}
	groundRaycastParams.IgnoreWater = true
	groundRaycastParams.CollisionGroup = CollisionGroupConstants.Camera

	local obstructionFilter = {Characters}
	if clashedWeaponData.Host then
		table.insert(obstructionFilter, 1, clashedWeaponData.Host)
	end
	local obstructionRaycastParams = RaycastsUtility.getProjectileObstructionParams(obstructionFilter)

	clashedWeaponData.State = ClashedWeapons.StateEnum.Clashed
	clashedWeaponData.Direction = direction
	clashedWeaponData.Speed = speed
	clashedWeaponData.SyncTargetPosition = nil

	if options.Position then
		local initialPosition = Vector3.new(options.Position.X, pivot.Position.Y, options.Position.Z)
		setWeaponCFrame(clashedWeaponData, (pivot - pivot.Position) + initialPosition)
	end

	clashedWeaponData.ClashOrigin = options.Position or pivot.Position

	local clashPivot = getWeaponCFrame(clashedWeaponData)
	if clashPivot then
		updateOwnWeaponHighlight(player, clashedWeaponData, clashPivot.Position)
		if isServer then
			fireSnapshot(player.UserId, clashPivot.Position, direction, speed, clashedWeaponData.State)
		end
	end

	clashedWeaponData.MovementConnection = RunService.Stepped:Connect(function(time, deltaTime)
		if ClashedWeapons.Data[player] ~= clashedWeaponData then
			return
		end

		local currentPivot = getWeaponCFrame(clashedWeaponData)
		if not currentPivot then
			return
		end

		if not isServer and speed <= 0 and isGrounded then
			updateOwnWeaponHighlight(player, clashedWeaponData, currentPivot.Position)
			return
		end

		local nextSpeed = math.max(0, speed - CLASH_DECELERATION * deltaTime)
		local travelDistance = (speed + nextSpeed) * 0.5 * deltaTime
		local nextPosition, nextDirection, isBlocked = resolveHorizontalMovement(currentPivot.Position, direction, travelDistance, obstructionRaycastParams)

		local restingY = if isGrounded then nil else getClashRestingY(clashedWeaponData, nextPosition, groundRaycastParams)

		if isGrounded or restingY or isBlocked then
			speed = nextSpeed
		else
			-- Nothing to land on: keep the frame's momentum instead of decelerating or falling
			nextPosition, nextDirection =
				resolveHorizontalMovement(currentPivot.Position, direction, speed * deltaTime, obstructionRaycastParams)
		end

		direction = nextDirection
		clashedWeaponData.Direction = direction

		if not isGrounded then
			if restingY then
				fallSpeed = math.min(CLASH_MAX_FALL_SPEED, fallSpeed + CLASH_FALL_ACCELERATION * deltaTime)
				local nextY = nextPosition.Y - fallSpeed * deltaTime
				if nextY <= restingY then
					nextY = restingY
					fallSpeed = 0
					isGrounded = true
				end
				nextPosition = Vector3.new(nextPosition.X, nextY, nextPosition.Z)
			else
				fallSpeed = 0
			end
		end

		if clashedWeaponData.ClashOrigin and getHorizontalDistance(clashedWeaponData.ClashOrigin, nextPosition) > CLASH_MAX_HORIZONTAL_DISTANCE then
			if isServer then
				ClashedWeaponLogic.removeFromField(player, clashedWeaponData)
			end
			return
		end

		setWeaponCFrame(clashedWeaponData, (currentPivot - currentPivot.Position) + nextPosition, deltaTime)
		clashedWeaponData.Speed = speed
		updateOwnWeaponHighlight(player, clashedWeaponData, nextPosition)

		if isServer and time >= nextReplicationAt then
			nextReplicationAt = time + REPLICATION_RATE
			fireSnapshot(player.UserId, nextPosition, direction, speed, clashedWeaponData.State)
		end

		if speed <= 0 and isServer then
			ClashedWeaponLogic.setDead(player, clashedWeaponData)
			if ClashedWeapons.Data[player] ~= clashedWeaponData then
				return
			end

			local movementConnection = clashedWeaponData.MovementConnection
			if movementConnection then
				movementConnection:Disconnect()
				clashedWeaponData.MovementConnection = nil
			end

			clashedWeaponData.MovementConnection = RunService.Heartbeat:Connect(function()
				if ClashedWeapons.Data[player] ~= clashedWeaponData then
					if clashedWeaponData.MovementConnection then
						clashedWeaponData.MovementConnection:Disconnect()
						clashedWeaponData.MovementConnection = nil
					end
					return
				end

				local deadPivot = getWeaponCFrame(clashedWeaponData)
				local character = player.Character
				local rootPart = character and character.PrimaryPart
				if deadPivot and rootPart and getHorizontalDistance(deadPivot.Position, rootPart.Position) <= DEAD_PICKUP_DISTANCE then
					ClashedWeaponLogic.removeFromField(player, clashedWeaponData)
				end
			end)
		end
	end)
end

return ClashedWeaponLogic