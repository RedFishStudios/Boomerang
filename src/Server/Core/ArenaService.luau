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

local CurrentGameState = require(ReplicatedStorage.Shared.Referential.CurrentGameState)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

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
local arenaFolder = game.Workspace.Arena

local registeredMaps: {
   [string]: Model
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ArenaService.MapChangedTasks = TasksList.new() :: TasksList.TasksList<MapChangedTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function sendPlayerToSpawnPosition(player: Player, position: Vector3)
   local fromPosition = position + Vector3.new(0, 3, 0)
   local raycastParams = RaycastParams.new()
   raycastParams.CollisionGroup = CollisionGroupConstants.Players
   raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
   raycastParams.FilterDescendantsInstances = {player.Character}
   local raycastResult = workspace:Raycast(fromPosition, Vector3.new(0, -100, 0), raycastParams)
   if raycastResult then
      local groundPosition = raycastResult.Position
      local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
      if humanoid then
         local hipHeight = humanoid.HipHeight
         player.Character:PivotTo(CFrame.new(groundPosition + Vector3.new(0, hipHeight, 0)))
      end
    end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

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

function ArenaService.getSpawnPoint(player: Player): SpawnLocation
   --error(`huh?`)
   local currentArenaModel = arenaFolder:FindFirstChildWhichIsA("Model")
   if not currentArenaModel then
      return nil
   end
   local spawnPointsFolder = currentArenaModel:FindFirstChild("SpawnPoints")
   if not spawnPointsFolder then
      return nil
   end
   local spawnPoints = spawnPointsFolder:GetChildren()

   -- Chosoe a spawn point that is not occupied by enemies
   local MIN_DISTANCE = 75
   local validSpawns = {}
   for _, spawn in ipairs(spawnPoints) do
      local valid = true
      for _, otherPlayer in ipairs(Players:GetPlayers()) do
         -- TODO: only consider team if teams are being used for enemy determination
         if otherPlayer.Team ~= player.Team then
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
         table.insert(validSpawns, spawn)
      end
   end
   if #validSpawns > 0 then
      return validSpawns[math.random(#validSpawns)]
   else
      return spawnPoints[math.random(#spawnPoints)]
   end
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
   if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
      warn(`player has no character or hrp to send to arena: {player}`)
      return
   end
   
   local currentArenaModel = arenaFolder:FindFirstChildWhichIsA("Model")
   if not currentArenaModel then
      warn(`No current arena model found to send player to: {player}`)
      return
   end

   -- Choose a spawn point that is not occupied by enemies
   local MIN_DISTANCE = 75
   local spawnPoints = currentArenaModel:FindFirstChild("SpawnPoints"):GetChildren()
   local validSpawns = {}
   local chosenSpawn = nil
   for _, spawn in ipairs(spawnPoints) do
      local valid = true
      for _, otherPlayer in ipairs(Players:GetPlayers()) do
         if otherPlayer ~= player and otherPlayer.Team ~= player.Team then
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
         table.insert(validSpawns, spawn)
      end
   end
   if #validSpawns > 0 then
      chosenSpawn = validSpawns[math.random(#validSpawns)]
   else
      chosenSpawn = spawnPoints[math.random(#spawnPoints)]
   end
   if chosenSpawn then
      sendPlayerToSpawnPosition(player, chosenSpawn.Position)
   end
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

   -- Teleport players to arena
   -- For each player, prioritize a random selection from unused spawn points; if none exist, prioritize random selection of least-used spawn points
   local livingPlayersInArena = CurrentGameState.LivingPlayersInArena:Get()
   local spawnPoints = liveMap:FindFirstChild("SpawnPoints"):GetChildren()
   local spawnPointUsage: {[Part]: number} = {}
   for _, spawnPoint in pairs(spawnPoints) do
      spawnPointUsage[spawnPoint] = 0
   end
   for _, player in pairs(game.Players:GetPlayers()) do
      if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
         local candidateSpawnPoints = {}
         local minUsage = math.huge
         for _, spawnPoint in pairs(spawnPoints) do
            local usage = spawnPointUsage[spawnPoint]
            if usage < minUsage then
               minUsage = usage
               candidateSpawnPoints = {spawnPoint}
            elseif usage == minUsage then
               table.insert(candidateSpawnPoints, spawnPoint)
            end
         end
         local chosenSpawnPoint = candidateSpawnPoints[math.random(1, #candidateSpawnPoints)]
         spawnPointUsage[chosenSpawnPoint] = spawnPointUsage[chosenSpawnPoint] + 1
         sendPlayerToSpawnPosition(player, chosenSpawnPoint.Position)

         if not table.find(livingPlayersInArena, player) then
            table.insert(livingPlayersInArena, player)
            CurrentGameState.LivingPlayersInArena:SilentSet(livingPlayersInArena)
         end
      end
   end

   ArenaService.MapChangedTasks:Execute("parallel")
   CurrentGameState.LivingPlayersInArena:Set(livingPlayersInArena)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ArenaService.init()
   -- Register maps
	for _, c in pairs(mapFolder:GetChildren()) do
      if not c:IsA("Model") then
         warn(`nonaccepted child in map folder: {c.Name}`)
         continue
      end

      local walls = c:FindFirstChild("Walls")
      if walls then
         for _, wall in pairs(walls:GetDescendants()) do
            if (wall:IsA("MeshPart") or wall:IsA("BasePart")) and wall.CanCollide then
               wall.CollisionGroup = CollisionGroupConstants.ArenaObstructions
            end
         end
      else
         warn(`map {c.Name} is missing Walls folder`)
      end

      registeredMaps[c.Name] = c
	end
end

function ArenaService.start()
   
end

function ArenaService.test()

end

return ArenaService
