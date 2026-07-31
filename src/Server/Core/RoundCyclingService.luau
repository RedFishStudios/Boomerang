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

local function iterateRoundId()
   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.CurrentRoundId:Set(gameStateData.CurrentRoundId:Get() + 1)
end

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
      local currentGamemode = gameStateData.Gamemode:Get()
      if currentGamemode then
         local roundLogic = getLogic(currentGamemode)
         local snapshot = GameStateLibrary.getSnapshot()
         snapshot.Gamemode = nil
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
   return GameStateLibrary.getGameStateData().IsInRound:Get()
end

function RoundCyclingService.getCurrentRoundTypeId(): string?
   return GameStateLibrary.getGameStateData().Gamemode:Get()
end

-- // Returns true if current round permits late joining for the given player
function RoundCyclingService.canSpawnIntoRound(player: Player): boolean
   local gameStateData = GameStateLibrary.getGameStateData()
   if not gameStateData.IsInRound:Get() or not gameStateData.Gamemode:Get() then
      return false
   end
   return gameStateData.CanRespawn:Get()
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
   iterateRoundId()
   GameStateLibrary.RoundStartingTasks:Execute("parallel")

   local roundType = Gamemodes[roundTypeId]
   local roundDuration = roundType.TimeLasts
   local notificationServerTime = workspace:GetServerTimeNow()
   local roundEndsAt = notificationServerTime + roundDuration

   local snapshot = GameStateLibrary.getSnapshot()
   snapshot.IsInRound = true
   snapshot.Gamemode = roundTypeId
   snapshot.CurrentMapName = mapName
   snapshot.CurrentTimerEndsAt = roundEndsAt
   snapshot.CanRespawn = roundType.CanRespawn
   snapshot.IntermissionWinMessage = nil
   snapshot.IntermissionOptions = {}
   snapshot.IntermissionVotes = {0, 0}
   snapshot.IntermissionChosenGamemode = nil
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
      GameStateLibrary.applyValues({
         IntermissionVotes = totalVotes,
      })
   end)

   print(GameStateLibrary)
end

function RoundCyclingService.start()
   task.spawn(function()
      task.wait(2)
      RoundCyclingService.setNextRound("ThrowBoomerang", "GenericA")
	end)

   GameStateLibrary.RoundFinishedTasks:Add(function(winner: Player?, winMessage: string)
      iterateRoundId()
      GameTeamService.beginIntermission()

      for _, player in pairs(game.Players:GetPlayers()) do
         SpawnService.sendPlayerTo(player, LobbyService.getSpawnPoint().Position, true)
      end

      local livingPlayersInArena = table.create(0)
      GameStateLibrary.applyValues({
         LivingPlayersInArena = livingPlayersInArena,
      }, true)

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

      local intermissionEndsAt = workspace:GetServerTimeNow() + INTERMISSION_DURATION
      local snapshot = GameStateLibrary.getSnapshot()
      snapshot.IsInRound = false
      snapshot.Gamemode = nil
      snapshot.CurrentMapName = nil
      snapshot.CurrentTimerEndsAt = intermissionEndsAt
      snapshot.CanRespawn = nil
      snapshot.IntermissionWinMessage = winMessage
      snapshot.IntermissionOptions = possibleGamemodes
      snapshot.IntermissionVotes = {0, 0}
      snapshot.IntermissionChosenGamemode = nil
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

      GameStateLibrary.applyValues({
         IntermissionVotes = totalVotes,
         IntermissionChosenGamemode = chosenGamemode,
      })
      
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