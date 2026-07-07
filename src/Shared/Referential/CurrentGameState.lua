local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

type RoundFinishedTask = ()->()

local CurrentGameState: {
   IsInRound: boolean,
   Gamemode: string?, -- If in a round
   CurrentMapName: string?, -- If in a round
   RemainingTime: number?, -- If in a round

   LivingPlayersInArena: {Player},
   LivingPlayersInArenaUpdatedTasks: TasksList.TasksList<({Player})->()>,
   RoundFinishedTasks: TasksList.TasksList<()->()>, -- Should be called only from within the GamemodeLogics module

   -- Copied over from Gamemodes data when a round is set
   CanRespawn: boolean?
} = {
   IsInRound = false,
   Gamemode = nil,
   CurrentMapName = nil,
   RemainingTime = nil,
   CanRespawn = nil,

   LivingPlayersInArena = {},
   LivingPlayersInArenaUpdatedTasks = TasksList.new(),
   RoundFinishedTasks = TasksList.new()
}

return CurrentGameState