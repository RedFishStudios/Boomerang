local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local ClashedWeapons = require(ReplicatedStorage.Shared.Referential.ClashedWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local PlayerStatsLibrary = require(ReplicatedStorage.Shared.Library.PlayerStatsLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local WeaponLibrary = {}

local AimingPlayers: {[number]: boolean} = {}

local function hasForceField(character: Model): boolean
   return character:FindFirstChildWhichIsA("ForceField") ~= nil
end

function WeaponLibrary.playerIsWeaponLocked(player: Player?): boolean
   local lockedUntil = PlayerStatsLibrary.getStat(player or game.Players.LocalPlayer, "WeaponLockedUntilTimestamp")
   return typeof(lockedUntil) == "number" and workspace:GetServerTimeNow() < lockedUntil
end

function WeaponLibrary.canThrow(player: Player, toolId: string): boolean
   local gameStateData = GameStateLibrary.getGameStateData()
   if gameStateData.CurrentRoundData:Get() == nil then
      print("not in round")
      return false
   end

   local livingPlayersInArena = gameStateData.LivingPlayersInArena:Get()
   if not table.find(livingPlayersInArena, player) then
      print("player not in arena")
      return false
   end

   if ThrownWeapons.Data[player] or ClashedWeapons.Data[player] then
      print("player already has thrown weapon")
      return false
   end

   if PickupLibrary.hasPickupEffectActive(player.UserId, "Zapped") then
      print("player is zapped")
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

function WeaponLibrary.init()
   PlayersUtil.PlayerRemoving:Add(function(player)
      AimingPlayers[player.UserId] = nil
   end)
   PlayersUtil.CharacterDied:Add(function(player)
      AimingPlayers[player.UserId] = nil
   end)
end

return WeaponLibrary
