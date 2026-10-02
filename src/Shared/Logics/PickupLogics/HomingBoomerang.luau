local HomingBoomerang = {}

local RunService = game:GetService("RunService")
local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local ToolController

HomingBoomerang.HOMING_INFLUENCE = 3

local isServer = RunService:IsServer()
if isServer then
else
   ToolController = require(ReplicatedStorage.Client.Core.ToolController)
end

local disconnectWeaponThrownByPlayer: {[Player]: () -> ()} = {}

function HomingBoomerang.onPickup(player: Player, timestamp: number?): number
   if isServer then
      local existingDisconnect = disconnectWeaponThrownByPlayer[player]
      if existingDisconnect then
         existingDisconnect()
      end

      disconnectWeaponThrownByPlayer[player] = SharedTasks.WeaponThrownTasks:Add(function(thrownPlayer: Player)
         if thrownPlayer ~= player then
            return
         end

         local thrownWeaponData = ThrownWeapons.Data[player]
         if thrownWeaponData then
            thrownWeaponData.Homing = true
         end
      end)
   else
      ToolController.addParticleToTool(player, "HomingBoomerang")
   end

   local thrownWeaponData = ThrownWeapons.Data[player]
   if thrownWeaponData then
      thrownWeaponData.Homing = true
   end

   return (timestamp or workspace:GetServerTimeNow()) + GlobalConfig.GenericEffectTimeout
end

function HomingBoomerang.onEnd(player: Player)
   local disconnectWeaponThrown = disconnectWeaponThrownByPlayer[player]
   if disconnectWeaponThrown then
      disconnectWeaponThrown()
      disconnectWeaponThrownByPlayer[player] = nil
   end

   local thrownWeaponData = ThrownWeapons.Data[player]
   if thrownWeaponData then
      thrownWeaponData.Homing = nil
   end

   if isServer then
   else
      ToolController.removeParticleFromTool(player, "HomingBoomerang")
   end
end

return HomingBoomerang