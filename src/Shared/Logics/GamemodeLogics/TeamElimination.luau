-- // Team gamemode: two opposing teams fight until one is eliminated entirely

local TeamEliminationRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local isServer = RunService:IsServer()
local ArenaService, GameTeamService, RoundCyclingService, WeaponService, StormCloseService, SpawnService
if isServer then
   ArenaService = require(ServerStorage.Server.Core.ArenaService)
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
   RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
   WeaponService = require(ServerStorage.Server.Core.WeaponService)
   StormCloseService = require(ServerStorage.Server.Core.StormCloseService)
   SpawnService = require(ServerStorage.Server.Core.SpawnService)
end

local PerMatchDestroyerFunctions: {()->()} = {}

local activeTeams: {Team} = {}
local matchArmed = false -- Set once both teams hold living players, so ongoing assignment can't be mistaken for a win
local matchFinished = false

local function clear()
   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)
end

local function assignUnassignedPlayers(livingPlayers: {Player})
   for _, player in ipairs(livingPlayers) do
      if not GameTeamService.isOnOppositionTeam(player) then
         GameTeamService.assignToSmallestOppositionTeam(player)
      end
   end
end

local function evaluateWinCondition(livingPlayers: {Player})
   if matchFinished or #activeTeams == 0 then
      return
   end

   local playersByTeam: {[Team]: {Player}} = {}
   local representedTeamCount = 0
   for _, player in ipairs(livingPlayers) do
      local team = player.Team
      if not team or table.find(activeTeams, team) == nil then
         -- Assignment is still in flight, so the roster isn't trustworthy yet
         return
      end
      local teamPlayers = playersByTeam[team]
      if not teamPlayers then
         teamPlayers = {}
         playersByTeam[team] = teamPlayers
         representedTeamCount += 1
      end
      table.insert(teamPlayers, player)
   end

   if representedTeamCount >= 2 then
      matchArmed = true
      return
   end

   if not matchArmed then
      return
   end

   local winningTeam: Team?, winningPlayers: {Player}?
   for team, teamPlayers in pairs(playersByTeam) do
      winningTeam = team
      winningPlayers = teamPlayers
   end

   matchFinished = true
   TeamEliminationRoundLogic.teardown(winningPlayers and winningPlayers[1], winningTeam)
end

function TeamEliminationRoundLogic.setup()
   if isServer then
      clear()
      matchArmed = false
      matchFinished = false

      activeTeams = GameTeamService.establishOppositionTeams()
      StormCloseService.begin(ArenaService.getCurrentArenaPosition() or Vector3.new(0, 0, 0))

      table.insert(PerMatchDestroyerFunctions, GameStateLibrary.PlayerRemovedFromArenaTasks:Add(function(player: Player)
         local livingPlayers = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get()
         if #livingPlayers <= 1 and not (RunService:IsStudio() and #game.Players:GetPlayers() == 1) then
            local winner = livingPlayers[1]
            TeamEliminationRoundLogic.teardown(winner, winner and winner.Team)
         end
      end))

      local livingPlayers = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get()
      assignUnassignedPlayers(livingPlayers)
      evaluateWinCondition(livingPlayers)
   end
end

function TeamEliminationRoundLogic.teardown(winner: Player?, winningTeam: Team?)
   if isServer then
      if not winningTeam then
         warn(`TeamElimination: no winning team found`)
      end
      matchFinished = true
      clear()
      table.clear(activeTeams)
      GameTeamService.dismantleRoundTeams()
      GameStateLibrary.RoundFinishedTasks:Execute("parallel", winner, winningTeam and (winningTeam.Name .. " won!") or "No winner")
   end
end

return TeamEliminationRoundLogic