local ClassicRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)

local ServerReferential = ServerStorage.Server.Referential
local CurrentGameState = require(ServerReferential.CurrentGameState)

function ClassicRoundLogic.setup()
   GameTeamService.setFreeForAll()
end

function ClassicRoundLogic.teardown()
   CurrentGameState.RoundFinishedTasks:Execute("parallel")
end

return ClassicRoundLogic