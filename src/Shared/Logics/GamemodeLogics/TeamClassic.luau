local TeamClassic = {} 

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)

local isServer = RunService:IsServer()
local GameTeamService, CombatService
if isServer then
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
end

local PerMatchDestroyerFunctions: {()->()} = {}
local TeamElims: {[Team]: number} = {}

local function clear()
   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)
   table.clear(TeamElims)
end

function TeamClassic.setup()
   if not isServer then
      return
   end

   clear()
   local activeTeams = GameTeamService.establishOppositionTeams()
   for _, team in ipairs(activeTeams) do
      TeamElims[team] = 0
   end

   table.insert(PerMatchDestroyerFunctions, CombatLibrary.PlayerElimedPlayerTasks:Add(function(attacker: Player, _victim: Player, _attackerToolId: string)
      local team = attacker.Team
      if team and TeamElims[team] ~= nil then
         TeamElims[team] += 1
      end
   end))

   table.insert(PerMatchDestroyerFunctions, PlayersUtil.GameEnteredTooFewPlayers:Add(function()
      TeamClassic.teardown()
   end))
end

function TeamClassic.teardown()
   if not isServer then
      return
   end

   local winningTeam: Team?
   local highestElims = 0
   local isTie = false
   for team, elimCount in pairs(TeamElims) do
      if elimCount > highestElims then
         winningTeam = team
         highestElims = elimCount
         isTie = false
      elseif elimCount == highestElims and elimCount > 0 then
         isTie = true
      end
   end

   if isTie then
      winningTeam = nil
   end

   clear()
   GameTeamService.dismantleRoundTeams()
   CurrentGameState.RoundFinishedTasks:Execute(
      "parallel",
      nil,
      if winningTeam then `{winningTeam.Name} wins with {highestElims} elims!` else "No winner"
   )
end

return TeamClassic