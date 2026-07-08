-- // Test game mode: First player to throw boomerang 3 times wins

local EliminationRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
local WeaponService = require(ServerStorage.Server.Core.WeaponService)
local StormCloseService = require(ServerStorage.Server.Core.StormCloseService)
local SpawnService = require(ServerStorage.Server.Core.SpawnService)

local CurrentGameState = require(ReplicatedStorage.Shared.Referential.CurrentGameState)

local PerMatchDestroyerFunctions: {()->()} = {}

local function clear()
   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)
end

function EliminationRoundLogic.setup()
   clear()
   GameTeamService.setFreeForAll()
   StormCloseService.begin(ArenaService.getCurrentArenaPosition() or Vector3.new(0, 0, 0))

   table.insert(PerMatchDestroyerFunctions, CurrentGameState.LivingPlayersInArenaUpdatedTasks:Add(function(livingPlayers: {Player})
      if #livingPlayers <= 1 then
         EliminationRoundLogic.teardown()
      end
   end))
end

function EliminationRoundLogic.teardown()
   clear()
   CurrentGameState.RoundFinishedTasks:Execute("parallel")
end

return EliminationRoundLogic