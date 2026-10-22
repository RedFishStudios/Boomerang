-- // While active, the player can explode their boomerang with the on-screen button (T-108: UsePickupButtons GUI) while it is out
-- // of their hand, once per throw, and it returns faster. It no longer explodes by itself (end of the throw / first kill).
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
local GameTeamLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameTeamLibrary"))
local PickupLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("PickupLibrary"))

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

-- // T-108: one explosion per throw: the instance id of the boomerang that already exploded (each throw has a new one). Both sides
-- // keep it (the client marks its own press right away, so the button dims without waiting for the server).
local explodedInstanceId: {[Player]: string} = {}

ExplosiveBoomerang.ExplosionOccurred = TasksList.new() :: TasksList.TasksList<(player: Player, explosionCFrame: CFrame) -> ()>

ExplosiveBoomerang.UseButton = true

local function applyExplosion(player: Player, position: Vector3)
   if not isServer then
      return
   end

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

-- // T-108: usable while the player's boomerang is out of their hand and hasn't exploded yet this throw
function ExplosiveBoomerang.canUse(player: Player): boolean
   local position, instanceId = PickupLibrary.getWeaponOnField(player)
   return position ~= nil and (instanceId == nil or explodedInstanceId[player] ~= instanceId)
end

-- // T-108: the button was pressed: the boomerang explodes where it is
function ExplosiveBoomerang.onUse(player: Player)
   local position, instanceId = PickupLibrary.getWeaponOnField(player)
   if not position or (instanceId ~= nil and explodedInstanceId[player] == instanceId) then
      return
   end
   if instanceId then
      explodedInstanceId[player] = instanceId
   end
   applyExplosion(player, position)
end

function ExplosiveBoomerang.onPickup(player: Player, startedAt: number?): number
   local endsAt = (startedAt or workspace:GetServerTimeNow()) + EFFECT_DURATION_SECONDS

   if isServer then
      explodedInstanceId[player] = nil
   else
      -- Client context
      ToolController.addParticleToTool(player, "ExplosiveBoomerang")
   end

   return endsAt
end

function ExplosiveBoomerang.onEnd(player: Player)
   explodedInstanceId[player] = nil
   if isServer then
      return
   else
      -- Client context
      ToolController.removeParticleFromTool(player, "ExplosiveBoomerang")
   end
end

return ExplosiveBoomerang