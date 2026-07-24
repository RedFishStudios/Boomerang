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

local GlobalInstanceController = require(ReplicatedStorage.Client.Controllers.GlobalInstanceController)
local GameTypes = require(ReplicatedStorage.Shared.GameTypes)
local CharacterLogic = require(ReplicatedStorage.Shared.Logics.CharacterLogic)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local REPLICATION_RATE = 1 / 12
local REPLICATION_HEARTBEAT = 0.3
local REPLICATION_YAW_DEADBAND = math.rad(2.5)
local REMOTE_ANGLE_SMOOTH_SPEED = 16

local ANIMATION_SPEEDS = table.freeze({
	Waist = 14,
	Root = 8,
})

local ANGLE_LIMITS = table.freeze({
	WaistYaw = math.rad(35),
	--WaistPitch = math.rad(45), -- Keep for optional vertical aim support.
})

local UNRELIABLE_CODES = RemoteCodes.Character.Unreliable

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type RequiredCharacterInstances = {
	HumanoidRootPart: BasePart,
	Waist: Motor6D,
	Humanoid: Humanoid,
}

type SolverState = {
	TargetYaw: number,
	RenderYaw: number,
}

type FacingConstraintState = {
	Orientation: AlignOrientation,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local unreliableEvent = SimpleRemotes.getUnreliableEvent("Character")

local playersSolverState: { [Player]: SolverState } = {}
local characterInstances: { [GameTypes.R15Character]: RequiredCharacterInstances } = {}
local motorsBaseC0: { [Motor6D]: CFrame } = {}
local facingConstraintStates: { [GameTypes.R15Character]: FacingConstraintState } = {}

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

-- // Apply local yaw to alleviate conflicts with server authoritative yaw
local function applyLocalAuthoritativeRotation(yawAngle: number)
	if not PlayersUtil.isAlive(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoidRootPart or not humanoid or humanoid.SeatPart then
		return
	end

	local rootAttachment = humanoidRootPart:FindFirstChild("RootAttachment")
	if not rootAttachment or not rootAttachment:IsA("Attachment") then
		return
	end

	local orientationState = facingConstraintStates[character]
	if not orientationState then
		local orientation = humanoidRootPart:FindFirstChild("CharacterFacingOrientation")
		if not orientation or not orientation:IsA("AlignOrientation") then
			return
		end

		orientationState = {
			Orientation = orientation,
		}
		facingConstraintStates[character] = orientationState
	elseif orientationState.Orientation.Parent ~= humanoidRootPart then
		facingConstraintStates[character] = nil
		return
	end

	local cf = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + CharacterLogic.getLookVectorFromYaw(yawAngle))
	CharacterController.LastCFrame = cf
	orientationState.Orientation.CFrame = cf
end

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

local function solveMotorsForCharacter(character: GameTypes.R15Character, solverState: SolverState, dT: number)
	local instances = characterInstances[character]
	if not instances then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local upperTorso = character:FindFirstChild("UpperTorso")
		local humanoid = character:FindFirstChild("Humanoid")

		if not (humanoidRootPart and upperTorso and humanoid) then
			return
		end

		local waistM6D = upperTorso:FindFirstChild("Waist")
		if not waistM6D then
			return
		end

		instances = {
			HumanoidRootPart = humanoidRootPart,
			Humanoid = humanoid,
			Waist = waistM6D,
		}

		motorsBaseC0[waistM6D] = waistM6D.C0
		characterInstances[character] = instances
	end

	local waistM6D = instances.Waist
	local waistBaseC0 = motorsBaseC0[waistM6D]
	local smoothAlpha = math.clamp(dT * REMOTE_ANGLE_SMOOTH_SPEED, 0, 1)

	solverState.RenderYaw = CharacterLogic.lerpAngle(solverState.RenderYaw, solverState.TargetYaw, smoothAlpha)
	local lookVector = CharacterLogic.getLookVectorFromYaw(solverState.RenderYaw)
	local lookAt = instances.HumanoidRootPart.Position + lookVector * 100

	-- compute waist
	local waistTarget = (waistM6D.Part0.CFrame * waistBaseC0):PointToObjectSpace(lookAt)
	local waistYawAngle = math.clamp(math.atan2(-waistTarget.X, -waistTarget.Z), -ANGLE_LIMITS.WaistYaw, ANGLE_LIMITS.WaistYaw)
	--local waistPitchAngle = math.clamp(math.atan2(waistTarget.Y, Vector2.new(waistTarget.X, waistTarget.Z).Magnitude), -ANGLE_LIMITS.WaistPitch, ANGLE_LIMITS.WaistPitch)
	local waistPitchAngle = 0

	waistM6D.Attachment0.CFrame = waistM6D.Attachment0.CFrame:Lerp(waistBaseC0 * CFrame.fromOrientation(waistPitchAngle, waistYawAngle, 0), dT * ANIMATION_SPEEDS.Waist)
end

local function onPreSimulation(dT: number)
	local localTarget = RaycastsUtility.getMouseWorldPosition(2048)
	local localYaw = 0

	if PlayersUtil.isAlive(player) and player.Character then
		local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart and localTarget then
			localYaw = CharacterLogic.getYawFromLookAt(rootPart.Position, localTarget)
		end
	end

	latestLocalYaw = localYaw
	getOrCreateSolverState(player, localYaw)
	applyLocalAuthoritativeRotation(localYaw)

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
		if PlayersUtil.isAlive(forPlayer) then
			solveMotorsForCharacter(forPlayer.Character, solverState, dT)
		end
	end

end

local function onRenderStepped()
   local localTarget = RaycastsUtility.getMouseWorldPosition(2048)
	local localYaw = 0
	if PlayersUtil.isAlive(player) and player.Character then
		local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart and localTarget then
			localYaw = CharacterLogic.getYawFromLookAt(rootPart.Position, localTarget)
		end
	end
   -- // THIS NEEDS TO BE DONE IN RENDER STEPPED. THIS HAS TO BE DONE IN RENDERSTEPPED.
   -- THE LOCAL AUTHORITATIVE ROTATION NEEDS TO BE DONE IN RENDERSTEPPED. IF IT IS NOT, IT WILL CONFLICT WITH THE SERVER.
   -- THE LOCAL AUTHORITATIVE ROTATION NEEDS TO BE DONE ON RENDERSTEPPED TO PREVENT JITTERINESS.
	applyLocalAuthoritativeRotation(localYaw)
end

local function onAnyCharacterRemoved(character: GameTypes.R15Character)
	local instances = characterInstances[character]
	if instances then
		motorsBaseC0[instances.Waist] = nil
	end
	characterInstances[character] = nil
	facingConstraintStates[character] = nil
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

   -- I Am Sick And Tired Of Physics Conflicts With Native Server Authority
	--RunService.PreSimulation:Connect(onPreSimulation)
   RunService.PostSimulation:Connect(onPreSimulation)
   RunService:BindToRenderStep("CharacterControllerRenderStep", Enum.RenderPriority.Last.Value, onPreSimulation)
	RunService:BindToRenderStep("CharacterControllerRenderStep", Enum.RenderPriority.First.Value, onPreSimulation)
   workspace.Characters.ChildRemoved:Connect(onAnyCharacterRemoved)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function CharacterController.start() end

function CharacterController.test() end

return CharacterController