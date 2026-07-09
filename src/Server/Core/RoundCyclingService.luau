--[[
  - Manages round starting/stopping, intermissions, voting for the next round, etc
  
  Author:
  @Soulsplosion
]]

local RoundCyclingService = {}

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SharedConstants = ReplicatedStorage.Shared.Constants

local Gamemodes = require(SharedConstants.Gamemodes)
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SpawnService = require(ServerStorage.Server.Core.SpawnService)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local GamemodeLogics = ServerStorage.Server.Logics.GamemodeLogics
local GamemodeLogicModules = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local INTERMISSION_DURATION = 10
local VOTE_DURATION = 8

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local roundDurationConnection: RBXScriptConnection? = nil
local currentRoundEndsAt: number? = nil

local IntermissionStartedEvent = SimpleRemotes.getEvent("IntermissionStarted")
local VoteUpdatedEvent = SimpleRemotes.getEvent("VoteUpdated")

local votes: {[Player]: number} = {}
local totalVotes = {0, 0}
local awaitingVotes: {Player} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(roundTypeId: string)
	if not GamemodeLogicModules[roundTypeId] then
		local module = require(GamemodeLogics:WaitForChild(roundTypeId))
		GamemodeLogicModules[roundTypeId] = module
	end
	return GamemodeLogicModules[roundTypeId]
end

local function updateRoundDuration()
   if not currentRoundEndsAt then
      return
   end
   local secondsLeft = math.max(0, currentRoundEndsAt - workspace:GetServerTimeNow())
   if secondsLeft <= 0 and roundDurationConnection then
      roundDurationConnection:Disconnect()
      roundDurationConnection = nil
      currentRoundEndsAt = nil
      if CurrentGameState.Gamemode then
         local roundLogic = getLogic(CurrentGameState.Gamemode)
         CurrentGameState.Gamemode = nil
         if roundLogic and roundLogic.teardown then
            roundLogic.teardown()
         end
      end
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function RoundCyclingService.isInRound(): boolean
   return CurrentGameState.IsInRound
end

function RoundCyclingService.getCurrentRoundTypeId(): string?
   return CurrentGameState.Gamemode
end

-- // Returns true if current round permits late joining for the given player
function RoundCyclingService.canSpawnIntoRound(player: Player): boolean
   if not CurrentGameState.IsInRound or not CurrentGameState.Gamemode then
      return false
   end
   return CurrentGameState.CanRespawn
end

function RoundCyclingService.getNextGamemodeChoices(): {string}
   local availableGamemodes = {}
   for gamemodeId, _ in pairs(Gamemodes) do
      table.insert(availableGamemodes, gamemodeId)
   end
   
   local availableForChoice = {}
   repeat
      local choice = availableGamemodes[math.random(1, #availableGamemodes)]
      if not table.find(availableForChoice, choice) then
         table.insert(availableForChoice, choice)
      end
   until #availableForChoice >= 2
   return availableForChoice
end

function RoundCyclingService.setNextRound(roundTypeId: string, mapName: string)
   CurrentGameState.RoundStartingTasks:Execute("parallel")

   local roundType = Gamemodes[roundTypeId]
   local roundDuration = roundType.TimeLasts
   local notificationServerTime = workspace:GetServerTimeNow()

   CurrentGameState.Gamemode = roundTypeId
   CurrentGameState.CurrentMapName = mapName
   CurrentGameState.IsInRound = true
   CurrentGameState.CanRespawn = roundType.CanRespawn
   ArenaService.setArena(mapName)

   local roundLogic = getLogic(roundTypeId)
   if roundLogic and roundLogic.setup then
      roundLogic.setup()
   end

   SimpleRemotes.getEvent("NewRoundStarted"):FireAllClients(roundTypeId, roundDuration, notificationServerTime)
	currentRoundEndsAt = notificationServerTime + roundDuration
   if roundDurationConnection  then
      roundDurationConnection:Disconnect()
      roundDurationConnection = nil
   end
   roundDurationConnection = RunService.Heartbeat:Connect(updateRoundDuration)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RoundCyclingService.init()
   SimpleRemotes.getEvent("NewRoundStarted")
   SimpleRemotes.getEvent("IntermissionStarted")
   SimpleRemotes.getEvent("VoteUpdated")

   SpawnService.PlayerDiedTasks:Add(function(Player: Player)
      local livingPlayersInArena = CurrentGameState.LivingPlayersInArena:Get()
      local i = table.find(livingPlayersInArena, Player)
      if i then 
         table.remove(livingPlayersInArena, i)
         CurrentGameState.LivingPlayersInArena:Set(livingPlayersInArena)
      end
   end)

   SpawnService.PlayerSpawnedTasks:Add(function(player: Player, inArena: boolean)
      if not inArena then
         return
      end
      local livingPlayersInArena = CurrentGameState.LivingPlayersInArena:Get()
      if not table.find(livingPlayersInArena, player) then
         table.insert(livingPlayersInArena, player)
         CurrentGameState.LivingPlayersInArena:Set(livingPlayersInArena)
      end
   end)

   PlayersUtil.onPlayerRemoving(function(player: Player)
      local livingPlayersInArena = CurrentGameState.LivingPlayersInArena:Get()
      local i = table.find(livingPlayersInArena, player)
      if i then 
         table.remove(livingPlayersInArena, i)
         CurrentGameState.LivingPlayersInArena:Set(livingPlayersInArena)
      end
      i = table.find(awaitingVotes, player)
      if i then
         table.remove(awaitingVotes, i)
      end
   end)

   VoteUpdatedEvent.OnServerEvent:Connect(function(player: Player, index: number)
      if votes[player] then
         return
      end
      votes[player] = index
      totalVotes[index] += 1
      local i = table.find(awaitingVotes, player)
      if i then
         table.remove(awaitingVotes, i)
      end
      VoteUpdatedEvent:FireAllClients(totalVotes[1], totalVotes[2], nil)
   end)

   print(CurrentGameState)
end

function RoundCyclingService.start()
   task.spawn(function()
      task.wait(2)
      RoundCyclingService.setNextRound("ThrowBoomerang", "GenericA")
	end)

    CurrentGameState.RoundFinishedTasks:Add(function(winner: Player?, winMessage: string)
      print("A ROUND FINISHED - BEGINNING INTERMISSION -")

      local livingPlayersInArena = CurrentGameState.LivingPlayersInArena:Get()
      table.clear(livingPlayersInArena)
      CurrentGameState.LivingPlayersInArena:Set(livingPlayersInArena)

      if roundDurationConnection  then
         roundDurationConnection:Disconnect()
         roundDurationConnection = nil
         currentRoundEndsAt = nil
      end

      -- // Start voting process
      local possibleGamemodes = RoundCyclingService.getNextGamemodeChoices()
      totalVotes[1] = 0
      totalVotes[2] = 0
      table.clear(votes)
      table.clear(awaitingVotes)
      for _, p in pairs(game.Players:GetPlayers()) do
         table.insert(awaitingVotes, p)
      end
      IntermissionStartedEvent:FireAllClients(winner, winMessage, possibleGamemodes, INTERMISSION_DURATION, workspace:GetServerTimeNow())

      CurrentGameState.IsInRound = false
      CurrentGameState.CurrentMapName = nil
      CurrentGameState.CanRespawn = nil

      -- Wait for votes
      local elapsed = 0
      repeat
         local deltaTime = RunService.Heartbeat:Wait()
         elapsed += deltaTime
      until elapsed >= VOTE_DURATION or #awaitingVotes == 0
      print(elapsed, VOTE_DURATION, awaitingVotes)
      
      -- Tally votes
      -- Restart tally, just for safety
      totalVotes[1] = 0
      totalVotes[2] = 0
      for player, vote in pairs(votes) do
         if vote == 1 then
            totalVotes[1] += 1
         elseif vote == 2 then
            totalVotes[2] += 1
         end
      end
      
      local chosenGamemode
      if totalVotes[1] > totalVotes[2] then
         chosenGamemode = possibleGamemodes[1]
      elseif totalVotes[2] > totalVotes[1] then
         chosenGamemode = possibleGamemodes[2]
      else
         chosenGamemode = possibleGamemodes[math.random(#possibleGamemodes)]
      end
      local untilNewRound = INTERMISSION_DURATION - VOTE_DURATION

      VoteUpdatedEvent:FireAllClients(totalVotes[1], totalVotes[2], chosenGamemode, untilNewRound, workspace:GetServerTimeNow())
      
      elapsed = 0
      repeat
         local deltaTime = RunService.Heartbeat:Wait()
         elapsed += deltaTime
      until elapsed >= untilNewRound
      -- TODO: do not start new round until minimum players; cancel voting if not at minimum players; etc

      local availableMaps = ArenaService.getAvailableMaps(chosenGamemode)
      local map = availableMaps[math.random(#availableMaps)]

      RoundCyclingService.setNextRound(chosenGamemode, map)
   end)
end

-- function RoundCyclingService.test() end

return RoundCyclingService