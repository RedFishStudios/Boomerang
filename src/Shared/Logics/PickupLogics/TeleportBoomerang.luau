local TeleportBoomerang = {}

local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()
local PICKUP_CLASS_ID = script.Name
local EFFECT_DURATION_SECONDS = 8

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ParticlesLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("ParticlesLibrary"))

local WeaponService, PickupService
local CharacterRenderController
if isServer then
   local ServerStorage = game:GetService("ServerStorage")
   WeaponService = require(ServerStorage.Server.Core.WeaponService)
   PickupService = require(ServerStorage.Server.Core.PickupService)
else
   CharacterRenderController = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Core"):WaitForChild("CharacterRenderController"))
end

local particles = {} -- {[Player]: Part}

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

local function applyTeleport(player: Player, position: Vector3)
   if not isServer or not PickupService or not PickupService.hasPickupEffectActive(player, PICKUP_CLASS_ID) then
      return
   end
   local character = player.Character
   if not character or not character.PrimaryPart then
      return
   end

   character:PivotTo(CFrame.new(position) * character:GetPivot().Rotation)
   PickupService.triggerEnd(player, PICKUP_CLASS_ID)
end

function TeleportBoomerang.onPickup(player: Player, startedAt: number?): number?
   local endsAt = (startedAt or workspace:GetServerTimeNow()) + EFFECT_DURATION_SECONDS
   
   if isServer then
      clearSubscriptions(player)
      cleanupFunctionsByPlayer[player] = {
         WeaponService.WeaponKilledPlayer:Add(function(attacker: Player, victim: Player)
            if attacker == player then
               local victimCharacter = victim.Character
               if victimCharacter and victimCharacter.PrimaryPart then
                  applyTeleport(player, victimCharacter.PrimaryPart.Position)
               end
            end
         end),
         --WeaponService.WeaponStruckObject:Add(function(eventPlayer: Player, _toolId: string, raycastResult: RaycastResult)
         --   if eventPlayer == player then
         --      applyTeleport(player, raycastResult.Position)
         --   end
         --end),
         WeaponService.WeaponReachedEventPoint:Add(function(eventPlayer: Player, _toolId: string, position: Vector3)
            if eventPlayer == player then
               applyTeleport(player, position)
            end
         end),
      }
   else
      local character = CharacterRenderController.getCharacterModel(player)
      if not character then
         return
      end

      local particle = ParticlesLibrary.play(`{player.UserId}_Forcefield`, "Forcefield", character.PrimaryPart, 1)
      particles[player] = particle
   end

   return endsAt
end

function TeleportBoomerang.onEnd(player: Player)
   if isServer then
      clearSubscriptions(player)
   else
      if particles[player] then
         particles[player]:Destroy()
         particles[player] = nil
      end

      local character = CharacterRenderController.getCharacterModel(player)
      if not character then
         return
      end
      ParticlesLibrary.emit(`{player.UserId}_ForcefieldBreak`, "ForcefieldBreak", character.PrimaryPart, 1)
   end
end

return TeleportBoomerang