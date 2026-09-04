-- // Test game mode: First player to throw boomerang 3 times wins

local ThrowBoomerangRoundLogic = {} 

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local isServer = RunService:IsServer()
local GameTeamService, RoundCyclingService, WeaponService
if isServer then
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
   RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
   WeaponService = require(ServerStorage.Server.Core.WeaponService)
end

local PerPlayerCount: {
   [Player]: number
} = {}
local winner: Player? = nil

local PerMatchDestroyerFunctions: {()->()} = {}

local function clear()
   for _, destroyer in pairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)
   table.clear(PerPlayerCount)
end

function ThrowBoomerangRoundLogic.setup()
   if isServer then
      clear()
      GameTeamService.setFreeForAll()
      table.insert(PerMatchDestroyerFunctions, SharedTasks.WeaponThrownTasks:Add(function(player: Player, toolId: string)
         PerPlayerCount[player] = (PerPlayerCount[player] or 0) + 1
         if PerPlayerCount[player] >= 5 then
            winner = player
            ThrowBoomerangRoundLogic.teardown()
         end
      end))

      table.insert(PerMatchDestroyerFunctions, PlayersUtil.GameEnteredTooFewPlayers:Add(function()
         ThrowBoomerangRoundLogic.teardown()
      end))
   end
end

function ThrowBoomerangRoundLogic.teardown()
   if isServer then
      clear()
      CurrentGameState.RoundFinishedTasks:Execute("parallel", winner, winner and (winner.Name .. " won!") or "No winner")
   end
end

return ThrowBoomerangRoundLogic