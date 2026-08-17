-- // Contains referential information on the current game state
--    Automatically manages replication between the server and client on data changes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ReactiveValue = require(ReplicatedStorage.Shared.Utils.ReactiveValue)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

type RoundFinishedTask = (winner: Player?, winMessage: string) -> ()
type SnapshotLoadedReason = "ServerApplied" | "ServerReplicated" | "InitialReplication"
type CurrentRoundData = {
   CurrentRoundId: number,
   Gamemode: string,
   CurrentMapName: string,
}
type IntermissionData = {
   WinMessage: string?,
   VoteOptions: {string},
   VoteCount: {number},
   ChosenGamemode: string?,
}
type ReplicatedFieldName =
   "CurrentRoundData"
   | "GameplayPhase"
   | "CurrentTimerEndsAt"
   | "CanRespawn"
   | "IntermissionData"
   | "LivingPlayersInArena"

type GameStateSnapshot = {
   CurrentRoundData: CurrentRoundData?,
   GameplayPhase: number,
   CurrentTimerEndsAt: number?,
   CanRespawn: boolean?,
   IntermissionData: IntermissionData?,
   LivingPlayersInArena: {Player},
}

type GameStatePatch = {
   CurrentRoundData: CurrentRoundData?,
   GameplayPhase: number?,
   CurrentTimerEndsAt: number?,
   CanRespawn: boolean?,
   IntermissionData: IntermissionData?,
   LivingPlayersInArena: {Player}?,
}

type SnapshotLoadedTask = (snapshot: GameStateSnapshot, reason: SnapshotLoadedReason) -> ()

type CurrentGameStateDataType = {
   CurrentRoundData: ReactiveValue.ReactiveValue<CurrentRoundData?>,
   GameplayPhase: ReactiveValue.ReactiveValue<number>,
   CurrentTimerEndsAt: ReactiveValue.ReactiveValue<number?>,
   CanRespawn: ReactiveValue.ReactiveValue<boolean?>,
   IntermissionData: ReactiveValue.ReactiveValue<IntermissionData?>,
   LivingPlayersInArena: ReactiveValue.ReactiveValue<{Player}>,
}

local isServer = RunService:IsServer()
local gameStateSyncEvent = SimpleRemotes.getEvent("GameStateSync")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

local GameStateLibrary = {}
GameStateLibrary.Ready = false

local CurrentGameStateData: CurrentGameStateDataType = {
   CurrentRoundData = ReactiveValue.new(nil :: CurrentRoundData?),
   GameplayPhase = ReactiveValue.new(GameplayPhases.LobbyEnded),
   CurrentTimerEndsAt = ReactiveValue.new(nil :: number?),
   CanRespawn = ReactiveValue.new(nil :: boolean?),
   IntermissionData = ReactiveValue.new(nil :: IntermissionData?),

   LivingPlayersInArena = ReactiveValue.new({}),
}

GameStateLibrary.RoundStartingTasks = TasksList.new()
GameStateLibrary.RoundFinishedTasks = TasksList.new() :: TasksList.TasksList<RoundFinishedTask>
GameStateLibrary.LobbyIntermissionStartedTasks = TasksList.new()
GameStateLibrary.GameStateSnapshotLoadedTasks = TasksList.new() :: TasksList.TasksList<SnapshotLoadedTask>

local replicatedFieldNames = table.freeze({
   CurrentRoundData = true,
   GameplayPhase = true,
   CurrentTimerEndsAt = true,
   IntermissionData = true,
   LivingPlayersInArena = true,
   CanRespawn = true,
}) :: { [ReplicatedFieldName]: boolean }

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function clonePlayers(source: {Player}): {Player}
   local cloned = table.create(#source)
   for index, player in ipairs(source) do
      cloned[index] = player
   end
   return cloned
end

local function cloneCurrentRoundData(source: CurrentRoundData?): CurrentRoundData?
   return if source then table.clone(source) else nil
end

local function currentRoundDataMatches(first: CurrentRoundData?, second: CurrentRoundData?): boolean
   if first == nil or second == nil then
      return first == second
   end
   return first.CurrentRoundId == second.CurrentRoundId
      and first.Gamemode == second.Gamemode
      and first.CurrentMapName == second.CurrentMapName
end

local function arraysMatch<T>(first: {T}, second: {T}): boolean
   if #first ~= #second then
      return false
   end
   for index, value in ipairs(first) do
      if value ~= second[index] then
         return false
      end
   end
   return true
end

local function cloneIntermissionData(source: IntermissionData?): IntermissionData?
   if source == nil then
      return nil
   end
   return {
      WinMessage = source.WinMessage,
      VoteOptions = table.clone(source.VoteOptions),
      VoteCount = table.clone(source.VoteCount),
      ChosenGamemode = source.ChosenGamemode,
   }
end

local function intermissionDataMatches(first: IntermissionData?, second: IntermissionData?): boolean
   if first == nil or second == nil then
      return first == second
   end
   return first.WinMessage == second.WinMessage
      and first.ChosenGamemode == second.ChosenGamemode
      and arraysMatch(first.VoteOptions, second.VoteOptions)
      and arraysMatch(first.VoteCount, second.VoteCount)
end

local function getSnapshot()
   return {
      CurrentRoundData = cloneCurrentRoundData(CurrentGameStateData.CurrentRoundData:Get()),
      GameplayPhase = CurrentGameStateData.GameplayPhase:Get(),
      CurrentTimerEndsAt = CurrentGameStateData.CurrentTimerEndsAt:Get(),
      CanRespawn = CurrentGameStateData.CanRespawn:Get(),
      IntermissionData = cloneIntermissionData(CurrentGameStateData.IntermissionData:Get()),
      LivingPlayersInArena = clonePlayers(CurrentGameStateData.LivingPlayersInArena:Get()),
   } :: GameStateSnapshot
end

local function encodeReplicatedValue(value: any): any
   if value == nil then
      return GlobalConfig.NilDataType
   end
   return value
end

local function decodeReplicatedValue(value: any): any
   if value == GlobalConfig.NilDataType then
      return nil
   end
   return value
end

local function getReplicatedSnapshotPayload(): {[string]: any}
   local snapshot = getSnapshot()
   local payload = {}
   for fieldName, _ in pairs(replicatedFieldNames) do
      local value = snapshot[fieldName]
      if fieldName == "CurrentRoundData" then
         payload[fieldName] = encodeReplicatedValue(cloneCurrentRoundData(value))
      elseif fieldName == "IntermissionData" then
         payload[fieldName] = encodeReplicatedValue(cloneIntermissionData(value))
      elseif fieldName == "LivingPlayersInArena" then
         payload[fieldName] = clonePlayers(value)
      else
         payload[fieldName] = encodeReplicatedValue(value)
      end
   end
   return payload
end

local function applySnapshotLocal(snapshot: GameStateSnapshot)
   local currentRoundData = decodeReplicatedValue(snapshot.CurrentRoundData)
   if not currentRoundDataMatches(currentRoundData, CurrentGameStateData.CurrentRoundData:Get()) then
      CurrentGameStateData.CurrentRoundData:Set(cloneCurrentRoundData(currentRoundData))
   end
   CurrentGameStateData.GameplayPhase:Set(snapshot.GameplayPhase)
   CurrentGameStateData.CurrentTimerEndsAt:Set(decodeReplicatedValue(snapshot.CurrentTimerEndsAt))
   CurrentGameStateData.CanRespawn:Set(decodeReplicatedValue(snapshot.CanRespawn))
   local intermissionData = decodeReplicatedValue(snapshot.IntermissionData)
   if not intermissionDataMatches(intermissionData, CurrentGameStateData.IntermissionData:Get()) then
      CurrentGameStateData.IntermissionData:Set(cloneIntermissionData(intermissionData))
   end
   CurrentGameStateData.LivingPlayersInArena:Set(clonePlayers(snapshot.LivingPlayersInArena))
end

local function applyPartialLocal(payload: {[string]: any})
   for fieldName, _ in pairs(replicatedFieldNames) do
      local encodedValue = payload[fieldName]
      if encodedValue ~= nil then
         local value = decodeReplicatedValue(encodedValue)
         if fieldName == "CurrentRoundData" then
            CurrentGameStateData.CurrentRoundData:Set(cloneCurrentRoundData(value))
         elseif fieldName == "IntermissionData" then
            CurrentGameStateData.IntermissionData:Set(cloneIntermissionData(value))
         elseif fieldName == "LivingPlayersInArena" then
            if value ~= nil then
               CurrentGameStateData[fieldName]:Set(clonePlayers(value))
            end
         else
            CurrentGameStateData[fieldName]:Set(value)
         end
      end
   end
end

local function fireSnapshotLoaded(snapshot: GameStateSnapshot, reason: SnapshotLoadedReason)
   GameStateLibrary.GameStateSnapshotLoadedTasks:Execute("parallel", snapshot, reason)
end

local function sendInitialSnapshot(player: Player)
   gameStateSyncEvent:FireClient(player, "InitialSnapshot", getReplicatedSnapshotPayload())
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GameStateLibrary.getSnapshot()
   return getSnapshot()
end

function GameStateLibrary.getGameStateData(): CurrentGameStateDataType
   return CurrentGameStateData
end

function GameStateLibrary.applySnapshot(snapshot: GameStateSnapshot, replicateToClients: boolean?)
   if snapshot.CurrentRoundData ~= nil then
      snapshot.GameplayPhase = GameplayPhases.RoundActive
   end

   local valuesChangedPayload = {}
   for fieldName, _ in pairs(replicatedFieldNames) do
      local value = snapshot[fieldName]
      local originalValue = CurrentGameStateData[fieldName]:Get()
      local hasChanged = false

      if fieldName == "CurrentRoundData" then
         hasChanged = not currentRoundDataMatches(value, originalValue)
      elseif fieldName == "IntermissionData" then
         hasChanged = not intermissionDataMatches(value, originalValue)
      elseif type(value) == "table" and type(originalValue) == "table" then
         if #value ~= #originalValue then
            hasChanged = true
         else
            for i = 1, #value do
               if value[i] ~= originalValue[i] then
                  hasChanged = true
                  break
               end
            end
         end
      else
         hasChanged = originalValue ~= value
      end

      if hasChanged then
         if fieldName == "CurrentRoundData" then
            valuesChangedPayload[fieldName] = encodeReplicatedValue(cloneCurrentRoundData(value))
         elseif fieldName == "IntermissionData" then
            valuesChangedPayload[fieldName] = encodeReplicatedValue(cloneIntermissionData(value))
         elseif fieldName == "LivingPlayersInArena" and type(value) == "table" then
            valuesChangedPayload[fieldName] = clonePlayers(value)
         else
            valuesChangedPayload[fieldName] = encodeReplicatedValue(value)
         end
      end
   end

   applySnapshotLocal(snapshot)

   if isServer and replicateToClients ~= false and next(valuesChangedPayload) ~= nil then
      gameStateSyncEvent:FireAllClients("SnapshotApplied", valuesChangedPayload)
   end

   fireSnapshotLoaded(getSnapshot(), if isServer then "ServerApplied" else "ServerReplicated")
end

function GameStateLibrary.applyValues(patch: GameStatePatch, replicateToClients: boolean?)
   if patch.CurrentRoundData ~= nil then
      patch.GameplayPhase = GameplayPhases.RoundActive
   end

   local changedValuesPayload = {}

   for fieldName, _ in pairs(replicatedFieldNames) do
      local value = patch[fieldName]
      if value ~= nil then
         local decodedValue = decodeReplicatedValue(value)
         local oldValue = CurrentGameStateData[fieldName]:Get()
         local hasChanged = false

         if fieldName == "IntermissionData" then
            hasChanged = not intermissionDataMatches(decodedValue, oldValue)
         elseif type(decodedValue) == "table" and type(oldValue) == "table" then
            -- Table patches are treated as changed to avoid in-place mutation edge cases.
            hasChanged = true
         else
            hasChanged = oldValue ~= decodedValue
         end

         if hasChanged then
            if fieldName == "CurrentRoundData" then
               changedValuesPayload[fieldName] = cloneCurrentRoundData(decodedValue)
            elseif fieldName == "IntermissionData" then
               changedValuesPayload[fieldName] = cloneIntermissionData(decodedValue)
            elseif fieldName == "LivingPlayersInArena" and type(decodedValue) == "table" then
               changedValuesPayload[fieldName] = clonePlayers(decodedValue)
            else
               changedValuesPayload[fieldName] = encodeReplicatedValue(decodedValue)
            end
         end
      end
   end

   if next(changedValuesPayload) == nil then
      return
   end

   applyPartialLocal(changedValuesPayload)

   if isServer and replicateToClients ~= false then
      gameStateSyncEvent:FireAllClients("SnapshotApplied", changedValuesPayload)
   end

   fireSnapshotLoaded(getSnapshot(), if isServer then "ServerApplied" else "ServerReplicated")
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GameStateLibrary.init()
   if isServer then
      -- // SERVER CONTEXT
      gameStateSyncEvent.OnServerEvent:Connect(function(player: Player, action: string)
         if action ~= "RequestSnapshot" then
            return
         end
         sendInitialSnapshot(player)
      end)
   else
      -- // CLIENT CONTEXT
      gameStateSyncEvent.OnClientEvent:Connect(function(action: string, payload: any)
         if action == "InitialSnapshot" then
            applySnapshotLocal(payload)
            fireSnapshotLoaded(getSnapshot(), "InitialReplication")
            return
         end
         if action == "SnapshotApplied" then
            applyPartialLocal(payload)
            fireSnapshotLoaded(getSnapshot(), "ServerReplicated")
            return
         end
      end)

      gameStateSyncEvent:FireServer("RequestSnapshot")
   end

   GameStateLibrary.Ready = true
end

function GameStateLibrary.start()
   
end

return GameStateLibrary