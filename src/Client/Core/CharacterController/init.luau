--[[
  CharacterController

  Description:
  Handles client-sided character operations

  Author:
  @SixthAtom

  Heavily modified and taken over by:
  @Soulsplosion
]]

local CharacterController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local CharacterLogic = require(ReplicatedStorage.Shared.Logics.CharacterLogic)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local PlatformController = require(ReplicatedStorage.Client.Core.PlatformController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local REPLICATION_RATE = 1 / 12
local REPLICATION_HEARTBEAT = 0.3
local REPLICATION_YAW_DEADBAND = math.rad(2.5)
local REMOTE_ANGLE_SMOOTH_SPEED = 16

local UNRELIABLE_CODES = RemoteCodes.Character.Unreliable

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type SolverState = {
	TargetYaw: number,
	RenderYaw: number,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local unreliableEvent = SimpleRemotes.getUnreliableEvent("Character")

local playersSolverState: { [Player]: SolverState } = {}

local nextReplicationAt = 0
local latestLocalYaw: number? = nil
local lastSentYaw: number? = nil
local lastSentAt = 0
local touchAimAngle: number? = nil
local isAiming = false

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CharacterController.LastCFrame = CFrame.new()

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getOrCreateSolverState(forPlayer: Player, yaw: number): SolverState
	local state = playersSolverState[forPlayer]
	if state then
		state.TargetYaw = yaw
		return state
	end

	state = {
		TargetYaw = yaw,
		RenderYaw = yaw,
	}

	playersSolverState[forPlayer] = state
	return state
end

local function applyYawToCustomCharacter(forPlayer: Player, yawAngle: number)
	local customCharacter = CharacterRenderController.getCharacterModel(forPlayer, false)
	if not customCharacter then
		return
	end

	local pivot = customCharacter:GetPivot()
	local lookVector = CharacterLogic.getLookVectorFromYaw(yawAngle)
	local orientedPivot = CFrame.new(pivot.Position, pivot.Position + lookVector)
	customCharacter:PivotTo(orientedPivot)

	if forPlayer == player then
		local rootPart = customCharacter:FindFirstChild("HumanoidRootPart")
		local rootPosition = if rootPart and rootPart:IsA("BasePart") then rootPart.Position else orientedPivot.Position
		CharacterController.LastCFrame = CFrame.new(rootPosition, rootPosition + lookVector)
	end
end

local function getTouchAimLookVectorFromAngle(angle: number): Vector3?
	local worldForward = Vector3.new(0, 0, -1)
	local worldRight = Vector3.new(1, 0, 0)
	local lookVector = (worldForward * math.cos(angle)) - (worldRight * math.sin(angle))
	if lookVector.Magnitude <= 1e-5 then
		return worldForward
	end

	return lookVector.Unit
end

local function solveCustomCharacterFacing(forPlayer: Player, solverState: SolverState, dT: number)
	local smoothAlpha = math.clamp(dT * REMOTE_ANGLE_SMOOTH_SPEED, 0, 1)

	solverState.RenderYaw = CharacterLogic.lerpAngle(solverState.RenderYaw, solverState.TargetYaw, smoothAlpha)
	applyYawToCustomCharacter(forPlayer, solverState.RenderYaw)
end

local function onPreSimulation(dT: number)
   if not PlayersUtil.isAlive(player) then
      return
   end

	local localYaw = latestLocalYaw or 0
	local localOriginPosition: Vector3? = nil

	local localCustomCharacter = CharacterRenderController.getCharacterModel(player, false)
	if localCustomCharacter then
		local localCustomRoot = localCustomCharacter:FindFirstChild("HumanoidRootPart")
		if localCustomRoot and localCustomRoot:IsA("BasePart") then
			localOriginPosition = localCustomRoot.Position
		end
	end

	if not localOriginPosition and PlayersUtil.isAlive(player) and player.Character then
		local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			localOriginPosition = rootPart.Position
		end
	end

	local mouseBehavior = UserInputService.MouseBehavior
	local isMouseLocked = mouseBehavior == Enum.MouseBehavior.LockCenter or mouseBehavior == Enum.MouseBehavior.LockCurrentPosition
	local controlScheme = PlatformController.getDominantControlScheme()
	local usesMovementFacing = controlScheme == "Touch" or controlScheme == "Console"

	if localOriginPosition then
		if not isAiming and usesMovementFacing then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local moveDirection = humanoid and humanoid.MoveDirection
			if moveDirection and moveDirection.Magnitude > 1e-5 then
				localYaw = CharacterLogic.getYawFromLookAt(localOriginPosition, localOriginPosition + moveDirection.Unit)
			end
		elseif touchAimAngle ~= nil then
			local lookVector = getTouchAimLookVectorFromAngle(touchAimAngle)
			if lookVector then
				localYaw = CharacterLogic.getYawFromLookAt(localOriginPosition, localOriginPosition + lookVector)
			end
		elseif isMouseLocked then
			local camera = workspace.CurrentCamera
			if camera then
				local cameraPosition = camera.CFrame.Position
				local toCharacter = Vector3.new(localOriginPosition.X - cameraPosition.X, 0, localOriginPosition.Z - cameraPosition.Z)
				if toCharacter.Magnitude > 1e-5 then
					local targetPosition = localOriginPosition + toCharacter.Unit
					localYaw = CharacterLogic.getYawFromLookAt(localOriginPosition, targetPosition)
				end
			end
		else
			local lastInWorld = PlatformController.getLastMousePositionInWorld()
			local localTarget = RaycastsUtility.getMouseWorldPosition(2048, nil, if lastInWorld then Vector2.new(lastInWorld.X, lastInWorld.Y) else nil)
			if localTarget then
				localYaw = CharacterLogic.getYawFromLookAt(localOriginPosition, localTarget)
			end
		end

		local lookVector = CharacterLogic.getLookVectorFromYaw(localYaw)
		CharacterController.LastCFrame = CFrame.new(localOriginPosition, localOriginPosition + lookVector)
	end

	latestLocalYaw = localYaw
	getOrCreateSolverState(player, localYaw)

	if PlayersUtil.isAlive(player) then
		local now = os.clock()
		if now >= nextReplicationAt then
			nextReplicationAt = now + REPLICATION_RATE

			local shouldSend = false
			if not lastSentYaw then
				shouldSend = true
			else
				local yawDelta = math.abs(CharacterLogic.getShortestAngleDelta(lastSentYaw, localYaw))
				shouldSend = yawDelta >= REPLICATION_YAW_DEADBAND
					or (now - lastSentAt) >= REPLICATION_HEARTBEAT
			end

			if shouldSend then
				lastSentYaw = localYaw
				lastSentAt = now

				unreliableEvent:FireServer(BufferUtil.construct({
					{ Type = "U8", Value = UNRELIABLE_CODES.SetTargetsBulk },
					{ Type = "U16", Value = CharacterLogic.quantizeYaw(localYaw) },
				}))
			end
		end
	end

	for forPlayer, solverState in next, playersSolverState do
		if forPlayer.Parent == nil then
			playersSolverState[forPlayer] = nil
			continue
		end

		solveCustomCharacterFacing(forPlayer, solverState, dT)
	end
end

local function onPlayerRemoving(removingPlayer: Player)
	playersSolverState[removingPlayer] = nil
end

local function loadRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(unreliableEvent, {
		[UNRELIABLE_CODES.SetTargetsBulk] = function(b: buffer)
			local len, offset = buffer.len(b) / 10, 0
			for _ = 1, len do
				local userId, quantizedYaw
				userId, offset = BufferUtil.readUserId(b, offset)
				quantizedYaw, offset = BufferUtil.readu16(b, offset)

				local forPlayer = Players:GetPlayerByUserId(userId)
				if not forPlayer or forPlayer == player then
					continue
				end

				getOrCreateSolverState(
					forPlayer,
					CharacterLogic.dequantizeYaw(quantizedYaw)
				)
			end
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CharacterController.setTouchAimAngle(angle: number?)
	if typeof(angle) == "number" then
		touchAimAngle = angle
	else
		touchAimAngle = nil
	end
end

function CharacterController.setAiming(nextIsAiming: boolean)
	isAiming = nextIsAiming
end

function CharacterController.getTouchAimLookVector(angle: number?): Vector3?
	local targetAngle = if typeof(angle) == "number" then angle else touchAimAngle
	if typeof(targetAngle) ~= "number" then
		return nil
	end

	return getTouchAimLookVectorFromAngle(targetAngle)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterController.init()
	loadRemotes()

	RunService.RenderStepped:Connect(onPreSimulation)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function CharacterController.start() end

function CharacterController.test() end

return CharacterController