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
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local OPPOSITION_TEAM_COUNT = 2

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

-- Round teams currently opposing each other; empty outside of team-based gamemodes
local ActiveOppositionTeams: {Team} = {}

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

local function shuffled<T>(source: {T}): {T}
   local result = table.clone(source)
   for index = #result, 2, -1 do
      local swapIndex = math.random(1, index)
      result[index], result[swapIndex] = result[swapIndex], result[index]
   end
   return result
end

local function getOppositionTeamOptionNames(): {string}
   local names = {}
   for name, teamOptionData in pairs(TeamOptions) do
      if not teamOptionData.FriendlyFire then
         table.insert(names, name)
      end
   end
   table.sort(names)
   return names
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
   table.clear(ActiveOppositionTeams)
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
   table.clear(ActiveOppositionTeams)
   local team = safeGetTeam("FreeForAll")
   team.AutoAssignable = false
   local livingPlayersInArena = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get()
   for _, player in ipairs(livingPlayersInArena) do
      player.Team = team
   end
end

-- // Set participating members to opposition teams
function GameTeamService.establishOppositionTeams(teamCount: number?): {Team}
   local desiredTeamCount = teamCount or OPPOSITION_TEAM_COUNT
   local optionNames = getOppositionTeamOptionNames()
   if #optionNames < desiredTeamCount then
      error(`GameTeamService: only {#optionNames} non-friendly-fire team options exist; {desiredTeamCount} required`)
   end

   roundTeamsDismantled = false
   table.clear(ActiveOppositionTeams)

   local chosenNames = shuffled(optionNames)
   for index = 1, desiredTeamCount do
      local team = safeGetTeam(chosenNames[index])
      team.AutoAssignable = false
      table.insert(ActiveOppositionTeams, team)
   end

   -- Deal shuffled players out round-robin so populations stay within one of each other
   local livingPlayersInArena = shuffled(GameStateLibrary.getGameStateData().LivingPlayersInArena:Get())
   for index, player in ipairs(livingPlayersInArena) do
      player.Team = ActiveOppositionTeams[(index - 1) % desiredTeamCount + 1]
   end

   return table.clone(ActiveOppositionTeams)
end

function GameTeamService.getActiveOppositionTeams(): {Team}
   return table.clone(ActiveOppositionTeams)
end

function GameTeamService.isOnOppositionTeam(player: Player): boolean
   return player.Team ~= nil and table.find(ActiveOppositionTeams, player.Team) ~= nil
end

-- // Place a player on whichever opposition team currently has the fewest living members
function GameTeamService.assignToSmallestOppositionTeam(player: Player): Team?
   if #ActiveOppositionTeams == 0 then
      return nil
   end

   local counts: {[Team]: number} = {}
   for _, team in ipairs(ActiveOppositionTeams) do
      counts[team] = 0
   end
   for _, livingPlayer in ipairs(GameStateLibrary.getGameStateData().LivingPlayersInArena:Get()) do
      local team = livingPlayer.Team
      if livingPlayer ~= player and team and counts[team] then
         counts[team] += 1
      end
   end

   local smallestTeams: {Team} = {}
   local smallestCount = math.huge
   for _, team in ipairs(ActiveOppositionTeams) do
      local count = counts[team]
      if count < smallestCount then
         smallestCount = count
         smallestTeams = {team}
      elseif count == smallestCount then
         table.insert(smallestTeams, team)
      end
   end

   local chosenTeam = smallestTeams[math.random(1, #smallestTeams)]
   player.Team = chosenTeam
   return chosenTeam
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GameTeamService.init()
   GameTeamService.setAllOutOfGame()
	PlayersUtil.PlayerAdded:Add(function(player: Player)
      local currentGameState = GameStateLibrary.getGameStateData()
   local currentRoundData = currentGameState.CurrentRoundData:Get()
   if currentRoundData == nil or not currentRoundData.CanRespawn then
         GameTeamService.setOutOfGame(player)
      elseif #ActiveOppositionTeams > 0 then
         GameTeamService.assignToSmallestOppositionTeam(player)
      else
         player.Team = safeGetTeam("FreeForAll")
      end
	end)

   -- // Dismantle round teams in response to new intermission stages
   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.GameplayPhase:Subscribe(function(gameplayPhase)
      if not roundTeamsDismantled then
         if gameplayPhase == GameplayPhases.LobbyVoting or gameplayPhase == GameplayPhases.LobbyEnded then
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