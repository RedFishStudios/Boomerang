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
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SpawnService = require(ServerStorage.Server.Core.SpawnService)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local LobbyService = require(ServerStorage.Server.Core.LobbyService)
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local GameplayPhases = require(SharedConstants.Enums.GameplayPhases)

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
local currentRoundId = 0

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
   local gameStateData = GameStateLibrary.getGameStateData()
   if not currentRoundEndsAt then
      return
   end
   local secondsLeft = math.max(0, currentRoundEndsAt - workspace:GetServerTimeNow())
   if secondsLeft <= 0 and roundDurationConnection then
      roundDurationConnection:Disconnect()
      roundDurationConnection = nil
      currentRoundEndsAt = nil
      local currentRoundData = gameStateData.CurrentRoundData:Get()
      local currentGamemode = if currentRoundData then currentRoundData.Gamemode else nil
      if currentGamemode then
         local roundLogic = getLogic(currentGamemode)
         local snapshot = GameStateLibrary.getSnapshot()
         snapshot.CurrentRoundData = nil
         snapshot.CurrentTimerEndsAt = nil
         GameStateLibrary.applySnapshot(snapshot)
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
   return GameStateLibrary.getGameStateData().CurrentRoundData:Get() ~= nil
end

function RoundCyclingService.getCurrentRoundTypeId(): string?
   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   return if currentRoundData then currentRoundData.Gamemode else nil
end

-- // Returns true if current round permits late joining for the given player
function RoundCyclingService.canSpawnIntoRound(player: Player): boolean
   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   if currentRoundData == nil then
      return false
   end
   return currentRoundData.CanRespawn
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
   GameStateLibrary.RoundStartingTasks:Execute("parallel")
   currentRoundId += 1

   local roundType = Gamemodes[roundTypeId]
   local roundDuration = roundType.TimeLasts
   local notificationServerTime = workspace:GetServerTimeNow()
   local roundEndsAt = notificationServerTime + roundDuration

   local snapshot = GameStateLibrary.getSnapshot()
   snapshot.CurrentRoundData = {
      CurrentRoundId = currentRoundId,
      Gamemode = roundTypeId,
      CurrentMapName = mapName,
      CanRespawn = roundType.CanRespawn,
   }
   snapshot.GameplayPhase = GameplayPhases.RoundActive
   snapshot.CurrentTimerEndsAt = roundEndsAt
   snapshot.IntermissionData = nil
   GameStateLibrary.applySnapshot(snapshot)

   ArenaService.setArena(mapName)

   local roundLogic = getLogic(roundTypeId)
   if roundLogic and roundLogic.setup then
      roundLogic.setup()
   end

	currentRoundEndsAt = roundEndsAt
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
   SimpleRemotes.getEvent("VoteUpdated")
   local gameStateData = GameStateLibrary.getGameStateData()

   PlayersUtil.CharacterDied:Add(function(player: Player, _character: Model, _humanoid: Humanoid)
      local currentLivingPlayers = gameStateData.LivingPlayersInArena:Get()
      local livingPlayersInArena = table.clone(currentLivingPlayers)
      local i = table.find(livingPlayersInArena, player)
      if i then 
         table.remove(livingPlayersInArena, i)
         GameStateLibrary.applyValues({
            LivingPlayersInArena = livingPlayersInArena,
         })
      end
   end)

   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      local currentLivingPlayers = gameStateData.LivingPlayersInArena:Get()
      local livingPlayersInArena = table.clone(currentLivingPlayers)
      local i = table.find(livingPlayersInArena, player)
      if i then 
         table.remove(livingPlayersInArena, i)
         GameStateLibrary.applyValues({
            LivingPlayersInArena = livingPlayersInArena,
         })
      end
      i = table.find(awaitingVotes, player)
      if i then
         table.remove(awaitingVotes, i)
      end
   end)

   VoteUpdatedEvent.OnServerEvent:Connect(function(player: Player, index: number)
      -- same vote?
      if votes[player] == index then
         return
      end

      -- Remove previous vote
      if votes[player] then
         totalVotes[votes[player]] -= 1
      end

      -- Record new vote
      votes[player] = index
      totalVotes[index] += 1

      
      local i = table.find(awaitingVotes, player)
      if i then
         table.remove(awaitingVotes, i)
      end
      local intermissionData = gameStateData.IntermissionData:Get()
      if intermissionData then
         local updatedIntermissionData = table.clone(intermissionData)
         updatedIntermissionData.VoteCount = table.clone(totalVotes)
         GameStateLibrary.applyValues({
            IntermissionData = updatedIntermissionData,
         })
      end
   end)
end

function RoundCyclingService.start()
   task.spawn(function()
      task.wait(2)
      RoundCyclingService.setNextRound("Classic", "GenericE")
	end)

   GameStateLibrary.RoundFinishedTasks:Add(function(winner: Player?, winMessage: string)
      if roundDurationConnection  then
         roundDurationConnection:Disconnect()
         roundDurationConnection = nil
         currentRoundEndsAt = nil
      end

      -- // Pre-Intermission
      local snapshot = GameStateLibrary.getSnapshot()
      snapshot.CurrentRoundData = nil
      snapshot.CurrentTimerEndsAt = nil
      snapshot.IntermissionData = {
         WinMessage = winMessage,
         VoteOptions = {},
         VoteCount = {0, 0},
         ChosenGamemode = nil,
      }
      snapshot.GameplayPhase = GameplayPhases.PreIntermission
      snapshot.LivingPlayersInArena = {}
      GameStateLibrary.applySnapshot(snapshot)

      task.wait(5)

      -- // Prep for lobby voting
      local possibleGamemodes = RoundCyclingService.getNextGamemodeChoices()
      totalVotes[1] = 0
      totalVotes[2] = 0
      table.clear(votes)
      table.clear(awaitingVotes)
      for _, p in pairs(game.Players:GetPlayers()) do
         table.insert(awaitingVotes, p)
      end

      local intermissionEndsAt = workspace:GetServerTimeNow() + INTERMISSION_DURATION
      snapshot.CurrentRoundData = nil
      snapshot.CurrentTimerEndsAt = intermissionEndsAt
      snapshot.IntermissionData = {
         WinMessage = winMessage,
         VoteOptions = possibleGamemodes,
         VoteCount = {0, 0},
         ChosenGamemode = nil,
      }
      snapshot.GameplayPhase = GameplayPhases.LobbyVoting
      GameStateLibrary.applySnapshot(snapshot)

      -- Wait for votes
      local elapsed = 0
      repeat
         local deltaTime = RunService.Heartbeat:Wait()
         elapsed += deltaTime
      until elapsed >= VOTE_DURATION or #awaitingVotes == 0
      
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

      local intermissionData = GameStateLibrary.getGameStateData().IntermissionData:Get()
      if intermissionData then
         local updatedIntermissionData = table.clone(intermissionData)
         updatedIntermissionData.VoteCount = table.clone(totalVotes)
         updatedIntermissionData.ChosenGamemode = chosenGamemode
         GameStateLibrary.applyValues({
            IntermissionData = updatedIntermissionData,
         })
      end
      
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