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
local CurrentGameState = require(ReplicatedStorage.Shared.Referential.CurrentGameState)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SpawnService = require(ServerStorage.Server.Core.SpawnService)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local GamemodeLogics = ServerStorage.Server.Logics.GamemodeLogics
local GamemodeLogicModules = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local roundDurationConnection: RBXScriptConnection? = nil
local currentRoundEndsAt: number? = nil

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
   CurrentGameState.RemainingTime = secondsLeft
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
   until #availableForChoice >= 3
   return availableForChoice
end

function RoundCyclingService.setNextRound(roundTypeId: string, mapName: string)
   local roundType = Gamemodes[roundTypeId]
   local roundDuration = roundType.TimeLasts
   local notificationServerTime = workspace:GetServerTimeNow()

   CurrentGameState.Gamemode = roundTypeId
   CurrentGameState.CurrentMapName = mapName
   CurrentGameState.RemainingTime = roundDuration
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

   SpawnService.PlayerDiedTasks:Add(function(Player: Player)
      print(CurrentGameState.LivingPlayersInArena)
      local i = table.find(CurrentGameState.LivingPlayersInArena, Player)
      if i then 
         table.remove(CurrentGameState.LivingPlayersInArena, i)
         CurrentGameState.LivingPlayersInArenaUpdatedTasks:Execute("parallel", CurrentGameState.LivingPlayersInArena)
      end
   end)

   SpawnService.PlayerSpawnedTasks:Add(function(player: Player, inArena: boolean)
      if not table.find(CurrentGameState.LivingPlayersInArena, player) then
         table.insert(CurrentGameState.LivingPlayersInArena, player)
         CurrentGameState.LivingPlayersInArenaUpdatedTasks:Execute("parallel", CurrentGameState.LivingPlayersInArena)
      end
   end)

   PlayersUtil.onPlayerRemoving(function(player: Player)
      local i = table.find(CurrentGameState.LivingPlayersInArena, player)
      if i then 
         table.remove(CurrentGameState.LivingPlayersInArena, i)
         CurrentGameState.LivingPlayersInArenaUpdatedTasks:Execute("parallel", CurrentGameState.LivingPlayersInArena)
      end
   end)

	task.spawn(function()
      task.wait(2)
      RoundCyclingService.setNextRound("ThrowBoomerang", "GenericA")
	end)

   CurrentGameState.RoundFinishedTasks:Add(function()
      print("A ROUND FINISHED - BEGINNING INTERMISSION -")

      table.clear(CurrentGameState.LivingPlayersInArena)
      CurrentGameState.LivingPlayersInArenaUpdatedTasks:Execute("parallel", CurrentGameState.LivingPlayersInArena)

      if roundDurationConnection  then
         roundDurationConnection:Disconnect()
         roundDurationConnection = nil
         currentRoundEndsAt = nil
      end

      -- // Establish available options for next round
      local possibleMaps = ArenaService.getNextMapChoices()
      local possibleGamemodes = RoundCyclingService.getNextGamemodeChoices()
      local options: {
         {
            Gamemode: string,
            Map: string
         }
      } = {}
      repeat
         local chosenMapIndex = math.random(#possibleMaps)
         local chosenGamemodeIndex = math.random(#possibleGamemodes)
         table.insert(options, {
            Gamemode = possibleGamemodes[chosenGamemodeIndex],
            Map = possibleMaps[chosenMapIndex]
         })
         table.remove(possibleMaps, chosenMapIndex)
         table.remove(possibleGamemodes, chosenGamemodeIndex)
      until #options == 3

      CurrentGameState.IsInRound = false
      CurrentGameState.RoundTypeId = nil
      CurrentGameState.CurrentMapName = nil
      CurrentGameState.RemainingTime = nil
      CurrentGameState.CanRespawn = nil

      -- // PLACEHOLDER: automated inermission with randomly chosen next round
      local ticks = 0
      repeat
         task.wait(1)
         ticks+=1
         print("Intermission...")
      until ticks >= 3
      local choice = math.random(#options)
		RoundCyclingService.setNextRound("Elimination", options[choice].Map)
   end)
end

-- function RoundCyclingService.start() end

-- function RoundCyclingService.test() end

return RoundCyclingService