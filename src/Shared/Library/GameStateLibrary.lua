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
type ReplicatedFieldName = "IsInRound" | "Gamemode" | "CurrentMapName" | "LivingPlayersInArena" | "CanRespawn"

local isServer = RunService:IsServer()
local gameStateSyncEvent = SimpleRemotes.getEvent("GameStateSync")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

local GameStateLibrary = {}

local data = {
   IsInRound = false,
   Gamemode = nil :: string?,
   CurrentMapName = nil :: string?,
   CanRespawn = nil :: boolean?,

   LivingPlayersInArena = ReactiveValue.new({}),
   RoundStartingTasks = TasksList.new(),
   RoundFinishedTasks = TasksList.new() :: TasksList.TasksList<RoundFinishedTask>,
}

local replicatedFieldNames = table.freeze({
   IsInRound = true,
   Gamemode = true,
   CurrentMapName = true,
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

local function getSnapshot()
   return {
      IsInRound = data.IsInRound,
      Gamemode = data.Gamemode,
      CurrentMapName = data.CurrentMapName,
      LivingPlayersInArena = clonePlayers(data.LivingPlayersInArena:Get()),
      CanRespawn = data.CanRespawn,
   }
end

local function applyField(fieldName: ReplicatedFieldName, value: any)
   if fieldName == "LivingPlayersInArena" then
      data.LivingPlayersInArena:Set(clonePlayers(value))
      return
   end

   data[fieldName] = value
end

local function broadcastField(fieldName: ReplicatedFieldName, value: any)
   if not isServer then
      return
   end

   if fieldName == "LivingPlayersInArena" then
      gameStateSyncEvent:FireAllClients("Set", fieldName, clonePlayers(value))
      return
   end

   gameStateSyncEvent:FireAllClients("Set", fieldName, value)
end

local function applySnapshot(snapshot)
   applyField("IsInRound", snapshot.IsInRound)
   applyField("Gamemode", snapshot.Gamemode)
   applyField("CurrentMapName", snapshot.CurrentMapName)
   applyField("LivingPlayersInArena", snapshot.LivingPlayersInArena)
   applyField("CanRespawn", snapshot.CanRespawn)
end

local function sendSnapshot(player: Player)
   gameStateSyncEvent:FireClient(player, "Snapshot", getSnapshot())
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GameStateLibrary.getSnapshot()
   return getSnapshot()
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GameStateLibrary.init()
   
   setmetatable(GameStateLibrary, {
      __index = function(_, key)
         local rawValue = rawget(GameStateLibrary, key)
         if rawValue ~= nil then
            return rawValue
         end
         return data[key]
      end,
      __newindex = function(_, key, value)
         if not replicatedFieldNames[key :: ReplicatedFieldName] then
            error(`Unknown GameStateLibrary field: {key}`)
         end
         if key == "LivingPlayersInArena" then
            data.LivingPlayersInArena:Set(clonePlayers(value))
            return
         end
         data[key :: ReplicatedFieldName] = value
         broadcastField(key :: ReplicatedFieldName, value)
      end,
   })

   if isServer then
      -- // SERVER CONTEXT
      data.LivingPlayersInArena:Subscribe(function(newValue)
         broadcastField("LivingPlayersInArena", newValue)
      end)

      gameStateSyncEvent.OnServerEvent:Connect(function(player: Player, action: string)
         if action ~= "RequestSnapshot" then
            return
         end
         sendSnapshot(player)
      end)
   else
      -- // CLIENT CONTEXT
      gameStateSyncEvent.OnClientEvent:Connect(function(action: string, payload: any, value: any)
         if action == "Snapshot" then
            applySnapshot(payload)
            return
         end
         if action == "Set" then
            applyField(payload, value)
         end
      end)

      gameStateSyncEvent:FireServer("RequestSnapshot")
   end
end

function GameStateLibrary.start()
   
end

return GameStateLibrary