-- // Contains referential information on the current game state
--    Automatically manages replication between the server and client on data changes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ReactiveValue = require(ReplicatedStorage.Shared.Utils.ReactiveValue)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

type RoundFinishedTask = (winner: Player?, winMessage: string) -> ()
type SnapshotLoadedReason = "ServerApplied" | "ServerReplicated" | "InitialReplication"
type ReplicatedFieldName =
   "IsInRound"
   | "Gamemode"
   | "CurrentMapName"
   | "CurrentTimerEndsAt"
   | "CanRespawn"
   | "IntermissionWinMessage"
   | "IntermissionOptions"
   | "IntermissionVotes"
   | "IntermissionChosenGamemode"
   | "LivingPlayersInArena"

type GameStateSnapshot = {
   CurrentRoundId: number,
   IsInRound: boolean,
   Gamemode: string?,
   CurrentMapName: string?,
   CurrentTimerEndsAt: number?,
   CanRespawn: boolean?,
   IntermissionWinMessage: string?,
   IntermissionOptions: {string},
   IntermissionVotes: {number},
   IntermissionChosenGamemode: string?,
   LivingPlayersInArena: {Player},
}

type GameStatePatch = {
   CurrentRoundId: number?,
   IsInRound: boolean?,
   Gamemode: string?,
   CurrentMapName: string?,
   CurrentTimerEndsAt: number?,
   CanRespawn: boolean?,
   IntermissionWinMessage: string?,
   IntermissionOptions: {string}?,
   IntermissionVotes: {number}?,
   IntermissionChosenGamemode: string?,
   LivingPlayersInArena: {Player}?,
}

type SnapshotLoadedTask = (snapshot: GameStateSnapshot, reason: SnapshotLoadedReason) -> ()

type CurrentGameStateDataType = {
   CurrentRoundId: ReactiveValue.ReactiveValue<number>,
   IsInRound: ReactiveValue.ReactiveValue<boolean>,
   Gamemode: ReactiveValue.ReactiveValue<string>,
   CurrentMapName: ReactiveValue.ReactiveValue<string?>,
   CurrentTimerEndsAt: ReactiveValue.ReactiveValue<number?>,
   CanRespawn: ReactiveValue.ReactiveValue<boolean?>,
   IntermissionWinMessage: ReactiveValue.ReactiveValue<string?>,
   IntermissionOptions: ReactiveValue.ReactiveValue<{string}>,
   IntermissionVotes: ReactiveValue.ReactiveValue<{number}>,
   IntermissionChosenGamemode: ReactiveValue.ReactiveValue<string?>,
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
   CurrentRoundId = ReactiveValue.new(0),
   IsInRound = ReactiveValue.new(false),
   Gamemode = ReactiveValue.new(nil :: string?),
   CurrentMapName = ReactiveValue.new(nil :: string?),
   CurrentTimerEndsAt = ReactiveValue.new(nil :: number?),
   CanRespawn = ReactiveValue.new(nil :: boolean?),
   IntermissionWinMessage = ReactiveValue.new(nil :: string?),
   IntermissionOptions = ReactiveValue.new({}),
   IntermissionVotes = ReactiveValue.new({0, 0}),
   IntermissionChosenGamemode = ReactiveValue.new(nil :: string?),

   LivingPlayersInArena = ReactiveValue.new({}),
}

GameStateLibrary.RoundStartingTasks = TasksList.new()
GameStateLibrary.RoundFinishedTasks = TasksList.new() :: TasksList.TasksList<RoundFinishedTask>
GameStateLibrary.LobbyIntermissionStartedTasks = TasksList.new()
GameStateLibrary.GameStateSnapshotLoadedTasks = TasksList.new() :: TasksList.TasksList<SnapshotLoadedTask>

local replicatedFieldNames = table.freeze({
   IsInRound = true,
   Gamemode = true,
   CurrentMapName = true,
   CurrentTimerEndsAt = true,
   IntermissionWinMessage = true,
   IntermissionOptions = true,
   IntermissionVotes = true,
   IntermissionChosenGamemode = true,
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

local function cloneOptions(source: {string}): {string}
   local cloned = table.create(#source)
   for index, option in ipairs(source) do
      cloned[index] = option
   end
   return cloned
end

local function getSnapshot()
   return {
      CurrentRoundId = CurrentGameStateData.CurrentRoundId:Get(),
      IsInRound = CurrentGameStateData.IsInRound:Get(),
      Gamemode = CurrentGameStateData.Gamemode:Get(),
      CurrentMapName = CurrentGameStateData.CurrentMapName:Get(),
      CurrentTimerEndsAt = CurrentGameStateData.CurrentTimerEndsAt:Get(),
      CanRespawn = CurrentGameStateData.CanRespawn:Get(),
      IntermissionWinMessage = CurrentGameStateData.IntermissionWinMessage:Get(),
      IntermissionOptions = cloneOptions(CurrentGameStateData.IntermissionOptions:Get()),
      IntermissionVotes = cloneOptions(CurrentGameStateData.IntermissionVotes:Get()),
      IntermissionChosenGamemode = CurrentGameStateData.IntermissionChosenGamemode:Get(),
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
      if fieldName == "IntermissionOptions" then
         payload[fieldName] = cloneOptions(value)
      elseif fieldName == "LivingPlayersInArena" then
         payload[fieldName] = clonePlayers(value)
      else
         payload[fieldName] = encodeReplicatedValue(value)
      end
   end
   return payload
end

local function applySnapshotLocal(snapshot: GameStateSnapshot)
   CurrentGameStateData.IsInRound:Set(snapshot.IsInRound)
   CurrentGameStateData.Gamemode:Set(decodeReplicatedValue(snapshot.Gamemode))
   CurrentGameStateData.CurrentMapName:Set(decodeReplicatedValue(snapshot.CurrentMapName))
   CurrentGameStateData.CurrentTimerEndsAt:Set(decodeReplicatedValue(snapshot.CurrentTimerEndsAt))
   CurrentGameStateData.CanRespawn:Set(decodeReplicatedValue(snapshot.CanRespawn))
   CurrentGameStateData.IntermissionWinMessage:Set(decodeReplicatedValue(snapshot.IntermissionWinMessage))
   CurrentGameStateData.IntermissionOptions:Set(cloneOptions(snapshot.IntermissionOptions))
   CurrentGameStateData.IntermissionVotes:Set(cloneOptions(snapshot.IntermissionVotes))
   CurrentGameStateData.IntermissionChosenGamemode:Set(decodeReplicatedValue(snapshot.IntermissionChosenGamemode))
   CurrentGameStateData.LivingPlayersInArena:Set(clonePlayers(snapshot.LivingPlayersInArena))
end

local function applyPartialLocal(payload: {[string]: any})
   for fieldName, _ in pairs(replicatedFieldNames) do
      local encodedValue = payload[fieldName]
      if encodedValue ~= nil then
         local value = decodeReplicatedValue(encodedValue)
         if fieldName == "IntermissionOptions" then
            if value ~= nil then
               CurrentGameStateData[fieldName]:Set(cloneOptions(value))
            end
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
   local valuesChangedPayload = {}
   for fieldName, _ in pairs(replicatedFieldNames) do
      local value = snapshot[fieldName]
      local originalValue = CurrentGameStateData[fieldName]:Get()
      local hasChanged = false

      if type(value) == "table" and type(originalValue) == "table" then
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
         if fieldName == "IntermissionOptions" and type(value) == "table" then
            valuesChangedPayload[fieldName] = cloneOptions(value)
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
   local changedValuesPayload = {}

   for fieldName, _ in pairs(replicatedFieldNames) do
      local value = patch[fieldName]
      if value ~= nil then
         local decodedValue = decodeReplicatedValue(value)
         local oldValue = CurrentGameStateData[fieldName]:Get()
         local hasChanged = false

         if type(decodedValue) == "table" and type(oldValue) == "table" then
            -- Table patches are treated as changed to avoid in-place mutation edge cases.
            hasChanged = true
         else
            hasChanged = oldValue ~= decodedValue
         end

         if hasChanged then
            if fieldName == "IntermissionOptions" and type(decodedValue) == "table" then
               changedValuesPayload[fieldName] = cloneOptions(decodedValue)
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