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
local IntermissionStagesEnum = require(ReplicatedStorage.Shared.Constants.Enums.IntermissionStages)

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

local roundTeamsDismantled = false

-- Teams that only exist for a round and are dismantled at the end of  around
local RoundTeams: {
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
   if not RoundTeams[name] then
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
      RoundTeams[name] = team
   end
   return RoundTeams[name]
end

------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

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

-- // Dismantle all round-specific teams and set all players to out-of-game
function GameTeamService.dismantleRoundTeams()
   roundTeamsDismantled = true
   for teamName, team in pairs(RoundTeams) do
      if team == OutOfGameTeam then
         continue
      end
      if team and team.Parent then
         for _, player in ipairs(Players:GetPlayers()) do
            if player.Team == team then
               player.Team = OutOfGameTeam
            end
         end
         team:Destroy()
      end
      RoundTeams[teamName] = nil
   end
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
      if currentGameState.CurrentRoundData:Get() == nil then
         GameTeamService.setOutOfGame(player)
      else
         -- TODO: when team vs team gamemodes are added, assign player to a team
         player.Team = safeGetTeam("FreeForAll")
      end
	end)

   -- // Dismantle round teams in response to new intermission stages
   local gameStateData = GameStateLibrary.getGameStateData()
   local currentIntermissionData = gameStateData.IntermissionData:Get()
   local lastIntermissionStage = if currentIntermissionData then currentIntermissionData.IntermissionStage else nil
   gameStateData.IntermissionData:Subscribe(function(intermissionData)
      local newIntermissionStage = if intermissionData then intermissionData.IntermissionStage else nil
      if newIntermissionStage == lastIntermissionStage then
         return
      end
      lastIntermissionStage = newIntermissionStage
      if not roundTeamsDismantled then
         if newIntermissionStage == IntermissionStagesEnum.LobbyVoting or newIntermissionStage == IntermissionStagesEnum.LobbyEnded then
            GameTeamService.dismantleRoundTeams()
         end
      end
   end)
end

function GameTeamService.start()

end

function GameTeamService.test()

end

return GameTeamService