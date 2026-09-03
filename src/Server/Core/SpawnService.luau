--[[
  Manages a simple system of detecting player deaths/respawns

  Author:
  @Soulsplosion
]]

local SpawnService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local LobbyService = require(ServerStorage.Server.Core.LobbyService)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local playersInLobby: {[Player]: boolean} = {}
local pendingInitialSpawnWorkerToken: {}? = nil

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function safeGetPlayerCharacter(player: Player)
   if not player.Character then
      local passed = 0
      repeat
         task.wait()
         print(`waiting for player character: {player}`)
         passed += 1
      until passed >= 300 or player.Character
      if not player.Character then
         warn(`player character never loaded: {player}`)
         return nil
      end
   end
   return player.Character
end

-- // NOTE: Do not rely on this for critical game logic
--    This helps the player predict the general area they will spawn and is NOT the definitive declaration of their spawn point
local function prepPlayerSpawnpoint(player: Player)
   local gameStateData = GameStateLibrary.getGameStateData()
   local currentRoundData = gameStateData.CurrentRoundData:Get()
   if currentRoundData and currentRoundData.CanRespawn then
      player.RespawnLocation = ArenaService.getSpawnPoint(player)
   else
      player.RespawnLocation = LobbyService.getSpawnPoint()
      GameTeamService.setOutOfGame(player)
   end
end

-- // Spawn thread to continually attempt to send players to the arena if original sends failed (such as their characters not being loaded)
local function startPendingInitialSpawnWorker(playersAwaitingInitialSpawn: {[Player]: true}, roundId: number?)
   local workerToken = {}
   pendingInitialSpawnWorkerToken = workerToken

   if next(playersAwaitingInitialSpawn) == nil then
      return
   end

   task.spawn(function()
      local gameStateData = GameStateLibrary.getGameStateData()
      while pendingInitialSpawnWorkerToken == workerToken and next(playersAwaitingInitialSpawn) ~= nil do
         local currentRoundData = gameStateData.CurrentRoundData:Get()
         if currentRoundData == nil or currentRoundData.CurrentRoundId ~= roundId then
            if pendingInitialSpawnWorkerToken == workerToken then
               pendingInitialSpawnWorkerToken = nil
            end
            return
         end

         local livingPlayersInArena = gameStateData.LivingPlayersInArena:Get()
         for player, _ in pairs(playersAwaitingInitialSpawn) do
            if pendingInitialSpawnWorkerToken ~= workerToken then
               return
            end
            if player.Parent ~= Players or table.find(livingPlayersInArena, player) then
               playersAwaitingInitialSpawn[player] = nil
            elseif SpawnService.isPlayerReadyForArena(player) then
               SpawnService.sendPlayerToArena(player)
               playersAwaitingInitialSpawn[player] = nil
            end
         end

         if next(playersAwaitingInitialSpawn) ~= nil then
            RunService.Heartbeat:Wait()
         end
      end

      if pendingInitialSpawnWorkerToken == workerToken then
         pendingInitialSpawnWorkerToken = nil
      end
   end)
end

-- // Sends every ready player into the newly-changed arena, retrying stragglers (e.g. characters still loading) via the pending-spawn worker
local function sendAllPlayersToArena()
   local gameStateData = GameStateLibrary.getGameStateData()
   local currentRoundData = gameStateData.CurrentRoundData:Get()
   local roundId = currentRoundData and currentRoundData.CurrentRoundId
   local playersAwaitingInitialSpawn = {} :: {[Player]: true}
   for _, player in ipairs(Players:GetPlayers()) do
      if SpawnService.isPlayerReadyForArena(player) then
         SpawnService.sendPlayerToArena(player)
      else
         playersAwaitingInitialSpawn[player] = true
      end
   end

   startPendingInitialSpawnWorker(playersAwaitingInitialSpawn, roundId)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Returns true if the player currently has everything needed to be sent into the arena
function SpawnService.isPlayerReadyForArena(player: Player): boolean
   return ArenaService.isReadyToSendToArena(player)
end

-- // The only entry point external modules should use to send a player into the arena
function SpawnService.sendPlayerToArena(player: Player)
   ArenaService.sendToArena(player)
   playersInLobby[player] = nil
end

function SpawnService.sendPlayerTo(player: Player, location: Vector3, forceLive: boolean?)
   local character = safeGetPlayerCharacter(player)
   if not character then
      return
   end
   local humanoid = character:FindFirstChildWhichIsA("Humanoid")
   if not humanoid then
      return
   end
   if forceLive and humanoid.Health <= 0 then
      player.CharacterAdded:Once(function()
         character = safeGetPlayerCharacter(player)
         SpawnService.sendPlayerTo(player, location, true)
      end)
      player:LoadCharacterAsync()
      return
   end
   local rootPart = character:FindFirstChild("HumanoidRootPart")
   if not rootPart then
      return
   end
   local rayOrigin = location + Vector3.new(0, 5, 0)
   local rayDirection = Vector3.new(0, -10, 0)
   local raycastParams = RaycastParams.new()
   raycastParams.FilterDescendantsInstances = {character}
   raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
   local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
   if rayResult then
      character:PivotTo(CFrame.new(rayResult.Position + Vector3.new(0, 3, 0)))
   else
      character:PivotTo(CFrame.new(location))
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SpawnService.init()
   local gameStateData = GameStateLibrary.getGameStateData()

   gameStateData.GameplayPhase:Subscribe(function(gameplayPhase)
      if gameplayPhase == GameplayPhases.LobbyVoting or gameplayPhase == GameplayPhases.PendingPlayers or gameplayPhase == GameplayPhases.LobbyEnded then
         local lobbySpawnPosition = LobbyService.getSpawnPoint().Position
         for _, player in pairs(Players:GetPlayers()) do
            if playersInLobby[player] then
               continue
            end
            SpawnService.sendPlayerTo(player, lobbySpawnPosition, true)
            playersInLobby[player] = true
         end
      end
   end)

   PlayersUtil.PlayerAdded:Add(function(player: Player)
      prepPlayerSpawnpoint(player)
   end)

   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      playersInLobby[player] = nil
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player)
      prepPlayerSpawnpoint(player)
   end)

   PlayersUtil.CharacterLoaded:Add(function(player: Player, _character: Model, _humanoid: Humanoid, _rootPart: BasePart)
         local currentRoundData = gameStateData.CurrentRoundData:Get()
         if currentRoundData == nil then
            return
         end
         if currentRoundData.CanRespawn == false then
            return
         end
         if SpawnService.isPlayerReadyForArena(player) then
            SpawnService.sendPlayerToArena(player)
         end
   end)

   ArenaService.MapChangedTasks:Add(function(_mapName: string)
      sendAllPlayersToArena()
   end)
end

function SpawnService.start()

end

function SpawnService.test()

end

return SpawnService