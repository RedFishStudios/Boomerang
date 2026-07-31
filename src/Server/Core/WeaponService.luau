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
local RunService = game:GetService("RunService")

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

local AIM_WALK_SPEED_TWEEN_DURATION = 0.495
local AIM_WALK_SPEED_TWEEN_EXPONENT = 2.4
local AIM_WALK_SPEED_RETURN_TWEEN_DURATION = 0.42
local AIM_WALK_SPEED_RETURN_TWEEN_EXPONENT = 2.0

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
local throwFunction = SimpleRemotes.getFunction("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")
local weaponEquipStateEvent = SimpleRemotes.getEvent("WeaponEquipState")

local aiming: {[Player]: number} = {}
local equippedToolIds: {[Player]: string} = {}
local equippedToolVisible: {[Player]: boolean} = {}

-- The TweenWalkSpeed functions exclusively and purely exist to hide conflicts between CharacterController and server authoritative positioning

local function tweenWalkSpeed(humanoid: Humanoid, targetWalkSpeed: number, tweenDuration: number, tweenExponent: number, shouldContinue: (() -> boolean)?): boolean
   local initialWalkSpeed = humanoid.WalkSpeed
   local elapsed = 0

   while humanoid.Parent and elapsed < tweenDuration do
      local _, deltaTime = RunService.Stepped:Wait()
      if not humanoid.Parent then
         return false
      end
      if shouldContinue and not shouldContinue() then
         return false
      end

      elapsed += deltaTime
      local alpha = math.clamp(elapsed / tweenDuration, 0, 1)
      local easedAlpha = alpha ^ tweenExponent
      humanoid.WalkSpeed = initialWalkSpeed + (targetWalkSpeed - initialWalkSpeed) * easedAlpha
   end

   if humanoid.Parent and (not shouldContinue or shouldContinue()) then
      humanoid.WalkSpeed = targetWalkSpeed
      return true
   end

   return false
end

local function tweenWalkSpeedInverse(humanoid: Humanoid, targetWalkSpeed: number, tweenDuration: number, tweenExponent: number): boolean
   local initialWalkSpeed = humanoid.WalkSpeed
   local elapsed = 0

   while humanoid.Parent and elapsed < tweenDuration do
      local _, deltaTime = RunService.Stepped:Wait()
      if not humanoid.Parent then
         return false
      end

      elapsed += deltaTime
      local alpha = math.clamp(elapsed / tweenDuration, 0, 1)
      local easedAlpha = 1 - ((1 - alpha) ^ tweenExponent)
      humanoid.WalkSpeed = initialWalkSpeed + (targetWalkSpeed - initialWalkSpeed) * easedAlpha
   end

   if humanoid.Parent then
      humanoid.WalkSpeed = targetWalkSpeed
      return true
   end

   return false
end

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

function WeaponService.isAiming(player: Player): boolean
   return aiming[player] ~= nil
end

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

      aiming[player] = os.clock()

      task.spawn(function()
         tweenWalkSpeed(
            humanoid,
            GlobalConfig.AimingWalkSpeed,
            AIM_WALK_SPEED_TWEEN_DURATION,
            AIM_WALK_SPEED_TWEEN_EXPONENT,
            function()
               return aiming[player] ~= nil
            end
         )
      end)

      aimStateEvent:FireAllClients(player.UserId, true)

      AnimationLibrary.playCoreAnimation(player, "Charging")
   end)

   -- // Throw boomerang
   throwFunction.OnServerInvoke = function(player: Player, toolId: string, clientDirection: Vector3?, clientStartPosition: Vector3?)
      local timeSinceAiming = os.clock() - (aiming[player] or os.clock())
      timeSinceAiming = math.clamp(timeSinceAiming, 0, GlobalConfig.AimFullStrength)
      local aimStrengthAlpha = timeSinceAiming / GlobalConfig.AimFullStrength

      aiming[player] = nil
      local character = player.Character
      local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
      if humanoid then
         task.spawn(function()
            tweenWalkSpeedInverse(
               humanoid,
               GlobalConfig.DefaultWalkSpeed,
               AIM_WALK_SPEED_RETURN_TWEEN_DURATION,
               AIM_WALK_SPEED_RETURN_TWEEN_EXPONENT
            )
         end)
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
      for i = 1, 3 do
         local visualizer = Instance.new("Part")
         visualizer.Name = "TestRaycastVisualizer"
         visualizer.Shape = Enum.PartType.Ball
         visualizer.Size = Vector3.new(0.5, 0.5, 0.5)
         visualizer.Material = "Neon"
         visualizer.Anchored = true
         visualizer.CanCollide = false
         visualizer.CanQuery = false
         visualizer.CanTouch = false
         visualizer.Transparency = 0.5
         visualizer.Color = Color3.fromRGB(255, 0, 0)
         visualizer.Parent = workspace
         table.insert(ThrownWeapons.Data[player].TestRaycastVisualizers, visualizer)
      end

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
	end

   -- // Boomerang visibility/removing visibility from client
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
      if aiming[player] ~= nil then
         aiming[player] = nil
         aimStateEvent:FireAllClients(player.UserId, false)
      end

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
      aiming[player] = nil
      equippedToolIds[player] = nil
      equippedToolVisible[player] = nil
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player, _character: Model, _humanoid: Humanoid)
      if aiming[player] ~= nil then
         aiming[player] = nil
         aimStateEvent:FireAllClients(player.UserId, false)
      end

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
         local character = p.Character
         if character and character:FindFirstChild("Humanoid") then
            character.Humanoid.WalkSpeed = GlobalConfig.DefaultWalkSpeed
         end
      end
      for _, p in pairs(game.Players:GetPlayers()) do
         AnimationLibrary.stopAllCoreAnimations(p)
      end
   end)
end

function WeaponService.start() end

function WeaponService.test() end

return WeaponService