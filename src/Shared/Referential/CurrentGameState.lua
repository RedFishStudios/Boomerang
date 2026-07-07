local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

type RoundFinishedTask = ()->()

local CurrentGameState: {
   IsInRound: boolean,
   RoundTypeId: string?, -- If in a round
   CurrentMapName: string?, -- If in a round
   RemainingTime: number?, -- If in a round
   RoundFinishedTasks: TasksList.TasksList<RoundFinishedTask>, -- Should be called only from within the GamemodeLogics module

   -- Copied over from Gamemodes data when a round is set
   CanRespawn: boolean?
} = {
   IsInRound = false,
   RoundTypeId = nil,
   CurrentMapName = nil,
   RemainingTime = nil,
   CanRespawn = nil,
   RoundFinishedTasks = TasksList.new()
}

return CurrentGameState