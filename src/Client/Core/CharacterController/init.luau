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

local GlobalInstanceController = require(ReplicatedStorage.Client.Controllers.GlobalInstanceController)
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

local function solveCustomCharacterFacing(forPlayer: Player, solverState: SolverState, dT: number)
	local smoothAlpha = math.clamp(dT * REMOTE_ANGLE_SMOOTH_SPEED, 0, 1)

	solverState.RenderYaw = CharacterLogic.lerpAngle(solverState.RenderYaw, solverState.TargetYaw, smoothAlpha)
	applyYawToCustomCharacter(forPlayer, solverState.RenderYaw)
end

local function onPreSimulation(dT: number)
   if not PlayersUtil.isAlive(player) then
      return
   end
	local lastInWorld = PlatformController.getLastMousePositionInWorld()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		lastInWorld += Vector3.new(0, -60, 0)
	end

	local localTarget = RaycastsUtility.getMouseWorldPosition(2048, nil, if lastInWorld then Vector2.new(lastInWorld.X, lastInWorld.Y) else nil)
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

	if localOriginPosition and localTarget then
		localYaw = CharacterLogic.getYawFromLookAt(localOriginPosition, localTarget)
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
			local len, offset = buffer.len(b) / 6, 0
			for _ = 1, len do
				local instanceId, quantizedYaw
				instanceId, offset = BufferUtil.readu32(b, offset)
				quantizedYaw, offset = BufferUtil.readu16(b, offset)

				local character = GlobalInstanceController.getInstance(instanceId)
				if not character then
					continue
				end

				local forPlayer = Players:GetPlayerFromCharacter(character)
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