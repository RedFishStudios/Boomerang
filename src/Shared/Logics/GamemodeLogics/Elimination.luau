-- // Test game mode: First player to throw boomerang 3 times wins

local EliminationRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

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

      table.insert(PerMatchDestroyerFunctions, GameStateLibrary.PlayerRemovedFromArenaTasks:Add(function(player: Player)
         local livingPlayers = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get()
         if #livingPlayers <= 1 and not (RunService:IsStudio() and #game.Players:GetPlayers() == 1) then
            local winner = livingPlayers[1]
            EliminationRoundLogic.teardown(winner)
         end
      end))

      -- // Only declare a winner if a single involved player remains; otherwise there is no winner
      table.insert(PerMatchDestroyerFunctions, PlayersUtil.GameEnteredTooFewPlayers:Add(function()
         local livingPlayers = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get()
         local winner = if #livingPlayers == 1 then livingPlayers[1] else nil
         EliminationRoundLogic.teardown(winner)
      end))
   end
end

function EliminationRoundLogic.teardown(winner: Player?)
   if isServer then
      if not winner then
         warn(`Elimination: no winner found`)
      end
      clear()
      GameStateLibrary.RoundFinishedTasks:Execute("parallel", winner, winner and (winner.Name .. " won!") or "No winner")
   end
end

return EliminationRoundLogic