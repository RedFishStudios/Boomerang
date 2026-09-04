local ClassicRoundLogic = {} 

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)

local isServer = RunService:IsServer()
local GameTeamService, RoundCyclingService
if isServer then
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
   RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
end

local PerMatchDestroyerFunctions: {()->()} = {}

local Elims: {[Player]: number} = {}

local function clear()
   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)
   table.clear(Elims)
end

function ClassicRoundLogic.setup()
   if isServer then
      GameTeamService.setFreeForAll()

      table.insert(PerMatchDestroyerFunctions, CombatLibrary.PlayerKilledPlayerTasks:Add(function(attacker: Player, victim: Player, attackerToolId: string)
         Elims[attacker] = (Elims[attacker] or 0) + 1
      end))

      -- // Highest-elims winner naturally stays nil if no one has scored an elim yet
      table.insert(PerMatchDestroyerFunctions, PlayersUtil.GameEnteredTooFewPlayers:Add(function()
         ClassicRoundLogic.teardown()
      end))
   end
end

function ClassicRoundLogic.teardown()
   if isServer then
      local winner
      local highestElims = 0
      for player, elimCount in pairs(Elims) do
         if elimCount > highestElims then
            highestElims = elimCount
            winner = player
         end
      end
      clear()
      CurrentGameState.RoundFinishedTasks:Execute("parallel", winner, if winner then `{winner.Name} wins with {highestElims} elims!` else "No winner")
   end
end

return ClassicRoundLogic