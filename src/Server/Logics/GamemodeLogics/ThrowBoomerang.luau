-- // Test game mode: First player to throw boomerang 3 times wins

local ThrowBoomerangRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
local WeaponService = require(ServerStorage.Server.Core.WeaponService)
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

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
   clear()
   GameTeamService.setFreeForAll()
   table.insert(PerMatchDestroyerFunctions, WeaponService.WeaponThrownTasks:Add(function(player: Player, toolId: string)
      print("player threw boomerang!")
      PerPlayerCount[player] = (PerPlayerCount[player] or 0) + 1
      if PerPlayerCount[player] >= 12 then
         print(`player has thrown boomerang 3 times and wins`)
         winner = player
         ThrowBoomerangRoundLogic.teardown()
      end
   end))
end

function ThrowBoomerangRoundLogic.teardown()
   clear()
   CurrentGameState.RoundFinishedTasks:Execute("parallel", winner, winner and (winner.Name .. " won!") or "No winner")
end

return ThrowBoomerangRoundLogic