local ClassicRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CombatService = require(ServerStorage.Server.Core.CombatService)

local PerMatchDestroyerFunctions: {()->()} = {}

local Kills: {[Player]: number} = {}

local function clear()
   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)
   table.clear(Kills)
end

function ClassicRoundLogic.setup()
   GameTeamService.setFreeForAll()

   table.insert(PerMatchDestroyerFunctions, CombatService.PlayerKilledPlayerTasks:Add(function(attacker: Player, victim: Player, attackerToolId: string)
      Kills[attacker] = (Kills[attacker] or 0) + 1
   end))
end

function ClassicRoundLogic.teardown()
   local winner
   local highestKills = 0
   for player, killCount in pairs(Kills) do
      if killCount > highestKills then
         highestKills = killCount
         winner = player
      end
   end
   clear()
   CurrentGameState.RoundFinishedTasks:Execute("parallel", winner, if winner then `{winner.Name} wins with {highestKills} kills!` else "No winner")
end

return ClassicRoundLogic