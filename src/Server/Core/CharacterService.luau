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
local PartUtil = require(ReplicatedStorage.Shared.Utils.PartUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local UNRELIABLE_CODES = RemoteCodes.Character.Unreliable
local COLLISION_GROUP = CollisionGroupConstants.Players

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type CharacterAddedTask = (character: Model, player: Player) -> ()
type CharacterRemovingTask = (character: Model, player: Player) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local unreliableEvent = SimpleRemotes.getUnreliableEvent("Character")
local solverTargetReplicationSchedule: { { Player: Player, SolverTarget: Vector3 } } = {}
local playersSolverTarget: { [Player]: Vector3 } = {}

local playerConnections: { [Player]: ConnectionsList.ConnectionsList } = {}
local hitboxes: {[Player]: BasePart} = {}

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
   if hitboxes[player] then
      hitboxes[player]:Destroy()
      hitboxes[player] = nil
   end
end

local function applyAuthoritativeRotation(deltaTime: number)
	for player, solverTarget in playersSolverTarget do
		local character = player.Character
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid or humanoid.SeatPart then
			continue
		end

      local cframe = CharacterLogic.stepRootYaw(rootPart.CFrame, solverTarget, deltaTime)
      if hitboxes[player] then
         hitboxes[player].CFrame = cframe
      end
		rootPart.CFrame = cframe
	end
end

local function dispatchSchedule()
	if #solverTargetReplicationSchedule <= 0 then
		return
	end

	task.defer(task.defer, function()
		local len = #solverTargetReplicationSchedule
		local b, offset = buffer.create(1 + len * 16), 0
		offset = BufferUtil.writeu8(b, offset, UNRELIABLE_CODES.SetTargetsBulk)

		for i = 1, len do
			local v = solverTargetReplicationSchedule[i]
			if not v.Player.Character then
				continue
			end

			offset = BufferUtil.writeu32(b, offset, GlobalInstanceService.getId(v.Player.Character))
			offset = BufferUtil.writeVector3_96(b, offset, v.SolverTarget)
		end

		unreliableEvent:FireAllClients(b)
		solverTargetReplicationSchedule = {}
	end)
end

local function onPostSimulation(deltaTime: number)
	dispatchSchedule()

	-- Apply authoritative root rotation at the end of the frame so movement/physics systems resolve first.
	task.defer(applyAuthoritativeRotation, deltaTime)
end

local function loadCharacterRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(unreliableEvent, {
		[UNRELIABLE_CODES.SetTargetsBulk] = function(player: Player, b: buffer)
			local solverTarget
			local offset = 0

			solverTarget, offset = BufferUtil.readVector3_96(b, offset)
			playersSolverTarget[player] = solverTarget

			table.insert(solverTargetReplicationSchedule, { Player = player, SolverTarget = solverTarget })
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
         d.CanCollide = false
         d.CanTouch = false
         d.CanQuery = false
      end
   end

   local hitbox = rootPart:Clone()
   for _, c in pairs(hitbox:GetChildren()) do
      c:Destroy()
   end
   hitbox.Name = "Hitbox"
   hitbox.Size = Vector3.new(2.2, 2.2, 2.2)
   hitbox.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
   hitbox.Parent = character
   hitboxes[player] = hitbox
   hitbox.CollisionGroup = COLLISION_GROUP
   hitbox.CanTouch = true
   hitbox.CanQuery = true
   hitbox.Transparency = .5

   character.DescendantAdded:Connect(function(d)
      if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("Part") then
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

		local playerConnectionList = playerConnections[player]
		if playerConnectionList then
			playerConnectionList:Destroy()
		end

      if hitboxes[player] then
         hitboxes[player]:Destroy()
         hitboxes[player] = nil
      end

		playerConnections[player] = nil
	end)

	RunService.PostSimulation:Connect(onPostSimulation)
end

function CharacterService.start() end

function CharacterService.test() end

return CharacterService
