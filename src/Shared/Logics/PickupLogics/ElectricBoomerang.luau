local ElectricBoomerang = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local ExplosiveBoomerang = require(ReplicatedStorage.Shared.Logics.PickupLogics.ExplosiveBoomerang)
local WaterEnvironmentLogic = require(ReplicatedStorage.Shared.Logics.Environment.Water)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GameplayPhaseEnums = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)

local isServer = RunService:IsServer()
local EFFECT_DURATION_SECONDS = GlobalConfig.GenericEffectTimeout
local EXPLOSION_LIFETIME = 1
local ELECTRIFIED_LENGTH = 4
local ZAP_LENGTH = 0
local WATER_RAYCAST_DISTANCE = 9
local ELECTRIC_EXPLOSION_RADIUS = 15

local playZappedAnimation = SimpleRemotes.getEvent("PlayZappedAnimation")

type ZappedState = {
   Character: Model,
   Humanoid: Humanoid,
   OriginalWalkSpeed: number,
   EndsAt: number,
   SourceWaters: {[Instance]: true},
}

type ElectrifiedWaterState = {
   ExpiresAt: number,
}

local electrifiedWaters: {[Instance]: ElectrifiedWaterState} = {}
local zappedPlayers: {[Player]: ZappedState} = {}
local nextElectrificationId = 0

local PickupService
local ToolController
local AnimationController
if isServer then
   PickupService = require(game:GetService("ServerStorage").Server.Core.PickupService)
else
   ToolController = require(ReplicatedStorage.Client.Core.ToolController)
   AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
end

local function clearZapped(player: Player)
   local state = zappedPlayers[player]
   if not state then
      return
   end
   zappedPlayers[player] = nil

   if player.Character == state.Character then
      state.Character.PrimaryPart.Anchored = false
   end
   playZappedAnimation:FireClient(player, false)
end

local function applyZapped(player: Player, sourceWater: Instance?)
   if not isServer then
      return
   end

   local currentPhase = GameStateLibrary.getGameStateData().GameplayPhase
   if currentPhase ~= GameplayPhaseEnums.RoundActive then
      return
   end

   local now = workspace:GetServerTimeNow()
   local existingState = zappedPlayers[player]
   if existingState then
      existingState.EndsAt = math.max(existingState.EndsAt, now + ZAP_LENGTH)
      if sourceWater and electrifiedWaters[sourceWater] then
         existingState.SourceWaters[sourceWater] = true
      end
      return
   end

   local character = player.Character
   local humanoid = character and character:FindFirstChildOfClass("Humanoid")
   local rootPart = character and character.PrimaryPart
   if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
      return
   end

   local state: ZappedState = {
      Character = character,
      OriginalWalkSpeed = humanoid.WalkSpeed,
      EndsAt = now + ZAP_LENGTH,
      SourceWaters = {},
   }
   if sourceWater and electrifiedWaters[sourceWater] then
      state.SourceWaters[sourceWater] = true
      state.EndsAt = electrifiedWaters[sourceWater].ExpiresAt + ZAP_LENGTH
   end
   zappedPlayers[player] = state
   rootPart.Anchored = true

   local velocity = rootPart.AssemblyLinearVelocity
   rootPart.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)

   local particleId = `ElectricPlayer_{player.UserId}_{workspace:GetServerTimeNow()}`
   ParticlesLibrary.play(particleId, "ElectricPlayer", rootPart, nil, state.EndsAt - now)
   SoundLibrary.play(particleId, Sounds.Data.Zapped.Name, rootPart)
   playZappedAnimation:FireClient(player, true)
end

local function electrifyWater(water: Instance)
   if electrifiedWaters[water] then
      return
   end
   electrifiedWaters[water] = {
      ExpiresAt = workspace:GetServerTimeNow() + ELECTRIFIED_LENGTH,
   }

   nextElectrificationId += 1
   local particleId = `ElectrifiedObject_{nextElectrificationId}`
   ParticlesLibrary.playToObjectSize(
      particleId,
      "ElectrifiedObject",
      water,
      nil,
      ELECTRIFIED_LENGTH
   )

   for _, player in ipairs(Players:GetPlayers()) do
      if table.find(WaterEnvironmentLogic.getTouchingWaters(player), water) then
         applyZapped(player, water)
      end
   end
end

local function updateTimedStates()
   local now = workspace:GetServerTimeNow()

   for water, state in pairs(electrifiedWaters) do
      if not water.Parent or now >= state.ExpiresAt then
         electrifiedWaters[water] = nil
      end
   end

   for player, state in pairs(zappedPlayers) do
      if player.Character ~= state.Character or not state.Character.PrimaryPart or state.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
         clearZapped(player)
         continue
      end

      local hasElectrifiedSource = false
      for water in pairs(state.SourceWaters) do
         if electrifiedWaters[water] then
            hasElectrifiedSource = true
         else
            state.SourceWaters[water] = nil
         end
      end

      if hasElectrifiedSource then
         state.EndsAt = now + ZAP_LENGTH
      elseif now >= state.EndsAt then
         clearZapped(player)
      end
   end
end

local function detectWaterBelow(position: Vector3)
   local waterParts = WaterEnvironmentLogic.getCurrentWaterParts()
   if #waterParts == 0 then
      return
   end

   local raycastParams = RaycastParams.new()
   raycastParams.CollisionGroup = CollisionGroupConstants.WaterDetector
   raycastParams.FilterType = Enum.RaycastFilterType.Include
   raycastParams.FilterDescendantsInstances = waterParts

   local result = workspace:Raycast(
      position,
      -Vector3.yAxis * WATER_RAYCAST_DISTANCE,
      raycastParams
   )
   if result then
      electrifyWater(result.Instance)
   end
end

local function applyElectricExplosion(position: Vector3)
   for _, player in ipairs(Players:GetPlayers()) do
      local character = player.Character
      local rootPart = character and character.PrimaryPart
      if rootPart and (rootPart.Position - position).Magnitude <= ELECTRIC_EXPLOSION_RADIUS then
         applyZapped(player)
      end
   end

   local waterParts = WaterEnvironmentLogic.getCurrentWaterParts()
   if #waterParts == 0 then
      return
   end

   local overlapParams = OverlapParams.new()
   overlapParams.CollisionGroup = CollisionGroupConstants.WaterDetector
   overlapParams.FilterType = Enum.RaycastFilterType.Include
   overlapParams.FilterDescendantsInstances = waterParts

   for _, water in ipairs(workspace:GetPartBoundsInRadius(position, ELECTRIC_EXPLOSION_RADIUS, overlapParams)) do
      electrifyWater(water)
   end
end

function ElectricBoomerang.onPickup(player: Player, startedAt: number?): number
   if not isServer then
      ToolController.addParticleToTool(player, "ElectricBoomerang")
   end

   return (startedAt or workspace:GetServerTimeNow()) + EFFECT_DURATION_SECONDS
end

function ElectricBoomerang.onEnd(player: Player)
   if isServer then
   else
      ToolController.removeParticleFromTool(player, "ElectricBoomerang")
   end
end

if isServer then
   SharedTasks.ThrownWeaponMoved:Add(function(
      player: Player,
      _toolId: string,
      newPosition: Vector3,
      _isRecalling: boolean
   )
      if PickupLibrary.hasPickupEffectActive(player.UserId, script.Name) then
         detectWaterBelow(newPosition)
      end
   end)

   WaterEnvironmentLogic.PlayerEnteredWater:Add(function(player: Player, water: Instance)
      if electrifiedWaters[water] then
         applyZapped(player, water)
      end
   end)

   RunService.Heartbeat:Connect(updateTimedStates)

   ExplosiveBoomerang.ExplosionOccurred:Add(function(player: Player, explosionCFrame: CFrame)
      if not PickupLibrary.hasPickupEffectActive(player.UserId, script.Name) then
         return
      end

      local particleId = `ElectricExplosion_{player.UserId}_{workspace:GetServerTimeNow()}`
      ParticlesLibrary.play(
         particleId,
         "ElectricExplosion",
         explosionCFrame.Position,
         nil,
         EXPLOSION_LIFETIME,
         true
      )
      applyElectricExplosion(explosionCFrame.Position)
      PickupService.triggerEnd(player, script.Name)
   end)

   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.GameplayPhase:Subscribe(function(newPhase)
      if newPhase ~= GameplayPhaseEnums.RoundActive then
         for player, _ in pairs(zappedPlayers) do
            clearZapped(player)
         end
         table.clear(electrifiedWaters)
      end
   end)
else
   local zappedAnimationGeneration = 0
   playZappedAnimation.OnClientEvent:Connect(function(isZapped: boolean)
      zappedAnimationGeneration += 1
      local generation = zappedAnimationGeneration
      local player = Players.LocalPlayer
      if isZapped then
         AnimationController.playCoreAnimation(player, "Zapped")
         if generation ~= zappedAnimationGeneration then
            AnimationController.stopCoreAnimation(player, "Zapped")
         end
      else
         AnimationController.stopCoreAnimation(player, "Zapped")
      end
   end)
end

return ElectricBoomerang