-- // Test game mode: First player to throw boomerang 3 times wins

local EliminationRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
local WeaponService = require(ServerStorage.Server.Core.WeaponService)

local ServerReferential = ServerStorage.Server.Referential
local CurrentGameState = require(ServerReferential.CurrentGameState)

local PerMatchDestroyerFunctions: {()->()} = {}

local function clear()
end

function EliminationRoundLogic.setup()
   clear()
   GameTeamService.setFreeForAll()
   task.spawn(function()
      print("ELIMINATION ROUND - PLACEHOLDER")
      task.wait(3)
      EliminationRoundLogic.teardown()
   end)
end

function EliminationRoundLogic.teardown()
   clear()
   CurrentGameState.RoundFinishedTasks:Execute("parallel")
end

return EliminationRoundLogic