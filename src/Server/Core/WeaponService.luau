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
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

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

local aimEvent = SimpleRemotes.getEvent("WeaponAim")
local aimStateEvent = SimpleRemotes.getEvent("WeaponAimState")
local throwEvent = SimpleRemotes.getEvent("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")

local aiming: {[Player]: number} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

WeaponService.WeaponThrownTasks = TasksList.new() :: TasksList.TasksList<WeaponThrownTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(toolId: string)
	if not ToolLogicModules[toolId] then
      local _module = ToolLogics:WaitForChild(toolId, 5)
      if not _module then
         warn(`WeaponService.getLogic: Tool logic module {toolId} not found`)
         return
      end
		local module = require(_module)
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

   aimEvent.OnServerEvent:Connect(function(player: Player, toolId)
      local canAim = WeaponLibrary.canThrow(player, toolId)
      if not canAim then
         return
      end

      local character = player.Character
      if not character then
         return
      end

      local humanoid = character:FindFirstChildWhichIsA("Humanoid")
      if not humanoid then
         return
      end

      aiming[player] = os.clock()
      humanoid.WalkSpeed = 0
      aimStateEvent:FireAllClients(player.UserId, true)
   end)

   -- // Throw boomerang
	throwEvent.OnServerEvent:Connect(function(player: Player, toolId: string)
      local timeSinceAiming = os.clock() - (aiming[player] or os.clock())
      timeSinceAiming = math.clamp(timeSinceAiming, 0, GlobalConfig.AimFullStrength)
      local aimStrengthAlpha = timeSinceAiming / GlobalConfig.AimFullStrength

      aiming[player] = nil
      local character = player.Character
      local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
      if humanoid then
         humanoid.WalkSpeed = 16
      end
      aimStateEvent:FireAllClients(player.UserId, false)

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
      if not Logic or not Logic.throw then
         warn(`WeaponService: no throw logic found for {toolData.LogicClass}`)
         return
      end
      Logic.throw(player, toolId, toolData, ThrownWeapons.Data[player], {
         TimeSinceAiming = timeSinceAiming,
         AimStrengthAlpha = aimStrengthAlpha,
      })
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
      for p, _ in pairs(aiming) do
         aiming[p] = nil
         aimStateEvent:FireAllClients(p.UserId, false)
      end
   end)
end

function WeaponService.start() end

function WeaponService.test() end

return WeaponService