local PlayerStatsLibrary = {}

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local GameplayPhaseEnum = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)

local RunService = game:GetService("RunService")

local initiated = false
local isServer = RunService:IsServer()
local replicatePlayerStat = SimpleRemotes.getEvent("ReplicatePlayerStat")

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type StatKey = "Speed" | "WeaponLockedUntilTimestamp"

export type PlayerStats = {
   [StatKey]: any
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local defaultStats: PlayerStats = {
   Speed = GlobalConfig.DefaultWalkSpeed,
   WeaponLockedUntilTimestamp = nil
}

local playerStats: {[number]: PlayerStats} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PlayerStatsLibrary.StatChangedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, statKey: string, newValue: any) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local StatApplicators: {[string]: (player: Player, value: any, stats: PlayerStats)->()} = {
   Speed = function(player: Player, value: number, stats: PlayerStats)
      if player.Character and player.Character:FindFirstChild("Humanoid") then
         player.Character.Humanoid.WalkSpeed = value
      end
   end
}

local function newPlayerStats(player: Player)
   local userStats = table.clone(defaultStats)
   playerStats[player.UserId] = userStats
   for statName, value in pairs(userStats) do
      local applicator = StatApplicators[statName]
      if applicator then
         applicator(player, value, userStats)
      end
   end
   return userStats
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PlayerStatsLibrary.setStat(player: Player, statName: string, value: any, doNotReplicate: boolean?)
   local userStats = playerStats[player.UserId]
   if not userStats then
      if not player.Parent then
         return
      end
      userStats = newPlayerStats(player)
   end
   userStats[statName] = value

   local applicator = StatApplicators[statName]
   if applicator then
      applicator(player, value, userStats)
   end
   
   if isServer and not doNotReplicate then
      replicatePlayerStat:FireClient(player, statName, value)
   end

   PlayerStatsLibrary.StatChangedTasks:Execute("serial", player, statName, value)
end

function PlayerStatsLibrary.getStat(player: Player, statName: string): number?
   local userStats = playerStats[player.UserId]
   if not userStats then
      return nil
   end
   return userStats[statName]
end

-------------------------------------------------------------------------------
-- CORE
-------------------------------------------------------------------------------

function PlayerStatsLibrary.init()
   if initiated then
      return
   end
   initiated = true

   if isServer then
      -- Server context
      PlayersUtil.PlayerRemoving:Add(function(player)
         playerStats[player.UserId] = nil
      end)
      PlayersUtil.PlayerAdded:Add(function(player)
         newPlayerStats(player)
      end)
      local gameStateData = GameStateLibrary.getGameStateData()
      gameStateData.GameplayPhase:Subscribe(function(newPhase)
         if newPhase == GameplayPhaseEnum.LobbyVoting then
            for _, player in pairs(Players:GetPlayers()) do
               newPlayerStats(player)
            end
            if isServer then
               for _, player in pairs(Players:GetPlayers()) do
                  local character = player.Character
                  if not character then
                     continue
                  end
                  local humanoid = character:FindFirstChild("Humanoid")
                  if not humanoid then
                     continue
                  end
                  humanoid.Health = humanoid.MaxHealth
               end
            end
         end
      end)
   else
      -- Client context
      replicatePlayerStat.OnClientEvent:Connect(function(statName: string, value: any)
         PlayerStatsLibrary.setStat(Players.LocalPlayer, statName, value)
      end)
   end
end

return PlayerStatsLibrary