--[[
  CharacterService

  Description:
  Handles server-side character management

  Original Author:
  @SixthAtom

   Absolutely gutted and demolished by:
   @Soulsplosion
]]

local CharacterService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ConnectionsList = require(ReplicatedStorage.Shared.Classes.ConnectionsList)
local GlobalInstanceService = require(ServerStorage.Server.Services.GlobalInstanceService)
local CharacterLogic = require(ReplicatedStorage.Shared.Logics.CharacterLogic)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local _PartUtil = require(ReplicatedStorage.Shared.Utils.PartUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local UNRELIABLE_CODES = RemoteCodes.Character.Unreliable
local _COLLISION_GROUP = CollisionGroupConstants.Players
local REPLICATION_FLUSH_RATE = 1 / 12

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type CharacterAddedTask = (character: Model, player: Player) -> ()
type CharacterRemovingTask = (character: Model, player: Player) -> ()
type FacingConstraintState = {
	Orientation: AlignOrientation,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local unreliableEvent = SimpleRemotes.getUnreliableEvent("Character")
type SolverAngles = {
	Yaw: number,
}

local playersSolverTarget: { [Player]: SolverAngles } = {}
local pendingSolverReplication: { [Player]: SolverAngles } = {}
local playerFacingConstraints: { [Player]: FacingConstraintState } = {}
local nextReplicationFlushAt = 0

local playerConnections: { [Player]: ConnectionsList.ConnectionsList } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function onCharacterAdded(character: Model)
	character.Parent = workspace.Characters
	--for _, v in next, character:QueryDescendants("BasePart") :: { BasePart } do
	--	v.CollisionGroup = COLLISION_GROUP
	--end
end

local function onCharacterRemoving(player: Player, character: Model)
end

local function getFacingConstraintState(player: Player, character: Model): FacingConstraintState?
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	local rootAttachment = rootPart:FindFirstChild("RootAttachment")
	if not rootAttachment or not rootAttachment:IsA("Attachment") then
		return nil
	end

	local state = playerFacingConstraints[player]
	if state and state.Orientation.Parent == rootPart then
		return state
	end

	local orientation = rootPart:FindFirstChild("CharacterFacingOrientation")
	if orientation and not orientation:IsA("AlignOrientation") then
		orientation = nil
	end
	if not orientation then
		orientation = Instance.new("AlignOrientation")
		orientation.Name = "CharacterFacingOrientation"
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.Attachment0 = rootAttachment
		orientation.RigidityEnabled = true
		orientation.Enabled = true
		orientation.Parent = rootPart
	end

	state = {
		Orientation = orientation,
	}
	playerFacingConstraints[player] = state
	return state
end

local function applyAuthoritativeFacing(deltaTime: number)
	for player, solverAngles in playersSolverTarget do
		local character = player.Character
		if not character then
			continue
		end

		local facingConstraintState = getFacingConstraintState(player, character)
		if not facingConstraintState then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid or humanoid.SeatPart then
			continue
		end

		local lookVector = CharacterLogic.getLookVectorFromYaw(solverAngles.Yaw)
		facingConstraintState.Orientation.CFrame = CFrame.new(rootPart.Position, rootPart.Position + lookVector)
	end
end

local function dispatchSchedule()
	if not next(pendingSolverReplication) then
		return
	end

	task.defer(task.defer, function()
		local validEntries: { { Id: number, Yaw: number } } = {}

		for player, solverAngles in pendingSolverReplication do
			local character = player.Character
			if not character then
				continue
			end

			table.insert(validEntries, {
				Id = GlobalInstanceService.getId(character),
				Yaw = solverAngles.Yaw,
			})
		end

		table.clear(pendingSolverReplication)

		local len = #validEntries
		if len <= 0 then
			return
		end

		local b, offset = buffer.create(1 + len * 6), 0
		offset = BufferUtil.writeu8(b, offset, UNRELIABLE_CODES.SetTargetsBulk)

		for i = 1, len do
			local v = validEntries[i]
			offset = BufferUtil.writeu32(b, offset, v.Id)
			offset = BufferUtil.writeu16(b, offset, CharacterLogic.quantizeYaw(v.Yaw))
		end

		unreliableEvent:FireAllClients(b)
	end)
end

local function onPostSimulation(deltaTime: number)
	local now = os.clock()
	if now >= nextReplicationFlushAt then
		nextReplicationFlushAt = now + REPLICATION_FLUSH_RATE
		dispatchSchedule()
	end

	-- DO NOT TASK DEFER.
	applyAuthoritativeFacing(deltaTime)
end

local function loadCharacterRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(unreliableEvent, {
		[UNRELIABLE_CODES.SetTargetsBulk] = function(player: Player, b: buffer)
			local quantizedYaw
			local offset = 0

			quantizedYaw, offset = BufferUtil.readu16(b, offset)

			local state = playersSolverTarget[player]
			if state then
				state.Yaw = CharacterLogic.dequantizeYaw(quantizedYaw)
			else
				state = {
					Yaw = CharacterLogic.dequantizeYaw(quantizedYaw),
				}
				playersSolverTarget[player] = state
			end

			pendingSolverReplication[player] = state
		end,
	}, SimpleRemotesUtil.DecodeActionBuffer)
end

local function onCharacterLoaded(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
	getFacingConstraintState(player, character)

   humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
   humanoid.JumpHeight = 0
   humanoid.JumpPower = 0
   humanoid.AutoRotate = false
   humanoid.WalkSpeed = GlobalConfig.DefaultWalkSpeed

   for _, d in pairs(character:GetDescendants()) do
      if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("Part") then
         if d.Name:match("Hitbox") then
            continue
         end
         d.CanCollide = false
         d.CanTouch = false
         d.CanQuery = false
      end
   end

   character.DescendantAdded:Connect(function(d)
      if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("Part") then
         if d.Name:match("Hitbox") then
            return
         end
         d.CanCollide = false
         d.CanTouch = false
         d.CanQuery = false
      end
   end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterService.init()
   if 1==1 then return end
	loadCharacterRemotes()

   for _, p in pairs(game.Players:GetPlayers()) do
      if p.Character then
         onCharacterAdded(p.Character)

         local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
         local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
         if humanoid and rootPart then
            onCharacterLoaded(p, p.Character, humanoid, rootPart)
         end
      end
   end

   PlayersUtil.CharacterAdded:Add(function(addedPlayer: Player, character: Model)
		onCharacterAdded(character)
	end)

   PlayersUtil.CharacterLoaded:Add(onCharacterLoaded)

   PlayersUtil.CharacterDestroying:Add(function(destroyingPlayer: Player, character: Model)
		playersSolverTarget[destroyingPlayer] = nil
		playerFacingConstraints[destroyingPlayer] = nil
		onCharacterRemoving(destroyingPlayer, character)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersSolverTarget[player] = nil
		pendingSolverReplication[player] = nil
		playerFacingConstraints[player] = nil

		local playerConnectionList = playerConnections[player]
		if playerConnectionList then
			playerConnectionList:Destroy()
		end

		playerConnections[player] = nil
	end)

	RunService.PostSimulation:Connect(onPostSimulation)
end

function CharacterService.start() end

function CharacterService.test() end

return CharacterService