--[[
  Handles player team assignment

  TODO:
  - When a player joins, if currently in a team-based match, assign to the team with the least players

TODO: figure out how teams should work
do i want to deal with default roblox bs or do i want to override it completely
dealing with default roblox system might be good for an MVP since it visualizes in the UI. it should just be very easy to modify for the future.

  Author:
  @Soulsplosion
]]

local GameTeamService = {}

local Players = game:GetService("Players")
local TeamService = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SharedConstants = ReplicatedStorage.Shared.Constants

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type PlayerDiedEventTask = (player: Player) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local OutOfGameTeam = Instance.new("Team")
OutOfGameTeam.Name = "OutOfGame"
OutOfGameTeam.TeamColor = BrickColor.new("Really black")
OutOfGameTeam.Parent = TeamService
OutOfGameTeam.AutoAssignable = false

local Teams: {
   [string]: Team,
} = {}

local TeamOptions: {
   [string]: {
      Name: string,
      Color: BrickColor,
   },
} = {
   FreeForAll = {
      Name = "Free for All!",
      Color = BrickColor.new("White"),
   },
   TeamRed = {
      Name = "Team Red!",
      Color = BrickColor.new("ReallyRed"),
   },
   TeamBlue = {
      Name = "Team Blue!",
      Color = BrickColor.new("Bright blue"),
   },
   TeamGreen = {
      Name = "Team Green!",
      Color = BrickColor.new("Bright green"),
   },
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function safeGetTeam(name: string): Team
   if not Teams[name] then
      if not TeamOptions[name] then
         error("No team color defined for team: "..name)
      end
      local team = Instance.new("Team")
      team.Name = TeamOptions[name].Name
      team.TeamColor = TeamOptions[name].Color
      team.Parent = TeamService
      team.AutoAssignable = false
      Teams[name] = team
   end
   return Teams[name]
end

------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Set particpiating members to free-for-all team
function GameTeamService.setFreeForAll()
   local team = safeGetTeam("FreeForAll")
   team.AutoAssignable = true
   for _, player in pairs(Players:GetPlayers()) do
      -- TODO: check if player is in round and not currently eliminated
      -- or something. yknow. don't adjust non-participating players
      player.Team = team
   end
end

-- // Set participating members to opposition teams
function GameTeamService.setOpposition()
   -- TODO
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GameTeamService.init()
   GameTeamService.setFreeForAll()
	PlayersUtil.onPlayerAdded(function(player: Player)
      
	end)
end

function GameTeamService.start()

end

function GameTeamService.test()

end

return GameTeamService