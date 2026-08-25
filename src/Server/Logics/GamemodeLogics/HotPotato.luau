local HotPotatoRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CombatService = require(ServerStorage.Server.Core.CombatService)
local PickupService = require(ServerStorage.Server.Core.PickupService)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)

local PerMatchDestroyerFunctions: {()->()} = {}

local Kills: {[Player]: number} = {}

local function clear()
end

function HotPotatoRoundLogic.setup()
   GameTeamService.setFreeForAll()

  local currentGameData = CurrentGameState.getGameStateData()
  local players = currentGameData.LivingPlayersInArena:Get()
  local randomPlayer = players[math.random(1, #players)]
  PickupService.grantPickupClassId(randomPlayer, "HotPotato")
end

function HotPotatoRoundLogic.teardown()
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

return HotPotatoRoundLogic