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
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local ExplosiveBoomerang = require(ReplicatedStorage.Shared.Logics.PickupLogics.ExplosiveBoomerang)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local GameplayPhaseEnums = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local spawnFireTrail = SimpleRemotes.getUnreliableEvent("SpawnFireTrail")

local PickupService
local ToolController
local WaterEnvironmentLogic = require(ReplicatedStorage.Shared.Logics.Environment.Water)
local PermanentFireEnvironmentLogic = require(ReplicatedStorage.Shared.Logics.Environment.PermanentFire)

local isServer = RunService:IsServer()

if isServer then
   PickupService = require(game:GetService("ServerStorage").Server.Core.PickupService)
else
   ToolController = require(ReplicatedStorage.Client.Core.ToolController)
end

local TRAIL_LIFETIME = 3
local PARTICLE_TRAIL_DISTANCE = 2
local OWNER_TRAIL_MINIMUM_DISTANCE = 3
local DIRECTION_CHANGE_DEGREES = 35
local DIRECTION_CHANGE_DOT = math.cos(math.rad(DIRECTION_CHANGE_DEGREES))
local MAX_SURFACE_RAYCAST_DISTANCE = 9
local MAX_SURFACE_RAYCAST_ITERATIONS = 64
local MIN_MOVEMENT_DISTANCE = 0.01
local FIRE_EFFECT_DAMAGE_FREQUENCY = 1
local FIRE_EFFECT_DAMAGE = 10
local FIRE_EFFECT_LASTS = 15
local FIRE_EFFECT_UPDATE_RATE = 1 / 20
local TRAIL_DAMAGE_CROSS_SECTION = Vector3.new(4, 4, MIN_MOVEMENT_DISTANCE)
local DASH_TO_EXTINGUISH = 5
local ON_FIRE_EFFECT_ID = "OnFire"
local DASH_ABILITY_ID = "Dash"
local EXPLOSION_LIFETIME = 9
local EXPLOSION_DAMAGE_RADIUS = 10
local FIRE_EFFECT_TOOL_ID = "FireEffect"

type TrailRecord = {
   Particle: Part,
   SpawnedAt: number,
}

type TrailSegmentRecord = {
   StartPosition: Vector3,
   EndPosition: Vector3,
   SpawnedAt: number,
   Attacker: Player,
   SelfHitAttacker: Player?,
}

type LogicalExplosionRecord = {
   Position: Vector3,
   ExpiresAt: number,
   Attacker: Player,
}

type MovementTrailState = {
   LastMovementPosition: Vector3?,
   LastSpawnPosition: Vector3?,
   LastDirection: Vector3?,
}

type ServerEffectState = {
   TrailState: MovementTrailState,
   HasSpawnedThrownTrail: boolean,
   DisconnectMovement: () -> (),
   DisconnectRemoval: () -> (),
}

type FireEffectState = {
   TrailState: MovementTrailState,
   EndsAt: number,
   NextDamageAt: number,
   LivePickupId: string,
   DashCount: number,
   Attacker: Player?,
   KillCredited: boolean,
}

local serverEffectsByPlayer: {[Player]: ServerEffectState} = {}
local fireEffectsByPlayer: {[Player]: FireEffectState} = {}
local trailSegments: {TrailSegmentRecord} = {}
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
      state.DisconnectRemoval()
   end
end

local function shouldSpawnTrail(state: MovementTrailState, newPosition: Vector3, minimumDistance: number): boolean
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
      or (newPosition - state.LastSpawnPosition).Magnitude >= minimumDistance
   if not farEnough and not changedDirection then
      return false
   end

   state.LastSpawnPosition = newPosition
   return true
end

local function canSpawnTrailAt(position: Vector3): boolean
   local waterRaycastParams = RaycastParams.new()
   waterRaycastParams.CollisionGroup = CollisionGroupConstants.WaterDetector
   waterRaycastParams.FilterType = Enum.RaycastFilterType.Include
   waterRaycastParams.FilterDescendantsInstances = WaterEnvironmentLogic.getCurrentWaterParts()
   local waterResult = workspace:Raycast(
      position,
      -Vector3.yAxis * MAX_SURFACE_RAYCAST_DISTANCE,
      waterRaycastParams
   )
   return waterResult == nil
end

local function recordTrailSegment(startPosition: Vector3, endPosition: Vector3, attacker: Player, selfHitAttacker: Player?)
   table.insert(trailSegments, {
      StartPosition = startPosition,
      EndPosition = endPosition,
      SpawnedAt = workspace:GetServerTimeNow(),
      Attacker = attacker,
      SelfHitAttacker = selfHitAttacker,
   })
end

local function spawnParticleTrail(position: Vector3)
   spawnFireTrail:FireAllClients(position)
end

local function updateTrailSamples(
   state: FireEffectState | ServerEffectState,
   position: Vector3,
   attacker: Player,
   selfHitAttacker: Player?
): boolean
   if not canSpawnTrailAt(position) then
      return false
   end

   local previousTrailPosition = state.TrailState.LastSpawnPosition
   if shouldSpawnTrail(state.TrailState, position, PARTICLE_TRAIL_DISTANCE) then
      if previousTrailPosition and (position - previousTrailPosition).Magnitude >= MIN_MOVEMENT_DISTANCE then
         recordTrailSegment(previousTrailPosition, position, attacker, selfHitAttacker)
      end
      spawnParticleTrail(position)
      return true
   end

   return false
end

local function trailSegmentHitsCharacter(segment: TrailSegmentRecord, character: Model): boolean
   local movement = segment.EndPosition - segment.StartPosition
   if movement.Magnitude < MIN_MOVEMENT_DISTANCE then
      return false
   end

   local castDirection = movement.Unit
   local castMargin = TRAIL_DAMAGE_CROSS_SECTION.Z
   local castStart = segment.StartPosition - castDirection * castMargin
   local raycastParams = RaycastParams.new()
   raycastParams.FilterType = Enum.RaycastFilterType.Include
   raycastParams.FilterDescendantsInstances = {character}
   raycastParams.CollisionGroup = CollisionGroupConstants.HandWeapons
   raycastParams.RespectCanCollide = false

   local result = workspace:Blockcast(
      CFrame.lookAt(castStart, castStart + castDirection),
      TRAIL_DAMAGE_CROSS_SECTION,
      movement + castDirection * castMargin * 2,
      raycastParams
   )
   return result ~= nil and result.Instance.CollisionGroup == CollisionGroupConstants.Players
end

local function removeFireEffect(player: Player)
   local state = fireEffectsByPlayer[player]
   if not state then
      return
   end

   fireEffectsByPlayer[player] = nil
   PickupLibrary.removePickupEffectActive(player.UserId, state.LivePickupId, nil, false)
end

local function applyFireEffect(player: Player, attacker: Player?)
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
      TrailState = {
         LastMovementPosition = nil,
         LastSpawnPosition = nil,
         LastDirection = nil,
      },
      EndsAt = now + FIRE_EFFECT_LASTS,
      NextDamageAt = now + FIRE_EFFECT_DAMAGE_FREQUENCY,
      LivePickupId = livePickupId,
      DashCount = 0,
      Attacker = if attacker ~= player then attacker else nil,
      KillCredited = false,
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
   for trailIndex = #trailSegments, 1, -1 do
      if now - trailSegments[trailIndex].SpawnedAt >= TRAIL_LIFETIME then
         table.remove(trailSegments, trailIndex)
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
      local gameStateData = GameStateLibrary.getGameStateData()
      local currentPhase = gameStateData.GameplayPhase:Get()

      local character = player.Character
      local rootPart = character and character.PrimaryPart
      if rootPart then
         updateTrailSamples(state, rootPart.Position, player, state.Attacker)
      end

      if now >= state.NextDamageAt and currentPhase == GameplayPhaseEnums.RoundActive then
         state.NextDamageAt = now + FIRE_EFFECT_DAMAGE_FREQUENCY
         local humanoid = character and character:FindFirstChildOfClass("Humanoid")
         if humanoid and humanoid.Health > 0 then
            humanoid:TakeDamage(FIRE_EFFECT_DAMAGE)
            if humanoid.Health <= 0 and state.Attacker and state.Attacker ~= player and not state.KillCredited then
               state.KillCredited = true
               CombatLibrary.PlayerKilledPlayerTasks:Execute("parallel", state.Attacker, player, FIRE_EFFECT_TOOL_ID)
            end
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

      for _, segment in ipairs(trailSegments) do
         if trailSegmentHitsCharacter(segment, character) then
            local attacker = if segment.Attacker == player then segment.SelfHitAttacker else segment.Attacker
            applyFireEffect(player, attacker)
            break
         end
      end

      if fireEffectsByPlayer[player] then
         continue
      end

      for _, explosion in ipairs(logicalExplosions) do
         if (rootPart.Position - explosion.Position).Magnitude <= EXPLOSION_DAMAGE_RADIUS then
            applyFireEffect(player, explosion.Attacker)
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
            ParticlesLibrary.destroy(trail.Particle, false)
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
         TrailState = {
            LastMovementPosition = nil,
            LastSpawnPosition = nil,
            LastDirection = nil,
         },
         HasSpawnedThrownTrail = false,
         DisconnectRemoval = SharedTasks.ThrownWeaponRemoved:Add(function(weaponPlayer: Player, _toolId: string)
            if weaponPlayer ~= player then
               return
            end

            state.TrailState.LastMovementPosition = nil
            state.TrailState.LastSpawnPosition = nil
            state.TrailState.LastDirection = nil
            state.HasSpawnedThrownTrail = false
         end),
         DisconnectMovement = SharedTasks.ThrownWeaponMoved:Add(function(
            weaponPlayer: Player,
            _toolId: string,
            newPosition: Vector3,
            isRecalling: boolean
         )
            if weaponPlayer ~= player then
               return
            end

            local character = player.Character
            local rootPart = character and character.PrimaryPart
            if not rootPart then
               return
            end

            local isNearOwner = (newPosition - rootPart.Position).Magnitude < OWNER_TRAIL_MINIMUM_DISTANCE
            if not state.HasSpawnedThrownTrail and isNearOwner then
               return
            end
            if isRecalling and isNearOwner then
               return
            end

            state.HasSpawnedThrownTrail = updateTrailSamples(state, newPosition, player, nil) or state.HasSpawnedThrownTrail
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
   local gameStateData = GameStateLibrary.getGameStateData()

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
            Attacker = player,
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
      PermanentFireEnvironmentLogic.PlayerTouchedFire:Add(function(player: Player, permanentfirePart: BasePart)
         if not fireEffectsByPlayer[player] then
            applyFireEffect(player, nil)
         end
      end)
      gameStateData.GameplayPhase:Subscribe(function(newPhase: string)
         if newPhase == GameplayPhaseEnums.LobbyVoting or newPhase == GameplayPhaseEnums.LobbyEnded then
            for player, _ in pairs(fireEffectsByPlayer) do
               removeFireEffect(player)
            end
         end
      end)
      PlayersUtil.PlayerRemoving:Add(function(player: Player)
         if fireEffectsByPlayer[player] then
            removeFireEffect(player)
         end
      end)
      PlayersUtil.CharacterDied:Add(function(player: Player)
         if fireEffectsByPlayer[player] then
            removeFireEffect(player)
         end
      end)
      PlayersUtil.CharacterDestroying:Add(function(player: Player)
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