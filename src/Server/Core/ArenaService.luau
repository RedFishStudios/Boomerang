--[[
  - Manages arena map selection
  - Manages arena map spawnpoint usage (spawning players into the map)
  - Manages arena map functionality such as animated/interactive objects

  Author:
  @Soulsplosion
]]

local ArenaService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local GameTeamLibrary = require(game.ReplicatedStorage.Shared.Library.GameTeamLibrary)
local ArenaLibrary = require(ReplicatedStorage.Shared.Library.ArenaLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type MapChangedTask = (newMapName: string)->()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local mapFolder = game.ServerStorage.Server.Assets.Maps
local arenaFolder = ArenaLibrary.getArenaFolder()

local registeredMaps: {
   [string]: Model
} = {}
local pendingInitialSpawnWorkerToken: {}? = nil

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ArenaService.MapChangedTasks = TasksList.new() :: TasksList.TasksList<MapChangedTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function sendPlayerToSpawnPosition(player: Player, position: Vector3)
   local character = player.Character
   if not character then
      return
   end

   local fromPosition = position + Vector3.new(0, 3, 0)
   local raycastParams = RaycastParams.new()
   raycastParams.CollisionGroup = CollisionGroupConstants.Players
   raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
   raycastParams.FilterDescendantsInstances = {character}
   local raycastResult = workspace:Raycast(fromPosition, Vector3.new(0, -100, 0), raycastParams)
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not humanoid then
      return
   end

   local groundPosition = if raycastResult then raycastResult.Position else position
   character:PivotTo(CFrame.new(groundPosition + Vector3.new(0, humanoid.HipHeight, 0)))
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ArenaService.getPickupSpawns(): {BasePart}
   local currentMap = ArenaService.getArenaModel()
   if not currentMap then
      return {}
   end
   local pickupSpawnsFolder = currentMap:FindFirstChild("Pickups")
   if not pickupSpawnsFolder then
      return {}
   end
   return pickupSpawnsFolder:GetChildren()
end

-- // Return set of map names that can be chosen from for voting
function ArenaService.getAvailableMaps(forGamemode: string): {string}
   local availableMapNames = {}
   for mapName, _ in pairs(registeredMaps) do
      table.insert(availableMapNames, mapName)
   end
   
   local availableForChoice = {}
   repeat
      local choice = availableMapNames[math.random(1, #availableMapNames)]
      if not table.find(availableForChoice, choice) then
         table.insert(availableForChoice, choice)
      end
   until #availableForChoice >= 3
   return availableForChoice
end

function ArenaService.getSpawnPoint(player: Player): BasePart?
   local gameStateData = CurrentGameState.getGameStateData()
   local currentRoundData = gameStateData.CurrentRoundData:Get()
   local forRoundId = if currentRoundData then currentRoundData.CurrentRoundId else nil

   -- Get character
   if not player.Character then
      local elapsed = 0
      repeat
         task.wait(0.1)
         elapsed += 0.1
      until player.Character or elapsed >= 3
      if not player.Character then
         warn(`player character never loaded to send to arena: {player}`)
         return
      end
      local latestRoundData = gameStateData.CurrentRoundData:Get()
      if not latestRoundData or latestRoundData.CurrentRoundId ~= forRoundId then
         warn(`arenaservice.sendtoarena: round changed while awaiting character: {player}`)
         return
      end
   end

   -- Get primary part
   if not player.Character.PrimaryPart then
      local elapsed = 0
      repeat
         task.wait(0.1)
         elapsed += 0.1
      until not player.Character or player.Character.PrimaryPart or elapsed >= 3
      if not player.Character or not player.Character.PrimaryPart then
         warn(`player character has no primary part to send to arena: {player}`)
         return
      end
      local latestRoundData = gameStateData.CurrentRoundData:Get()
      if not latestRoundData or latestRoundData.CurrentRoundId ~= forRoundId then
         warn(`arenaservice.sendtoarena: round changed while awaiting player primary part: {player}`)
         return
      end
   end

   if gameStateData.CurrentRoundData:Get() == nil then
      -- Round ended; cease arena send call
      return
   end
   
   local currentArenaModel = arenaFolder:FindFirstChildWhichIsA("Model")
   if not currentArenaModel then
      warn(`No current arena model found to send player to: {player}`)
      return
   end

   -- Choose a spawn point
   local MIN_DISTANCE = 75
   local spawnPoints = currentArenaModel:FindFirstChild("SpawnPoints"):GetChildren()
   local chosenSpawn = nil

   if #spawnPoints == 0 then
      warn(`No spawn points found in arena for player: {player}`)
      return
   end

   local startIndex = math.random(#spawnPoints)
   for offset = 0, #spawnPoints - 1 do
      local index = ((startIndex + offset - 1) % #spawnPoints) + 1
      local spawn = spawnPoints[index]
      local valid = true
      for _, otherPlayer in ipairs(Players:GetPlayers()) do
         if otherPlayer == player then
            continue
         end
         if otherPlayer.Team ~= player.Team or (player.Team and GameTeamLibrary.hasFriendlyFire(player.Team)) then
            local character = otherPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
               local distance = (root.Position - spawn.Position).Magnitude
               if distance < MIN_DISTANCE then
                  valid = false
                  break
               end
            end
         end
      end
      if valid then
         chosenSpawn = spawn
         break
      end
   end

   if not chosenSpawn then
      warn(`no intelligently chosen spawn; sending to random position`)
      chosenSpawn = spawnPoints[math.random(#spawnPoints)]
   end

   return chosenSpawn
end

function ArenaService.isReadyToSendToArena(player: Player): boolean
   local currentRoundData = CurrentGameState.getGameStateData().CurrentRoundData:Get()
   if currentRoundData == nil or player.Parent ~= Players then
      return false
   end

   local character = player.Character
   if not character or not character.Parent then
      return false
   end
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   local rootPart = character:FindFirstChild("HumanoidRootPart")
   if not humanoid
      or humanoid.Health <= 0
      or not rootPart
      or not rootPart:IsA("BasePart")
      or not character.PrimaryPart
   then
      return false
   end

   local currentArenaModel = ArenaService.getArenaModel()
   local spawnPointsFolder = currentArenaModel and currentArenaModel:FindFirstChild("SpawnPoints")
   if not spawnPointsFolder then
      return false
   end
   for _, spawnPoint in ipairs(spawnPointsFolder:GetChildren()) do
      if spawnPoint:IsA("BasePart") then
         return true
      end
   end
   return false
end

function ArenaService.getCurrentArenaPosition(): Vector3?
   local currentArenaModel = arenaFolder:FindFirstChildWhichIsA("Model")
   if not currentArenaModel then
      print(`No current arena model found`)
      return nil
   end
   return currentArenaModel:GetPivot().Position
end

-- // Send player to a random spawn point in the arena
function ArenaService.sendToArena(player: Player)
   if not ArenaService.isReadyToSendToArena(player) then
      warn(`Player is not ready to send to arena: {player}`)
      return
   end

   local chosenSpawn = ArenaService.getSpawnPoint(player)
   if not chosenSpawn then
      return
   end
   sendPlayerToSpawnPosition(player, chosenSpawn.Position)

   local gameStateData = CurrentGameState.getGameStateData()
   local livingPlayersInArena = table.clone(gameStateData.LivingPlayersInArena:Get())
   if not table.find(livingPlayersInArena, player) then
      table.insert(livingPlayersInArena, player)
      CurrentGameState.applyValues({
         LivingPlayersInArena = livingPlayersInArena,
      })
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
      local gameStateData = CurrentGameState.getGameStateData()
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
            elseif ArenaService.isReadyToSendToArena(player) then
               ArenaService.sendToArena(player)
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

-- // Set the arena to this map name
function ArenaService.setArena(mapName: string)
   local map = registeredMaps[mapName]
   if not map then
      warn(`Attempted to set arena to unregistered map: {mapName}`)
      return
   end

   local currentMap = arenaFolder:FindFirstChildWhichIsA("Model")
   if currentMap then
      currentMap:Destroy()
   end
   
   local liveMap = map:Clone()
   liveMap.Parent = arenaFolder

   CurrentGameState.applyValues({
      LivingPlayersInArena = {},
   })

   local gameStateData = CurrentGameState.getGameStateData()
   local currentRoundData = gameStateData.CurrentRoundData:Get()
   local roundId = currentRoundData and currentRoundData.CurrentRoundId
   local playersAwaitingInitialSpawn = {} :: {[Player]: true}
   for _, player in ipairs(Players:GetPlayers()) do
      if ArenaService.isReadyToSendToArena(player) then
         ArenaService.sendToArena(player)
      else
         playersAwaitingInitialSpawn[player] = true
      end
   end

   startPendingInitialSpawnWorker(playersAwaitingInitialSpawn, roundId)
   ArenaService.MapChangedTasks:Execute("parallel", mapName)
end

function ArenaService.getAllMapModels()
   return mapFolder:GetChildren()
end

function ArenaService.getArenaModel(): Model?
   return ArenaLibrary.getArenaModel()
end

function ArenaService.getConfig(configName: string)
   local currentArenaModel = arenaFolder:FindFirstChildWhichIsA("Model")
   if not currentArenaModel then
      warn(`No current arena model found to get config from: {configName}`)
      return nil
   end

   local configFolder = currentArenaModel:FindFirstChild("Config")
   if not configFolder then
      warn(`Current arena model is missing Config folder: {configName}`)
      return nil
   end

   local config = configFolder:FindFirstChild(configName)
   if not config then
      warn(`Current arena model is missing requested config: {configName}`)
      return nil
   end

   return config
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ArenaService.init()
   -- Register maps
	for _, c in pairs(mapFolder:GetChildren()) do
      if not c:IsA("Model") then
         warn(`nonaccepted child in map folder: {c.Name}`)
         c:Destroy()
         continue
      end

      local walls = c:FindFirstChild("Walls")
      if walls then
         for _, wall in pairs(walls:GetDescendants()) do
            if (wall:IsA("MeshPart") or wall:IsA("BasePart")) and wall.CanCollide then
               wall.CollisionGroup = CollisionGroupConstants.ArenaWalls
            end
         end
      else
         warn(`map {c.Name} is missing Walls folder`)
      end

      local spawnpoints = c:FindFirstChild("SpawnPoints")
      if not spawnpoints then
         warn(`map {c.Name} is missing SpawnPoints folder`)
      else
         for _, c in pairs(spawnpoints:GetChildren()) do
            if c:IsA("SpawnLocation") then
               c.Duration = GlobalConfig.SpawnShieldDuration
            end
         end
      end

      local pickups = c:FindFirstChild("Pickups")
      if not pickups then
         warn(`map {c.Name} is missing Pickup spawns folder`)
      else
         for _, c in pairs(pickups:GetChildren()) do
            if c:IsA("BasePart") or c:IsA("Part") then
               c.Transparency = 1
               c.CanCollide = false
            end
         end
      end

      local config = c:FindFirstChild("Config")
      if not config then
         warn(`map {c.Name} is missing Config folder`)
      else
         local stormclose = config:FindFirstChild("StormClose")
         if not stormclose then
            warn(`map {c.Name} is missing StormClose folder`)
         else
            stormclose.Transparency = 1
         end
      end

      registeredMaps[c.Name] = c
	end
end

function ArenaService.start()
   
end

function ArenaService.test()

end

return ArenaService
