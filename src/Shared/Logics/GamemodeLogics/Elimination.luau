-- // Test game mode: First player to throw boomerang 3 times wins

local EliminationRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local isServer = RunService:IsServer()
local ArenaService, GameTeamService, RoundCyclingService, WeaponService, StormCloseService, SpawnService
if isServer then
   ArenaService = require(ServerStorage.Server.Core.ArenaService)
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
   RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
   WeaponService = require(ServerStorage.Server.Core.WeaponService)
   StormCloseService = require(ServerStorage.Server.Core.StormCloseService)
   SpawnService = require(ServerStorage.Server.Core.SpawnService)
end

local PerMatchDestroyerFunctions: {()->()} = {}

local function clear()
   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)
end

function EliminationRoundLogic.setup()
   if isServer then
      clear()
      GameTeamService.setFreeForAll()
      StormCloseService.begin(ArenaService.getCurrentArenaPosition() or Vector3.new(0, 0, 0))

      table.insert(PerMatchDestroyerFunctions, CurrentGameState.getGameStateData().LivingPlayersInArena:Subscribe(function(livingPlayers: {Player})
         if #livingPlayers <= 1 and not (RunService:IsStudio() and #game.Players:GetPlayers() == 1) then
            local winner = livingPlayers[1]
            EliminationRoundLogic.teardown(winner)
         end
      end))
   end
end

function EliminationRoundLogic.teardown(winner: Player?)
   if isServer then
      if not winner then
         warn(`Elimination: no winner found`)
      end
      clear()
      CurrentGameState.RoundFinishedTasks:Execute("parallel", winner, winner and (winner.Name .. " won!") or "No winner")
   end
end

return EliminationRoundLogic