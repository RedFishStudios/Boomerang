local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ReactiveValue = require(ReplicatedStorage.Shared.Utils.ReactiveValue)

type RoundFinishedTask = ()->()

local CurrentGameState: {
   IsInRound: boolean,
   Gamemode: string?, -- If in a round
   CurrentMapName: string?, -- If in a round
   RemainingTime: number?, -- If in a round

   LivingPlayersInArena: ReactiveValue.ReactiveValue,
   RoundStartingTasks: TasksList.TasksList<()->()>,
   RoundFinishedTasks: TasksList.TasksList<(winner: Player?, winMessage: string)->()>, -- Should be called only from within the GamemodeLogics module

   -- Copied over from Gamemodes data when a round is set
   CanRespawn: boolean?
} = {
   IsInRound = false,
   Gamemode = nil,
   CurrentMapName = nil,
   RemainingTime = nil,
   CanRespawn = nil,

   LivingPlayersInArena = ReactiveValue.new({}),
   RoundStartingTasks = TasksList.new(),
   RoundFinishedTasks = TasksList.new()
}

return CurrentGameState