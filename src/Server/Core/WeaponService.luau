-- // Handles behavior of thrown weapons

--[[
  Handles equipping/unequipping of tools to the character
  - Boomerangs, shuricans, fans, special weapons, etc
]]

local WeaponService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local GameStateLibrary= require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local WeaponLibrary = require(ReplicatedStorage.Shared.Library.WeaponLibrary)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)

local ToolLogics = ReplicatedStorage.Shared.Logics.WeaponLogics
local ToolLogicModules = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type WeaponThrownTask = (player: Player, toolId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local throwEvent = SimpleRemotes.getEvent("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

WeaponService.WeaponThrownTasks = TasksList.new() :: TasksList.TasksList<WeaponThrownTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(toolId: string)
	if not ToolLogicModules[toolId] then
		local module = require(ToolLogics:WaitForChild(toolId))
		ToolLogicModules[toolId] = module
	end
	return ToolLogicModules[toolId]
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function WeaponService.init()
   -- Ensure boomerang replication remotes exist at server startup.
   SimpleRemotes.getEvent("ThrownBoomerangSpawned")
   SimpleRemotes.getEvent("ThrownBoomerangDespawned")
   SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication")

   -- // Create thrown weapon replication part
   local replicationPart = Instance.new("Part")
   replicationPart.Name = "ThrownWeaponReplication"
   replicationPart.Shape = Enum.PartType.Ball
   replicationPart.Size = Vector3.new(3, 3, 3)
   replicationPart.Material = "Neon"
   replicationPart.Anchored = true
   replicationPart.CanCollide = false
   replicationPart.CanQuery = false
   replicationPart.CanTouch = false
   replicationPart.Transparency = 1
   replicationPart.Parent = game.ReplicatedStorage.Shared.Assets

   -- // Throw boomerang
	throwEvent.OnServerEvent:Connect(function(player: Player, toolId: string)
      local canThrow, reason = WeaponLibrary.canThrow(player, toolId)
      if not canThrow then
         if reason == "AlreadyThrown" then
            print(`player already has a thrown weapon`)
         elseif reason == "InvalidToolId" then
            print(`invalid toolId`)
         elseif reason == "HasForceField" then
            print("player has forcefield")
         end
         return
      end
      local toolData = Tools[toolId]

      ThrownWeapons.Data[player] = {
         ToolId = toolId,
         State = ThrownWeapons.StateEnum.Outgoing,
         ReplicationPart = nil,
         TestRaycastVisualizers = {}
      }
      for i = 1, 3 do
         local part = Instance.new("Part")
         part.Size = Vector3.new(1, 1, 1)
         part.Anchored = true
         part.CanTouch = false
         part.CanQuery = false
         part.CanCollide = false
         part.Parent = workspace
         ThrownWeapons.Data[player].TestRaycastVisualizers[i] = part
      end

      local Logic = getLogic(toolData.LogicClass)
      Logic.throw(player, toolId, toolData, ThrownWeapons.Data[player])
      WeaponService.WeaponThrownTasks:Execute("parallel", player, toolId)
	end)

   -- // Manual recall boomerang
   recallEvent.OnServerEvent:Connect(function(Player: Player)
      local thrownWeaponData = ThrownWeapons.Data[Player]
      if not thrownWeaponData then
         print(`player has no thrown weapon to recall`)
         return
      end

      local toolData = Tools[thrownWeaponData.ToolId]
      local Logic = getLogic(toolData.LogicClass)
      Logic.recall(Player, thrownWeaponData.ToolId, toolData, thrownWeaponData)
   end)

   -- // Reset boomerangs when starting/stopping game
   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.IsInRound:Subscribe(function(isInRound: boolean)
      for player, thrownWeaponData in pairs(ThrownWeapons.Data) do
         local toolData = Tools[thrownWeaponData.ToolId]
         local Logic = getLogic(toolData.LogicClass)
         Logic.removeFromField(player, thrownWeaponData)
      end
   end)

end

function WeaponService.start() end

function WeaponService.test() end

return WeaponService