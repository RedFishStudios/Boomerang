-- Boomerang leaves a trail of fire

local FireBoomerang = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local ExplosiveBoomerang = require(ReplicatedStorage.Shared.Logics.PickupLogics.ExplosiveBoomerang)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)

local spawnFireTrail = SimpleRemotes.getUnreliableEvent("SpawnFireTrail")

local PickupService
local ToolController
local WaterEnvironmentLogic = require(ReplicatedStorage.Shared.Logics.Environment.Water)

local isServer = RunService:IsServer()

if isServer then
   PickupService = require(game:GetService("ServerStorage").Server.Core.PickupService)
else
   ToolController = require(ReplicatedStorage.Client.Core.ToolController)
end

local TRAIL_LIFETIME = 3
local MIN_TRAIL_DISTANCE = 4
local DIRECTION_CHANGE_DEGREES = 35
local DIRECTION_CHANGE_DOT = math.cos(math.rad(DIRECTION_CHANGE_DEGREES))
local MAX_SURFACE_RAYCAST_DISTANCE = 9
local MAX_SURFACE_RAYCAST_ITERATIONS = 64
local MIN_MOVEMENT_DISTANCE = 0.01
local FIRE_EFFECT_DAMAGE_FREQUENCY = 1
local FIRE_EFFECT_DAMAGE = 5
local FIRE_EFFECT_LASTS = 10
local FIRE_EFFECT_UPDATE_RATE = 1 / 20
local TRAIL_DAMAGE_DISTANCE = 2
local DASH_TO_EXTINGUISH = 5
local ON_FIRE_EFFECT_ID = "OnFire"
local DASH_ABILITY_ID = "Dash"
local EXPLOSION_LIFETIME = 9
local EXPLOSION_DAMAGE_RADIUS = 10

type TrailRecord = {
   Particle: Part,
   SpawnedAt: number,
}

type LogicalTrailRecord = {
   Position: Vector3,
   SpawnedAt: number,
}

type LogicalExplosionRecord = {
   Position: Vector3,
   ExpiresAt: number,
}

type MovementTrailState = {
   LastMovementPosition: Vector3?,
   LastSpawnPosition: Vector3?,
   LastDirection: Vector3?,
}

type ServerEffectState = MovementTrailState & {
   DisconnectMovement: () -> (),
}

type FireEffectState = MovementTrailState & {
   EndsAt: number,
   NextDamageAt: number,
   LivePickupId: string,
   DashCount: number,
}

local serverEffectsByPlayer: {[Player]: ServerEffectState} = {}
local fireEffectsByPlayer: {[Player]: FireEffectState} = {}
local logicalTrails: {LogicalTrailRecord} = {}
local logicalExplosions: {LogicalExplosionRecord} = {}
local clientTrails: {TrailRecord} = {}
local nextClientTrailId = 0
local heartbeatConnection: RBXScriptConnection? = nil
local serverUpdateAccumulator = 0

local function clearServerEffect(player: Player)
   local state = serverEffectsByPlayer[player]
   if state then
      serverEffectsByPlayer[player] = nil
      state.DisconnectMovement()
   end
end

local function shouldSpawnTrail(state: MovementTrailState, newPosition: Vector3): boolean
   local changedDirection = false
   local previousPosition = state.LastMovementPosition
   if previousPosition then
      local movement = newPosition - previousPosition
      if movement.Magnitude >= MIN_MOVEMENT_DISTANCE then
         local direction = movement.Unit
         changedDirection = state.LastDirection ~= nil and state.LastDirection:Dot(direction) <= DIRECTION_CHANGE_DOT
         state.LastDirection = direction
      end
   end
   state.LastMovementPosition = newPosition

   local farEnough = state.LastSpawnPosition == nil
      or (newPosition - state.LastSpawnPosition).Magnitude >= MIN_TRAIL_DISTANCE
   if not farEnough and not changedDirection then
      return false
   end

   state.LastSpawnPosition = newPosition
   return true
end

local function spawnServerTrail(position: Vector3)
   local waterRaycastParams = RaycastParams.new()
   waterRaycastParams.CollisionGroup = CollisionGroupConstants.WaterDetector
   waterRaycastParams.FilterType = Enum.RaycastFilterType.Include
   waterRaycastParams.FilterDescendantsInstances = WaterEnvironmentLogic.getCurrentWaterParts()
   local waterResult = workspace:Raycast(
      position,
      -Vector3.yAxis * MAX_SURFACE_RAYCAST_DISTANCE,
      waterRaycastParams
   )
   if waterResult then
      return
   end

   table.insert(logicalTrails, {
      Position = position,
      SpawnedAt = workspace:GetServerTimeNow(),
   })
   spawnFireTrail:FireAllClients(position)
end

local function removeFireEffect(player: Player)
   local state = fireEffectsByPlayer[player]
   if not state then
      return
   end

   fireEffectsByPlayer[player] = nil
   PickupLibrary.removePickupEffectActive(player.UserId, state.LivePickupId, nil, false)
end

local function applyFireEffect(player: Player)
   if not isServer or fireEffectsByPlayer[player] or PickupLibrary.hasPickupEffectActive(player.UserId, ON_FIRE_EFFECT_ID) then
      return
   end
   if HitboxLibrary.isImmunized(player) then
      print(`cancelling fire, player is immunized`)
      return
   end
   if #WaterEnvironmentLogic.getTouchingWaters(player) > 0 then
      print(`cancelling fire, player is in water`)
      return
   end

   local now = workspace:GetServerTimeNow()
   local livePickupId = `OnFire_{player.UserId}`
   fireEffectsByPlayer[player] = {
      LastMovementPosition = nil,
      LastSpawnPosition = nil,
      LastDirection = nil,
      EndsAt = now + FIRE_EFFECT_LASTS,
      NextDamageAt = now + FIRE_EFFECT_DAMAGE_FREQUENCY,
      LivePickupId = livePickupId,
      DashCount = 0,
   }
   PickupLibrary.setPickupEffectActive(player.UserId, livePickupId, ON_FIRE_EFFECT_ID, now + FIRE_EFFECT_LASTS)
end

local function updateServer(deltaTime: number)
   serverUpdateAccumulator += deltaTime
   if serverUpdateAccumulator < FIRE_EFFECT_UPDATE_RATE then
      return
   end
   serverUpdateAccumulator %= FIRE_EFFECT_UPDATE_RATE

   local now = workspace:GetServerTimeNow()
   for trailIndex = #logicalTrails, 1, -1 do
      if now - logicalTrails[trailIndex].SpawnedAt >= TRAIL_LIFETIME then
         table.remove(logicalTrails, trailIndex)
      end
   end
   for explosionIndex = #logicalExplosions, 1, -1 do
      if now >= logicalExplosions[explosionIndex].ExpiresAt then
         table.remove(logicalExplosions, explosionIndex)
      end
   end

   for player, state in pairs(fireEffectsByPlayer) do
      if now >= state.EndsAt or player.Parent == nil then
         removeFireEffect(player)
         continue
      end

      local character = player.Character
      local rootPart = character and character.PrimaryPart
      if rootPart and shouldSpawnTrail(state, rootPart.Position) then
         spawnServerTrail(rootPart.Position)
      end

      if now >= state.NextDamageAt then
         state.NextDamageAt = now + FIRE_EFFECT_DAMAGE_FREQUENCY
         local humanoid = character and character:FindFirstChildOfClass("Humanoid")
         if humanoid then
            humanoid:TakeDamage(FIRE_EFFECT_DAMAGE)
         end
      end
   end

   for _, player in ipairs(GameStateLibrary.getGameStateData().LivingPlayersInArena:Get()) do
      if fireEffectsByPlayer[player] or PickupLibrary.hasPickupEffectActive(player.UserId, ON_FIRE_EFFECT_ID) then
         continue
      end

      local character = player.Character
      local rootPart = character and character.PrimaryPart
      if not rootPart then
         continue
      end

      for _, trail in ipairs(logicalTrails) do
         if (rootPart.Position - trail.Position).Magnitude <= TRAIL_DAMAGE_DISTANCE then
            applyFireEffect(player)
            break
         end
      end

      if fireEffectsByPlayer[player] then
         continue
      end

      for _, explosion in ipairs(logicalExplosions) do
         if (rootPart.Position - explosion.Position).Magnitude <= EXPLOSION_DAMAGE_RADIUS then
            applyFireEffect(player)
            break
         end
      end
   end
end

local function updateClient()
   local now = os.clock()
   for trailIndex = #clientTrails, 1, -1 do
      local trail = clientTrails[trailIndex]
      if now - trail.SpawnedAt >= TRAIL_LIFETIME then
         if trail.Particle.Parent then
            ParticlesLibrary.destroy(trail.Particle, true)
         end
         table.remove(clientTrails, trailIndex)
      end
   end
end

local function raycastTrailSurface(origin: Vector3): RaycastResult?
   local raycastParams = RaycastParams.new()
   raycastParams.FilterType = Enum.RaycastFilterType.Exclude

   local ignoredInstances: {Instance} = {}
   local endPosition = origin - Vector3.yAxis * MAX_SURFACE_RAYCAST_DISTANCE
   local currentOrigin = origin

   for _ = 1, MAX_SURFACE_RAYCAST_ITERATIONS do
      local remainingDirection = endPosition - currentOrigin
      if remainingDirection.Magnitude <= 1e-6 then
         return nil
      end

      raycastParams.FilterDescendantsInstances = ignoredInstances
      local result = workspace:Raycast(currentOrigin, remainingDirection, raycastParams)
      if not result then
         return nil
      end

      local hit = result.Instance
      local playerCharacters = workspace:FindFirstChild("PlayerCharacters")
      local isPlayerCharacter = playerCharacters ~= nil and hit:IsDescendantOf(playerCharacters)
      if hit.CanCollide and hit.Transparency ~= 1 and not isPlayerCharacter then
         return result
      end

      table.insert(ignoredInstances, hit)
      currentOrigin = result.Position
   end

   return nil
end

function FireBoomerang.onPickup(player: Player, _timestamp: number?): number?
   local endsAt = workspace:GetServerTimeNow() + GlobalConfig.GenericEffectTimeout
   if isServer then
      clearServerEffect(player)

      local state: ServerEffectState
      state = {
         LastMovementPosition = nil,
         LastSpawnPosition = nil,
         LastDirection = nil,
         DisconnectMovement = SharedTasks.ThrownWeaponMoved:Add(function(weaponPlayer: Player, _toolId: string, newPosition: Vector3)
            if weaponPlayer ~= player then
               return
            end

            if shouldSpawnTrail(state, newPosition) then
               spawnServerTrail(newPosition)
            end
         end),
      }
      serverEffectsByPlayer[player] = state
   else
      ToolController.addParticleToTool(player, "FireBoomerang")
   end

   return endsAt
end

function FireBoomerang.onEnd(player: Player, _cancelCode: number?): number?
   if isServer then
      clearServerEffect(player)
   else
      ToolController.removeParticleFromTool(player, "FireBoomerang")
   end
end

local function _init()
   if heartbeatConnection then
      return
   end

   if isServer then
      ExplosiveBoomerang.ExplosionOccurred:Add(function(player: Player, explosionCFrame: CFrame)
         if not PickupLibrary.hasPickupEffectActive(player.UserId, script.Name) then
            return
         end
         local particleId = `FireExplosion_{player.UserId}_{workspace:GetServerTimeNow()}`
         ParticlesLibrary.play(particleId, "FireExplosion", explosionCFrame.Position, nil, EXPLOSION_LIFETIME, true)
         table.insert(logicalExplosions, {
            Position = explosionCFrame.Position,
            ExpiresAt = workspace:GetServerTimeNow() + EXPLOSION_LIFETIME,
         })
         PickupService.triggerEnd(player, script.Name)
      end)
      SharedTasks.PlayerUsedAbility:Add(function(player: Player, abilityId: string)
         if abilityId ~= DASH_ABILITY_ID then
            return
         end

         local state = fireEffectsByPlayer[player]
         if not state then
            return
         end

         state.DashCount += 1
         if state.DashCount >= DASH_TO_EXTINGUISH then
            removeFireEffect(player)
         end
      end)
      WaterEnvironmentLogic.PlayerEnteredWater:Add(function(player: Player)
         if fireEffectsByPlayer[player] then
            removeFireEffect(player)
         end
      end)
      heartbeatConnection = RunService.Heartbeat:Connect(updateServer)
   else
      spawnFireTrail.OnClientEvent:Connect(function(position: Vector3)
         local raycastResult = raycastTrailSurface(position)
         if not raycastResult then
            return
         end

         nextClientTrailId += 1
         local particleId = `FireBoomerang_{nextClientTrailId}`
         local particle = ParticlesLibrary.play(particleId, "FireTrail", raycastResult.Position, nil, nil, true)
         if particle then
            table.insert(clientTrails, {
               Particle = particle,
               SpawnedAt = os.clock(),
            })
         end
      end)

      heartbeatConnection = RunService.Heartbeat:Connect(updateClient)
   end
end

_init()

return FireBoomerang