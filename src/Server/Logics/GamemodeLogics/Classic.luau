local ClassicRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
local CurrentGameState = require(ReplicatedStorage.Shared.Referential.CurrentGameState)

function ClassicRoundLogic.setup()
   GameTeamService.setFreeForAll()
end

function ClassicRoundLogic.teardown()
   -- TODO: get winner by tracking kills
   local winner = game.Players:FindFirstChildWhichIsA("Player")
   CurrentGameState.RoundFinishedTasks:Execute("parallel", winner, "TODO: get winner")
end

return ClassicRoundLogic