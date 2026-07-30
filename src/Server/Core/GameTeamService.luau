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
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

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
      FriendlyFire: boolean?
   },
} = {
   FreeForAll = {
      Name = "Free for All!",
      Color = BrickColor.new("White"),
      FriendlyFire = true
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
      local teamOptionData =  TeamOptions[name] 
      if not teamOptionData then
         error("No team color defined for team: "..name)
      end
      local team = Instance.new("Team")
      team.Name = teamOptionData.Name
      team.TeamColor = teamOptionData.Color
      team.Parent = TeamService
      team.AutoAssignable = false
      if teamOptionData.FriendlyFire ~= nil then
         team:SetAttribute("FriendlyFire", teamOptionData.FriendlyFire)
      end
      Teams[name] = team
   end
   return Teams[name]
end

------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GameTeamService.hasFriendlyFire(Team: Team)
   return Team:GetAttribute("FriendlyFire") == true
end

function GameTeamService.getOutOfGameTeam(): Team
   return OutOfGameTeam
end

function GameTeamService.setOutOfGame(player: Player)
   player.Team = OutOfGameTeam
end

function GameTeamService.setAllOutOfGame()
   for _, player in ipairs(Players:GetPlayers()) do
      player.Team = OutOfGameTeam
   end
end

function GameTeamService.destroyRoundTeams()
   for teamName, team in pairs(Teams) do
      if team and team.Parent then
         for _, player in ipairs(Players:GetPlayers()) do
            if player.Team == team then
               player.Team = OutOfGameTeam
            end
         end
         team:Destroy()
      end
      Teams[teamName] = nil
   end
end

function GameTeamService.beginIntermission()
   GameTeamService.setAllOutOfGame()
   GameTeamService.destroyRoundTeams()
end

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
   GameTeamService.setAllOutOfGame()
	PlayersUtil.PlayerAdded:Add(function(player: Player)
      local currentGameState = GameStateLibrary.getGameStateData()
      if currentGameState.CanRespawn:Get() then
         -- TODO: when team vs team gamemodes are added, assign player to a team
         player.Team = safeGetTeam("FreeForAll")
      else
         GameTeamService.setOutOfGame(player)
      end
	end)
end

function GameTeamService.start()

end

function GameTeamService.test()

end

return GameTeamService