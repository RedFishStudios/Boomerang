-- // Handles behavior of thrown weapons

--[[
  Handles equipping/unequipping of tools to the character
  - Boomerangs, shuricans, fans, special weapons, etc
]]

local WeaponService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local _CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local _PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local _ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local _RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local ClashedWeapons = require(ReplicatedStorage.Shared.Referential.ClashedWeapons)
local ClashedWeaponLogic = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Clashed)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local GameStateLibrary= require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local WeaponLibrary = require(ReplicatedStorage.Shared.Library.WeaponLibrary)
local _ArenaService = require(ServerStorage.Server.Core.ArenaService)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local _AnimationService = require(ServerStorage.Server.Core.AnimationService)
local CharacterService = require(ServerStorage.Server.Core.CharacterService)
local _HitboxService = require(ServerStorage.Server.Core.HitboxService)
local PlayerStatsLibrary = require(ReplicatedStorage.Shared.Library.PlayerStatsLibrary)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local SkinService = require(ServerStorage.Server.Core.SkinService)

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

type WeaponKilledPlayerTask = (attacker: Player, victim: Player, toolId: string) -> ()
type WeaponStruckObjectTask = (player: Player, toolId: string, raycastResult: RaycastResult) -> ()
type WeaponReachedEventPointTask = (player: Player, toolId: string, position: Vector3) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local aimEvent = SimpleRemotes.getEvent("WeaponAim")
local aimStateEvent = SimpleRemotes.getEvent("WeaponAimState")
local aimCancelEvent = SimpleRemotes.getEvent("WeaponAimCancel") -- // Client left aiming without throwing (T-060)
local throwFunction = SimpleRemotes.getFunction("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")
local weaponEquipStateEvent = SimpleRemotes.getEvent("WeaponEquipState")

local aiming: {[Player]: number} = {}
local equippedToolIds: {[Player]: string} = {}
local equippedToolVisible: {[Player]: boolean} = {}

-- The TweenWalkSpeed functions exclusively and purely exist to hide conflicts between CharacterController and server authoritative positioning

local function tweenWalkSpeed(player: Player, humanoid: Humanoid, targetWalkSpeed: number, tweenDuration: number, tweenExponent: number, shouldContinue: (() -> boolean)?): boolean
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
      PlayerStatsLibrary.setStat(player, "CurrentSpeed", targetWalkSpeed, nil, nil)
      return true
   end

   return false
end

local function tweenWalkSpeedInverse(player: Player, humanoid: Humanoid, targetWalkSpeed: number, tweenDuration: number, tweenExponent: number): boolean
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
      PlayerStatsLibrary.setStat(player, "CurrentSpeed", targetWalkSpeed, nil, nil)
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

WeaponService.WeaponKilledPlayer = TasksList.new() :: TasksList.TasksList<WeaponKilledPlayerTask>
WeaponService.WeaponStruckObject = TasksList.new() :: TasksList.TasksList<WeaponStruckObjectTask>
WeaponService.WeaponReachedEventPoint = TasksList.new() :: TasksList.TasksList<WeaponReachedEventPointTask>

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

local function playerIsWeaponLocked(player: Player): boolean
   local lockedUntil = PlayerStatsLibrary.getStat(player, "WeaponLockedUntilTimestamp")
   if not lockedUntil then
      return false
   end
   local isLocked = game.Workspace:GetServerTimeNow() < lockedUntil
   if not isLocked then
      PlayerStatsLibrary.setStat(player, "WeaponLockedUntilTimestamp", nil, nil, true)
   end
   return isLocked
end

local function throwForPlayer(
   player: Player,
   toolId: string,
   direction: Vector3?,
   startPosition: Vector3?,
   timeSinceAiming: number,
   aimStrengthAlpha: number
)
   if playerIsWeaponLocked(player) then
      return
   end

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

   local character = player.Character
   if not character or not character.PrimaryPart then
      return
   end

   local toolData = Tools[toolId]
   local trustedDirection = getHorizontalDirection(direction or character.PrimaryPart.CFrame.LookVector)
   local trustedStartPosition = character.PrimaryPart.Position + trustedDirection * 3
   if startPosition then
      local maxStartDistanceFromCharacter = 12
      local distanceFromCharacter = (startPosition - character.PrimaryPart.Position).Magnitude
      if distanceFromCharacter <= maxStartDistanceFromCharacter then
         trustedStartPosition = startPosition
      end
   end

   ThrownWeapons.Data[player] = {
      OwnerUserId = player.UserId,
      ToolId = toolId,
      State = ThrownWeapons.StateEnum.Outgoing,
      ReplicationPart = nil,
   }

   local logic = getLogic(toolData.LogicClass)
   if not logic or not logic.throw then
      warn(`WeaponService: no throw logic found for {toolData.LogicClass}`)
      return
   end
   logic.throw(player, toolId, toolData, ThrownWeapons.Data[player], {
      Direction = trustedDirection,
      StartPosition = trustedStartPosition,
      TimeSinceAiming = timeSinceAiming,
      AimStrengthAlpha = aimStrengthAlpha,
   })
   SharedTasks.WeaponThrownTasks:Execute("serial", player, toolId)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The tool the player is currently holding (nil when they have none, e.g. no character)
function WeaponService.getEquippedToolId(player: Player): string?
   return equippedToolIds[player]
end

function WeaponService.isAiming(player: Player): boolean
   return aiming[player] ~= nil
end

function WeaponService.clashWeapon(player: Player, thrownWeaponData: ThrownWeapons.Data, direction: Vector3, position: Vector3)
   local toolData = Tools[thrownWeaponData.ToolId]
   if not toolData then
      return
   end

   local logic = getLogic(toolData.LogicClass)
   if logic and logic.clash then
      logic.clash(player, thrownWeaponData, {
         Direction = direction,
         Position = position,
      })
   end
end

function WeaponService.playerIsWeaponLocked(player: Player): boolean
   return WeaponLibrary.playerIsWeaponLocked(player)
end

-- // Ends a player's aim without a throw: back to free motion and normal walk speed, and every client hides the aim
-- // arrow (T-060). Used when the weapon gets locked and when the client cancels its aim.
local function cancelAiming(player: Player)
   if aiming[player] == nil then
      return
   end
   aiming[player] = nil
   PlayerStatsLibrary.setStat(player, "CurrentMovementState", "FreeMotion", nil, nil)
   local character = player.Character
   local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
   if humanoid then
      task.spawn(
         tweenWalkSpeedInverse,
         player,
         humanoid,
         PlayerStatsLibrary.getStat(player, "RunSpeed") or GlobalConfig.DefaultWalkSpeed,
         AIM_WALK_SPEED_RETURN_TWEEN_DURATION,
         AIM_WALK_SPEED_RETURN_TWEEN_EXPONENT
      )
   end
   aimStateEvent:FireAllClients(player.UserId, false)
end

function WeaponService.applyLockOnWeapon(player: Player, forTime: number)
   cancelAiming(player) -- // T-060: a locked weapon can't stay aimed (the client drops its aim too)
   PlayerStatsLibrary.setStat(player, "WeaponLockedUntilTimestamp", game.Workspace:GetServerTimeNow() + forTime)

   local thrownWeaponData = ThrownWeapons.Data[player]
   if not thrownWeaponData then
      local clashedWeaponData = ClashedWeapons.Data[player]
      if clashedWeaponData then
         ClashedWeaponLogic.removeFromField(player, clashedWeaponData, false)
      end
      return
   end

   local toolData = Tools[thrownWeaponData.ToolId]
   if not toolData then
      if thrownWeaponData.MovementConnection then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
      end
      if thrownWeaponData.Host then
         thrownWeaponData.Host:Destroy()
      end
      ThrownWeapons.Data[player] = nil
      return
   end

   local logic = getLogic(toolData.LogicClass)
   if logic and logic.removeFromField then
      logic.removeFromField(player, thrownWeaponData, {
         ReturnToPlayer = false,
      })
   end
end

function WeaponService.removeLockOnWeapon(player: Player)
   PlayerStatsLibrary.setStat(player, "WeaponLockedUntilTimestamp", nil)
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

   -- // T-077 Telekinesis: the owning client streams its desired steer direction while the effect is active and its
   -- // boomerang is in flight. Validate here (server is authoritative) and store it on the thrown weapon.
   local telekinesisSteerEvent = SimpleRemotes.getUnreliableEvent("TelekinesisSteer")
   telekinesisSteerEvent.OnServerEvent:Connect(function(player: Player, direction: unknown)
      if typeof(direction) ~= "Vector3" then
         return
      end
      local horizontal = Vector3.new(direction.X, 0, direction.Z)
      if horizontal.Magnitude < 1e-3 then
         return
      end
      local thrownWeaponData = ThrownWeapons.Data[player]
      if not thrownWeaponData then
         return
      end
      if not PickupLibrary.isEffectActive(player.UserId, "TelekinesisBoomerang") then
         return
      end
      thrownWeaponData.TelekinesisBias = horizontal.Unit
   end)

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
      if WeaponService.playerIsWeaponLocked(player) then
         return
      end
      toolId = equippedToolIds[player] or toolId -- // The server decides the weapon class (from the equipped skin)

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
      PlayerStatsLibrary.setStat(player, "CurrentMovementState", "Aiming", nil, nil)

      task.spawn(function()
         tweenWalkSpeed(
            player,
            humanoid,
            BoomerangTuningLibrary.getForAnyTool(if type(toolId) == "string" then toolId else nil, "AimWalkSpeed"), -- // T-067
            AIM_WALK_SPEED_TWEEN_DURATION,
            AIM_WALK_SPEED_TWEEN_EXPONENT,
            function()
               return aiming[player] ~= nil
            end
         )
      end)

      aimStateEvent:FireAllClients(player.UserId, true)

      -- Client-only animation replication will handle this later.
   end)

   aimCancelEvent.OnServerEvent:Connect(function(player: Player)
      cancelAiming(player)
   end)

   -- // Throw boomerang
   throwFunction.OnServerInvoke = function(player: Player, toolId: string, clientDirection: Vector3?, clientStartPosition: Vector3?)
      toolId = equippedToolIds[player] or toolId -- // The server decides the weapon class (from the equipped skin)
      local timeSinceAiming = os.clock() - (aiming[player] or os.clock())
      local chargeTime = BoomerangTuningLibrary.getForAnyTool(if type(toolId) == "string" then toolId else nil, "ChargeTime") -- // T-066
      timeSinceAiming = math.clamp(timeSinceAiming, 0, chargeTime)
      local aimStrengthAlpha = timeSinceAiming / chargeTime

      aiming[player] = nil
      PlayerStatsLibrary.setStat(player, "CurrentMovementState", "FreeMotion", nil, nil)
      local character = player.Character
      local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
      if humanoid then
         task.spawn(function()
            tweenWalkSpeedInverse(
               player,
               humanoid,
               PlayerStatsLibrary.getStat(player, "RunSpeed") or GlobalConfig.DefaultWalkSpeed,
               AIM_WALK_SPEED_RETURN_TWEEN_DURATION,
               AIM_WALK_SPEED_RETURN_TWEEN_EXPONENT
            )
         end)
      end
      aimStateEvent:FireAllClients(player.UserId, false)
      
      -- Client-only animation replication will handle this later.

      if GlobalConfig.SyncAbilitiesToEveryPlayer then
         for _, throwPlayer in ipairs(Players:GetPlayers()) do
            if throwPlayer == player then
               throwForPlayer(
                  throwPlayer,
                  toolId,
                  if typeof(clientDirection) == "Vector3" then clientDirection else nil,
                  if typeof(clientStartPosition) == "Vector3" then clientStartPosition else nil,
                  timeSinceAiming,
                  aimStrengthAlpha
               )
            else
               throwForPlayer(
                  throwPlayer,
                  toolId,
                  CharacterService.getLookDirection(throwPlayer),
                  nil,
                  timeSinceAiming,
                  aimStrengthAlpha
               )
            end
         end
      else
         throwForPlayer(
            player,
            toolId,
            if typeof(clientDirection) == "Vector3" then clientDirection else nil,
            if typeof(clientStartPosition) == "Vector3" then clientStartPosition else nil,
            timeSinceAiming,
            aimStrengthAlpha
         )
      end
	end

   -- // Boomerang visibility/removing visibility from client
   SharedTasks.WeaponThrownTasks:Add(function(player: Player, toolId: string)
      if equippedToolIds[player] then
         equippedToolVisible[player] = false
         weaponEquipStateEvent:FireAllClients(player.UserId, "SetVisible", false)
      end
   end)
   SharedTasks.WeaponReturnedTasks:Add(function(player: Player, toolId: string)
      if equippedToolIds[player] then
         equippedToolVisible[player] = true
         weaponEquipStateEvent:FireAllClients(player.UserId, "SetVisible", true)
      end
   end)

   -- // Manual recall. The client sends true on press and false on release (nil = a plain tap/press).
   -- // Live boomerang: a press recalls it (no need to hold). Dying/dead boomerang: it returns only while held;
   -- // releasing drops it back into the dead state. Safe to toggle rapidly: each press/release is one state change.
   recallEvent.OnServerEvent:Connect(function(Player: Player, isPressed: unknown)
      if isPressed == nil then
         isPressed = true
      end
      if type(isPressed) ~= "boolean" then
         return
      end

      local thrownWeaponData = ThrownWeapons.Data[Player]
      if isPressed then
         if thrownWeaponData then
            local toolData = Tools[thrownWeaponData.ToolId]
            local Logic = toolData and getLogic(toolData.LogicClass)
            if Logic then
               Logic.recall(Player, thrownWeaponData.ToolId, toolData, thrownWeaponData)
            end
            return
         end
         local clashedWeaponData = ClashedWeapons.Data[Player]
         local toolData = clashedWeaponData and Tools[clashedWeaponData.ToolId]
         local Logic = toolData and getLogic(toolData.LogicClass)
         if Logic and Logic.recallFromClashed then
            Logic.recallFromClashed(Player, clashedWeaponData, true)
         end
      elseif thrownWeaponData and thrownWeaponData.RecallFromDead then
         local toolData = Tools[thrownWeaponData.ToolId]
         local Logic = toolData and getLogic(toolData.LogicClass)
         if Logic and Logic.stopRecallFromDead then
            Logic.stopRecallFromDead(Player, thrownWeaponData)
         end
      end
   end)

   PlayersUtil.CharacterLoaded:Add(function(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
         -- // Stats come from the equipped skin's weapon class; clients get the skin's model name
         local equippedToolId = SkinLibrary.getWeaponClass(player)
         if equippedToolId ~= nil then
            equippedToolIds[player] = equippedToolId
            equippedToolVisible[player] = true
            weaponEquipStateEvent:FireAllClients(player.UserId, "Equip", SkinLibrary.getModelName(player))
         else
            equippedToolIds[player] = nil
            equippedToolVisible[player] = nil
         end
   end)

   -- // Skin changed (equipped in the Skins menu, or applied when the profile loads): swap the held model
   SkinService.SkinEquippedTasks:Add(function(player: Player, _skinId: string)
      if not equippedToolIds[player] then
         return
      end
      equippedToolIds[player] = SkinLibrary.getWeaponClass(player) or equippedToolIds[player]
      weaponEquipStateEvent:FireAllClients(player.UserId, "Equip", SkinLibrary.getModelName(player))
      if equippedToolVisible[player] == false then
         weaponEquipStateEvent:FireAllClients(player.UserId, "SetVisible", false)
      end
   end)

   PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
      if aiming[player] ~= nil then
         aiming[player] = nil
         PlayerStatsLibrary.setStat(player, "CurrentMovementState", "FreeMotion", nil, nil)
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
      local clashedWeaponData = ClashedWeapons.Data[player]
      if clashedWeaponData then
         ClashedWeaponLogic.removeFromField(player, clashedWeaponData, false)
      end
   end)

   PlayersUtil.PlayerAdded:Add(function(joiningPlayer: Player)
      for player, equippedToolId in pairs(equippedToolIds) do
         if player.Character and player.Character.Parent then
            weaponEquipStateEvent:FireClient(joiningPlayer, player.UserId, "Equip", SkinLibrary.getModelName(player) or equippedToolId)
            if equippedToolVisible[player] == false and (ThrownWeapons.Data[player] or ClashedWeapons.Data[player]) then
               weaponEquipStateEvent:FireClient(joiningPlayer, player.UserId, "SetVisible", false)
            end
         end
      end
   end)

   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      aiming[player] = nil
      PlayerStatsLibrary.setStat(player, "CurrentMovementState", "FreeMotion", nil, nil)
      equippedToolIds[player] = nil
      equippedToolVisible[player] = nil
      local clashedWeaponData = ClashedWeapons.Data[player]
      if clashedWeaponData then
         ClashedWeaponLogic.removeFromField(player, clashedWeaponData, false)
      end
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player, _character: Model, _humanoid: Humanoid)
      if aiming[player] ~= nil then
         aiming[player] = nil
         PlayerStatsLibrary.setStat(player, "CurrentMovementState", "FreeMotion", nil, nil)
         aimStateEvent:FireAllClients(player.UserId, false)
      end

      local thrownWeaponData = ThrownWeapons.Data[player]
      if not thrownWeaponData then
         local clashedWeaponData = ClashedWeapons.Data[player]
         if clashedWeaponData then
            ClashedWeaponLogic.removeFromField(player, clashedWeaponData, false)
         end
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
   gameStateData.CurrentRoundData:Subscribe(function()
      for player, thrownWeaponData in pairs(ThrownWeapons.Data) do
         local toolData = Tools[thrownWeaponData.ToolId]
         local Logic = getLogic(toolData.LogicClass)
         Logic.removeFromField(player, thrownWeaponData)
      end
      for player, clashedWeaponData in pairs(ClashedWeapons.Data) do
         ClashedWeaponLogic.removeFromField(player, clashedWeaponData, false)
      end
      for p, _ in pairs(aiming) do
         PlayerStatsLibrary.setStat(p, "CurrentMovementState", "FreeMotion", nil, nil)
         aiming[p] = nil
         aimStateEvent:FireAllClients(p.UserId, false)
         local character = p.Character
         if character and character:FindFirstChild("Humanoid") then
            PlayerStatsLibrary.setStat(p, "CurrentSpeed", PlayerStatsLibrary.getStat(p, "RunSpeed") or GlobalConfig.DefaultWalkSpeed, nil, nil)
         end
      end
   end)
end

function WeaponService.start() end

function WeaponService.test() end

return WeaponService