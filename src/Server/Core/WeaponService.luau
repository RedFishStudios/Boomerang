-- // Handles behavior of thrown weapons

--[[
  Handles equipping/unequipping of tools to the character
  - Boomerangs, shuricans, fans, special weapons, etc
]]

local WeaponService = {}

local Players = game:GetService("Players")
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
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local AnimationService = require(ServerStorage.Server.Core.AnimationService)
local AnimationLibrary = require(ReplicatedStorage.Shared.Library.AnimationLibrary)
local CharacterService = require(ServerStorage.Server.Core.CharacterService)
local HitboxService = require(ServerStorage.Server.Core.HitboxService)
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
type WeaponReturnedTask = (player: Player, toolId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local aimEvent = SimpleRemotes.getEvent("WeaponAim")
local aimStateEvent = SimpleRemotes.getEvent("WeaponAimState")
local throwEvent = SimpleRemotes.getEvent("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")
local weaponEquipStateEvent = SimpleRemotes.getEvent("WeaponEquipState")

local aiming: {[Player]: number} = {}
local equippedToolIds: {[Player]: string} = {}
local equippedToolVisible: {[Player]: boolean} = {}

local function getHorizontalDirection(direction: Vector3): Vector3
   local horizontal = Vector3.new(direction.X, 0, direction.Z)
   if horizontal.Magnitude <= 1e-5 then
      return Vector3.new(0, 0, -1)
   end
   return horizontal.Unit
end

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

WeaponService.WeaponThrownTasks = TasksList.new() :: TasksList.TasksList<WeaponThrownTask>
WeaponService.WeaponReturnedTasks = TasksList.new() :: TasksList.TasksList<WeaponReturnedTask>

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
   SimpleRemotes.getEvent("WeaponEquipState")
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

   aimEvent.OnServerEvent:Connect(function(player: Player, toolId, clientPosition: Vector3)
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
      
      -- TODO: compensate this without using the hitbox and with a better authoritative positioning system
      --local serverPosition = character.Hitbox:GetPivot().Position
      --local authoritativePosition = serverPosition + (clientPosition - serverPosition) * 0.5
      --character:PivotTo(CFrame.new(authoritativePosition))

      aiming[player] = os.clock()
      humanoid.WalkSpeed = GlobalConfig.AimingWalkSpeed
      aimStateEvent:FireAllClients(player.UserId, true)

      AnimationLibrary.playCoreAnimation(player, "Charging")
   end)

   -- // Throw boomerang
   throwEvent.OnServerEvent:Connect(function(player: Player, toolId: string, clientDirection: Vector3?, clientStartPosition: Vector3?)
      local timeSinceAiming = os.clock() - (aiming[player] or os.clock())
      timeSinceAiming = math.clamp(timeSinceAiming, 0, GlobalConfig.AimFullStrength)
      local aimStrengthAlpha = timeSinceAiming / GlobalConfig.AimFullStrength
      print("aim strength alpha: ", aimStrengthAlpha)

      aiming[player] = nil
      local character = player.Character
      local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
      if humanoid then
         humanoid.WalkSpeed = GlobalConfig.DefaultWalkSpeed
      end
      aimStateEvent:FireAllClients(player.UserId, false)
      
      AnimationLibrary.playCoreAnimation(player, "Throw")

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

      if not character or not character.PrimaryPart then
         return
      end

      local trustedDirection = getHorizontalDirection(
         if typeof(clientDirection) == "Vector3" then clientDirection else character.PrimaryPart.CFrame.LookVector
      )
      local trustedStartPosition = character.PrimaryPart.Position + trustedDirection * 3
      if typeof(clientStartPosition) == "Vector3" then
         local maxStartDistanceFromCharacter = 12
         local distanceFromCharacter = (clientStartPosition - character.PrimaryPart.Position).Magnitude
         if distanceFromCharacter <= maxStartDistanceFromCharacter then
            trustedStartPosition = clientStartPosition
         end
      end

      ThrownWeapons.Data[player] = {
         ToolId = toolId,
         State = ThrownWeapons.StateEnum.Outgoing,
         ReplicationPart = nil,
         TestRaycastVisualizers = {}
      }

      local Logic = getLogic(toolData.LogicClass)
      if not Logic or not Logic.throw then
         warn(`WeaponService: no throw logic found for {toolData.LogicClass}`)
         return
      end
      Logic.throw(player, toolId, toolData, ThrownWeapons.Data[player], {
         Direction = trustedDirection,
         StartPosition = trustedStartPosition,
         TimeSinceAiming = timeSinceAiming,
         AimStrengthAlpha = aimStrengthAlpha,
      })
      WeaponService.WeaponThrownTasks:Execute("parallel", player, toolId)
	end)

   -- // Boomerang visibility/removing visibility from client
   -- TODO: This will likely later be clientside rendered using animation events to appear/disappear at the right point in the throw/catch animation
   WeaponService.WeaponThrownTasks:Add(function(player: Player, toolId: string)
      if equippedToolIds[player] then
         equippedToolVisible[player] = false
         weaponEquipStateEvent:FireAllClients(player.UserId, "SetVisible", false)
      end
   end)
   WeaponService.WeaponReturnedTasks:Add(function(player: Player, toolId: string)
      if equippedToolIds[player] then
         equippedToolVisible[player] = true
         weaponEquipStateEvent:FireAllClients(player.UserId, "SetVisible", true)
      end
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

   PlayersUtil.CharacterLoaded:Add(function(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
      local equippedBoomerang = "ClassicBoomerang" -- TODO: get from player data
        equippedToolIds[player] = equippedBoomerang
        equippedToolVisible[player] = true
        weaponEquipStateEvent:FireAllClients(player.UserId, "Equip", equippedBoomerang)
   end)

   PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
        if equippedToolIds[player] then
          weaponEquipStateEvent:FireAllClients(player.UserId, "Unequip")
      end
        equippedToolIds[player] = nil
        equippedToolVisible[player] = nil

      local thrownWeaponData = ThrownWeapons.Data[player]
      if thrownWeaponData then
         local toolData = Tools[thrownWeaponData.ToolId]
         local Logic = getLogic(toolData.LogicClass)
         Logic.removeFromField(player, thrownWeaponData)
      end
   end)

   PlayersUtil.PlayerAdded:Add(function(joiningPlayer: Player)
      for player, equippedToolId in pairs(equippedToolIds) do
         if player.Character and player.Character.Parent then
            weaponEquipStateEvent:FireClient(joiningPlayer, player.UserId, "Equip", equippedToolId)
            if equippedToolVisible[player] == false then
               weaponEquipStateEvent:FireClient(joiningPlayer, player.UserId, "SetVisible", false)
            end
         end
      end
   end)

   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      equippedToolIds[player] = nil
      equippedToolVisible[player] = nil
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player, _character: Model, _humanoid: Humanoid)
      local thrownWeaponData = ThrownWeapons.Data[player]
      if not thrownWeaponData then
         return
      end
      local host = thrownWeaponData.Host
      if not host then
         return
      end
      local currentCharacter = player.Character
      if not currentCharacter or not currentCharacter.PrimaryPart or not currentCharacter.Parent or not currentCharacter.PrimaryPart.Parent then
         local toolData = Tools[thrownWeaponData.ToolId]
         local Logic = getLogic(toolData.LogicClass)
         Logic.removeFromField(player, thrownWeaponData)
      end
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