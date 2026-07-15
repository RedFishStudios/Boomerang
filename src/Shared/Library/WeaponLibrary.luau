local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

local WeaponLibrary = {}

local function hasForceField(character: Model): boolean
   return character:FindFirstChildWhichIsA("ForceField") ~= nil
end

function WeaponLibrary.canThrow(player: Player, toolId: string): boolean
   local gameStateData = GameStateLibrary.getGameStateData()
   if not gameStateData.IsInRound:Get() then
      print("not in round")
      return false
   end

   if ThrownWeapons.Data[player] then
      print("player already has thrown weapon")
      return false
   end

   local toolData = Tools[toolId]
   if not toolData then
      warn(`WeaponLibrary.canThrow: Tool data not found for toolId {toolId}`)
      return false
   end

   local character = player.Character
   if not character then
      warn(`WeaponLibrary.canThrow: No character found for player {player.Name}`)
      return false
   end

   if hasForceField(character) then
      print("player has forcefield")
      return false
   end

   return true
end

return WeaponLibrary
