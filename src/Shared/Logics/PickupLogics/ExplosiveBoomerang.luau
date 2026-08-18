-- STUD
-- TODO
-- Boomerang explodes at the end of the next throw

local ExplosiveBoomerang = {}

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))
local ParticlesLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("ParticlesLibrary"))
local PlayerStatsLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("PlayerStatsLibrary"))
local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("Sounds"))
local SoundLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("SoundLibrary"))
local GameStateLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameStateLibrary"))
local CombatLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("CombatLibrary"))

local isServer = RunService:IsServer()

local PickupService, WeaponService
if isServer then
   local ServerStorage = game:GetService("ServerStorage")
   WeaponService = require(ServerStorage.Server.Core.WeaponService)
   PickupService = require(ServerStorage.Server.Core.PickupService)
end

local cleanupFunctionsByPlayer: {[Player]: {() -> ()}} = {}

local function clearSubscriptions(player: Player)
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
   if not isServer then
      return
   end

   local raycastParams = RaycastParams.new()
   raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
   raycastParams.FilterDescendantsInstances = {player.Character}
   local raycastResult = workspace:Raycast(position, Vector3.new(0, -100, 0), raycastParams)
   if raycastResult then
      position = raycastResult.Position
   end
   local eventId = `ExplosiveBoomerang_Explosion_{player.UserId}`
   ParticlesLibrary.emit(eventId, "Explosion", position, 3)
   SoundLibrary.play(eventId, Sounds.Data.Explosion.Name, position)
   WeaponService.applyLockOnWeapon(player, 3)
   PickupService.triggerEnd(player, script.Name)

   local gameStateData = GameStateLibrary.getGameStateData()
   local playersInArena = gameStateData.LivingPlayersInArena:Get()
   for _, p in pairs(playersInArena) do
      if p == player then
         continue
      end
      local character = p.Character
      if not character or not character.PrimaryPart then
         continue
      end
      local distance = ((character.PrimaryPart.Position - position)*Vector3.new(1, 0, 1)).Magnitude
      if distance < 12 then
         CombatLibrary.attackHitPlayer(player, nil, p, nil, 10000, true)
      end
   end

   clearSubscriptions(player)
end

function ExplosiveBoomerang.onPickup(player: Player, position: CFrame)
   if isServer then
      cleanupFunctionsByPlayer[player] = {
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
      -- Maybe a sound, gui etc
   end
end

function ExplosiveBoomerang.onEnd(player: Player)
   if isServer then
      clearSubscriptions(player)
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return ExplosiveBoomerang