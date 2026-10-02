-- // While active, the boomerang explodes at the end of every throw (or on its first kill), and returns faster.
-- // The faster return is applied in WeaponLogics/Boomerang.recall (speed) and below (shorter weapon lock after an explosion).

local ExplosiveBoomerang = {}

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ParticlesLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("ParticlesLibrary"))
local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("Sounds"))
local SoundLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("SoundLibrary"))
local GameStateLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameStateLibrary"))
local CombatLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("CombatLibrary"))
local GlobalConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))
local TasksList = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"):WaitForChild("TasksList"))
local CollisionGroupConstants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("CollisionGroupConstants"))
local SharedTasks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("SharedTasks"))
local GameTeamLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameTeamLibrary"))

local EFFECT_DURATION_SECONDS = GlobalConfig.GenericEffectTimeout
local BASE_EXPLOSION_WEAPON_LOCK_SECONDS = 3
local EXPLOSION_WEAPON_LOCK_SECONDS = BASE_EXPLOSION_WEAPON_LOCK_SECONDS / GlobalConfig.ExplosiveBoomerangReturnSpeedMultiplier
local isServer = RunService:IsServer()

local PickupService, WeaponService
local ToolController
if isServer then
   local ServerStorage = game:GetService("ServerStorage")
   WeaponService = require(ServerStorage.Server.Core.WeaponService)
   PickupService = require(ServerStorage.Server.Core.PickupService)
else
   ToolController = require(ReplicatedStorage.Client.Core.ToolController)
end

local cleanupFunctionsByPlayer: {[Player]: {() -> ()}} = {}
local explodedThisThrow: {[Player]: boolean} = {} -- // One explosion per throw (a kill and the end point could both trigger)

ExplosiveBoomerang.ExplosionOccurred = TasksList.new() :: TasksList.TasksList<(player: Player, explosionCFrame: CFrame) -> ()>

local function clearSubscriptions(player: Player)
   explodedThisThrow[player] = nil
   local cleanupFunctions = cleanupFunctionsByPlayer[player]
   if not cleanupFunctions then
      return
   end
   cleanupFunctionsByPlayer[player] = nil
   for _, cleanup in ipairs(cleanupFunctions) do
      cleanup()
   end
end

local function applyExplosion(player: Player, position: Vector3)
   if not isServer or explodedThisThrow[player] then
      return
   end
   explodedThisThrow[player] = true

   local raycastParams = RaycastParams.new()
   raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
   raycastParams.FilterDescendantsInstances = {player.Character}
   raycastParams.CollisionGroup = CollisionGroupConstants.ArenaFloorDetector
   local raycastResult = workspace:Raycast(position, Vector3.new(0, -100, 0), raycastParams)
   if raycastResult then
      position = raycastResult.Position
   end
   local explosionCFrame = CFrame.new(position)
   local eventId = `ExplosiveBoomerang_Explosion_{player.UserId}`
   ParticlesLibrary.emit(eventId, "Explosion", explosionCFrame.Position, 3)
   ExplosiveBoomerang.ExplosionOccurred:Execute("serial", player, explosionCFrame)
   SoundLibrary.play(eventId, Sounds.Data.Explosion.Name, explosionCFrame.Position)
   WeaponService.applyLockOnWeapon(player, EXPLOSION_WEAPON_LOCK_SECONDS)

   local gameStateData = GameStateLibrary.getGameStateData()
   local playersInArena = gameStateData.LivingPlayersInArena:Get()
   for _, p in pairs(playersInArena) do
      -- // The thrower and their teammates are spared
      if p == player or not GameTeamLibrary.areEnemies(player, p) then
         continue
      end
      local character = p.Character
      if not character or not character.PrimaryPart then
         continue
      end
      local distance = ((character.PrimaryPart.Position - position)*Vector3.new(1, 0, 1)).Magnitude
      if distance < 12 then
         CombatLibrary.attackHitPlayer(player, "ExplosiveBoomerang", p, nil, 10000, true)
      end
   end
   -- // The effect stays active until it times out (onEnd); it no longer ends after the first explosion
end

function ExplosiveBoomerang.onPickup(player: Player, startedAt: number?): number
   local endsAt = (startedAt or workspace:GetServerTimeNow()) + EFFECT_DURATION_SECONDS

   if isServer then
      clearSubscriptions(player) -- // Picking it up again while active refreshes the subscriptions instead of doubling them
      cleanupFunctionsByPlayer[player] = {
         SharedTasks.WeaponThrownTasks:Add(function(thrownPlayer: Player)
            if thrownPlayer == player then
               explodedThisThrow[player] = nil
            end
         end),
         WeaponService.WeaponKilledPlayer:Add(function(attacker: Player, victim: Player)
            if attacker == player then
               local victimCharacter = victim.Character
               if victimCharacter and victimCharacter.PrimaryPart then
                  applyExplosion(player, victimCharacter.PrimaryPart.Position)
               end
            end
         end),
         WeaponService.WeaponReachedEventPoint:Add(function(eventPlayer: Player, _toolId: string, position: Vector3)
            if eventPlayer == player then
               applyExplosion(player, position)
            end
         end),
      }
   else
      -- Client context
      ToolController.addParticleToTool(player, "ExplosiveBoomerang")
   end

   return endsAt
end

function ExplosiveBoomerang.onEnd(player: Player)
   if isServer then
      clearSubscriptions(player)
   else
      -- Client context
      ToolController.removeParticleFromTool(player, "ExplosiveBoomerang")
   end
end

return ExplosiveBoomerang