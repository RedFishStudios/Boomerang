local ClassicRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)

local ServerReferential = ServerStorage.Server.Referential
local CurrentGameState = require(ServerReferential.CurrentGameState)

local timeRemaining: number = nil

local function clear()
   timeRemaining = nil
end

function ClassicRoundLogic.setup()
   timeRemaining = 10
   GameTeamService.setFreeForAll()

   task.spawn(function()
      while timeRemaining and timeRemaining > 0 do
         task.wait(1)
         timeRemaining -= 1
         print(`time remaining: {timeRemaining}`)
         if timeRemaining == 0 then
            print("Time's up!")
            ClassicRoundLogic.teardown()
         end
      end
   end)
end

function ClassicRoundLogic.teardown()
   clear()
   CurrentGameState.RoundFinishedTasks:Execute("parallel")
end

return ClassicRoundLogic