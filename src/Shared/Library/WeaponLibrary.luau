local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

local WeaponLibrary = {}

local function hasForceField(character: Model): boolean
   return character:FindFirstChildWhichIsA("ForceField") ~= nil
end

function WeaponLibrary.canThrow(player: Player, toolId: string): (boolean, string?)
   local gameStateData = GameStateLibrary.getGameStateData()
   if not gameStateData.IsInRound:Get() then
      return false, "NotInRound"
   end

   if ThrownWeapons.Data[player] then
      return false, "AlreadyThrown"
   end

   local toolData = Tools[toolId]
   if not toolData then
      return false, "InvalidToolId"
   end

   local character = player.Character
   if not character then
      return false, "NoCharacter"
   end

   if hasForceField(character) then
      return false, "HasForceField"
   end

   return true
end

return WeaponLibrary
