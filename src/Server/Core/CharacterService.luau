--[[
  CharacterService

  Description:
  Handles server-side character management

  Author:
  @SixthAtom

  Date:
  28-02-2026
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
local HitboxService = require(ServerStorage.Server.Core.HitboxService)

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

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local unreliableEvent = SimpleRemotes.getUnreliableEvent("Character")
type SolverAngles = {
	Yaw: number,
}

local playersSolverTarget: { [Player]: SolverAngles } = {}
local pendingSolverReplication: { [Player]: SolverAngles } = {}
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

local function applyAuthoritativeRotation(deltaTime: number)
	for player, solverAngles in playersSolverTarget do
		local character = player.Character
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid or humanoid.SeatPart then
			continue
		end

		local cframe = CharacterLogic.stepRootYawToAngle(rootPart.CFrame, solverAngles.Yaw, deltaTime)
      local hitbox = HitboxService.getHitbox(player)
      rootPart.CFrame = cframe
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

	-- Apply authoritative root rotation at the end of the frame so movement/physics systems resolve first.
	task.defer(applyAuthoritativeRotation, deltaTime)
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
   humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
   humanoid.JumpHeight = 0
   humanoid.JumpPower = 0
   humanoid.AutoRotate = false

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
		onCharacterRemoving(destroyingPlayer, character)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersSolverTarget[player] = nil
		pendingSolverReplication[player] = nil

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
