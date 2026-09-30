--[[
]]

local LeaderstatService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // Elims mirrors the saved lifetime total; Round is the per-round score set by gamemode logic
export type Stats = "Elims" | "Round"

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local playerLeaderstatFolders: {[Player]: Folder} = {}
local playerLeaderstatValues: {[Player]: {[Stats]: IntValue}} = {}
-- // Stats shown only while enabled (e.g. by a gamemode), including for players who join meanwhile
local enabledOptionalStats: {[Stats]: true} = {}

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

function LeaderstatService.enableStat(stat: Stats)
   enabledOptionalStats[stat] = true
   for player, values in pairs(playerLeaderstatValues) do
      if not values[stat] then
         values[stat] = createLeaderstat(playerLeaderstatFolders[player], stat, 0)
      end
   end
end

function LeaderstatService.disableStat(stat: Stats)
   enabledOptionalStats[stat] = nil
   for _, values in pairs(playerLeaderstatValues) do
      if values[stat] then
         values[stat]:Destroy()
         values[stat] = nil
      end
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LeaderstatService.init()
   PlayersUtil.PlayerAdded:Add(function(player: Player)
      local leaderstats = Instance.new("Folder")
      leaderstats.Name = "leaderstats"
      leaderstats.Parent = player

      local profileData = PlayerDataService.get(player)
      playerLeaderstatFolders[player] = leaderstats
      playerLeaderstatValues[player] = {
         Elims = createLeaderstat(leaderstats, "Elims", if profileData then profileData.Elims else 0),
         Round = createLeaderstat(leaderstats, "Round", 0),
      }
      for stat in pairs(enabledOptionalStats) do
         playerLeaderstatValues[player][stat] = createLeaderstat(leaderstats, stat, 0)
      end
   end)
   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      playerLeaderstatFolders[player] = nil
      playerLeaderstatValues[player] = nil
   end)
   PlayerDataService.ProfileAddedTasks:Add(function(player: Player, data)
      LeaderstatService.setValue(player, "Elims", data.Elims)
   end)
   PlayerDataService.UpdatedTasks:Add(function(player: Player, index, value, path)
      if #path == 0 and index == "Elims" then
         LeaderstatService.setValue(player, "Elims", value)
      end
   end)

   GameStateLibrary.RoundStartingTasks:Add(function()
      for _, player in pairs(Players:GetPlayers()) do
         LeaderstatService.setValue(player, "Round", 0)
      end
   end)
end

function LeaderstatService.start()

end

function LeaderstatService.test()

end

return LeaderstatService