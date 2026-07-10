-- // Contains referential information on the current game state
--    Automatically manages replication between the server and client on data changes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ReactiveValue = require(ReplicatedStorage.Shared.Utils.ReactiveValue)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

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

local function applySnapshotLocal(snapshot: GameStateSnapshot)
   CurrentGameStateData.IsInRound:Set(snapshot.IsInRound)
   CurrentGameStateData.Gamemode:Set(snapshot.Gamemode)
   CurrentGameStateData.CurrentMapName:Set(snapshot.CurrentMapName)
   CurrentGameStateData.CurrentTimerEndsAt:Set(snapshot.CurrentTimerEndsAt)
   CurrentGameStateData.CanRespawn:Set(snapshot.CanRespawn)
   CurrentGameStateData.IntermissionWinMessage:Set(snapshot.IntermissionWinMessage)
   CurrentGameStateData.IntermissionOptions:Set(cloneOptions(snapshot.IntermissionOptions))
   CurrentGameStateData.IntermissionVotes:Set(cloneOptions(snapshot.IntermissionVotes))
   CurrentGameStateData.IntermissionChosenGamemode:Set(snapshot.IntermissionChosenGamemode)
   CurrentGameStateData.LivingPlayersInArena:Set(clonePlayers(snapshot.LivingPlayersInArena))
end

local function applyPartialLocal(payload: GameStatePatch)
   for fieldName, _ in pairs(replicatedFieldNames) do
      local value = payload[fieldName]
      if value ~= nil then
         if fieldName == "IntermissionOptions" then
            CurrentGameStateData[fieldName]:Set(cloneOptions(value))
         elseif fieldName == "LivingPlayersInArena" then
            CurrentGameStateData[fieldName]:Set(clonePlayers(value))
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
   gameStateSyncEvent:FireClient(player, "InitialSnapshot", getSnapshot())
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
   local valuesChanged = {} :: GameStatePatch
   for k, v in pairs(snapshot) do
      local originalValue = CurrentGameStateData[k]:Get()
      if type(v) == "table" and type(originalValue) == "table" then
         if #v ~= #originalValue then
            valuesChanged[k] = v
         else
            for i = 1, #v do
               if v[i] ~= originalValue[i] then
                  valuesChanged[k] = v
                  break
               end
            end
         end
      else
         if originalValue ~= v then
            valuesChanged[k] = v
         end
      end
   end

   applySnapshotLocal(snapshot)

   if isServer and replicateToClients ~= false and next(valuesChanged) ~= nil then
      gameStateSyncEvent:FireAllClients("SnapshotApplied", valuesChanged)
   end

   fireSnapshotLoaded(getSnapshot(), if isServer then "ServerApplied" else "ServerReplicated")
end

function GameStateLibrary.applyValues(patch: GameStatePatch, replicateToClients: boolean?)
   local changedValues = {} :: GameStatePatch

   for fieldName, _ in pairs(replicatedFieldNames) do
      local value = patch[fieldName]
      if value ~= nil then
         local oldValue = CurrentGameStateData[fieldName]:Get()
         local hasChanged = false

         if type(value) == "table" and type(oldValue) == "table" then
            -- Table patches are treated as changed to avoid in-place mutation edge cases.
            hasChanged = true
         else
            hasChanged = oldValue ~= value
         end

         if hasChanged then
            if fieldName == "IntermissionOptions" then
               changedValues[fieldName] = cloneOptions(value)
            elseif fieldName == "LivingPlayersInArena" then
               changedValues[fieldName] = clonePlayers(value)
            else
               changedValues[fieldName] = value
            end
         end
      end
   end

   if next(changedValues) == nil then
      return
   end

   applyPartialLocal(changedValues)

   if isServer and replicateToClients ~= false then
      gameStateSyncEvent:FireAllClients("SnapshotApplied", changedValues)
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