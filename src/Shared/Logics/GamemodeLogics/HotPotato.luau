local HotPotatoRoundLogic = {} 

local RunService = game:GetService("RunService")

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)

local PerMatchDestroyerFunctions: {()->()} = {}

local Kills: {[Player]: number} = {}

local isServer = RunService:IsServer()
local PickupService, GameTeamService, RoundCyclingService
if isServer then
   PickupService = require(ServerStorage.Server.Core.PickupService)
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
   RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
end

local function clear()
end

function HotPotatoRoundLogic.setup()
  if isServer then
   GameTeamService.setFreeForAll()
   local currentGameData = CurrentGameState.getGameStateData()
   local players = currentGameData.LivingPlayersInArena:Get()
   local randomPlayer = players[math.random(1, #players)]
   PickupService.grantPickupClassId(randomPlayer, "HotPotato")
  end
end

function HotPotatoRoundLogic.teardown()
   if isServer then
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
end

return HotPotatoRoundLogic