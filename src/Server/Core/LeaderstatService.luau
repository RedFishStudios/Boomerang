--[[
]]

local LeaderstatService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GameplayPhaseEnum = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Stats = "Elims"

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local playerLeaderstatValues: {[Player]: {[Stats]: IntValue}} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function createLeaderstat(parent: Folder, name: Stats, value: number)
   local statValue = Instance.new("IntValue")
   statValue.Name = name
   statValue.Value = value
   statValue.Parent = parent
   return statValue
end

------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function LeaderstatService.addValue(player: Player, stat: Stats, amount: number)
   if not playerLeaderstatValues[player] then
      return
   end
   if not playerLeaderstatValues[player][stat] then
      return
   end
   playerLeaderstatValues[player][stat].Value += amount
end

function LeaderstatService.setValue(player: Player, stat: Stats, value: number)
   if not playerLeaderstatValues[player] then
      return
   end
   if not playerLeaderstatValues[player][stat] then
      return
   end
   playerLeaderstatValues[player][stat].Value = value
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LeaderstatService.init()
   PlayersUtil.PlayerAdded:Add(function(player: Player)
      local leaderstats = Instance.new("Folder")
      leaderstats.Name = "leaderstats"
      leaderstats.Parent = player

      playerLeaderstatValues[player] = {
         Elims = createLeaderstat(leaderstats, "Elims", 0)
      }
   end)
   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      playerLeaderstatValues[player] = nil
   end)
   CombatLibrary.PlayerKilledPlayerTasks:Add(function(killer: Player, victim: Player, weaponId: string)
      LeaderstatService.addValue(killer, "Elims", 1)
   end)
   
   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.GameplayPhase:Subscribe(function(gameplayPhase: string)
      if gameplayPhase == GameplayPhaseEnum.LobbyVoting then
         for _, player in pairs(Players:GetPlayers()) do
            LeaderstatService.setValue(player, "Elims", 0)
         end
      end
   end)
end

function LeaderstatService.start()

end

function LeaderstatService.test()

end

return LeaderstatService