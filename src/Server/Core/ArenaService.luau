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

local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local GameTeamService = require(game.ServerStorage.Server.Core.GameTeamService)

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
      if not player.Character then
         warn(`player character never loaded to send to arena: {player}`)
         return
      end
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
local gameStateData = CurrentGameState.getGameStateData()
   local forRoundId = gameStateData.CurrentRoundId:Get()

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
      if gameStateData.CurrentRoundId:Get() ~= forRoundId then
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
      if gameStateData.CurrentRoundId:Get() ~= forRoundId then
         warn(`arenaservice.sendtoarena: round changed while awaiting player primary part: {player}`)
         return
      end
   end

   if not gameStateData.IsInRound:Get() then
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
         if otherPlayer.Team ~= player.Team or (player.Team and GameTeamService.hasFriendlyFire(player.Team)) then
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
   local chosenSpawn = ArenaService.getSpawnPoint(player)
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

   local livingPlayersInArena = {}

   -- Send all players to a different spawnpoint
   local consumedSpawnPoints: {
      [Part]: {Player}
   } = {}
   local spawnPoints = liveMap:FindFirstChild("SpawnPoints"):GetChildren()

   for _, player in ipairs(game.Players:GetPlayers()) do
      table.insert(livingPlayersInArena, player)

      local availableSpawnPoints = {}

      -- Find spawn points that haven't been consumed yet
      for _, spawnPoint in ipairs(spawnPoints) do
         if not consumedSpawnPoints[spawnPoint] then
            table.insert(availableSpawnPoints, spawnPoint)
         end
      end

      -- Send to an unused spawn point if one is available
      local spawnPoint
      if #availableSpawnPoints > 0 then
         spawnPoint = availableSpawnPoints[math.random(#availableSpawnPoints)]
         consumedSpawnPoints[spawnPoint] = { player }
      else
         spawnPoint = spawnPoints[math.random(#spawnPoints)]
         table.insert(consumedSpawnPoints[spawnPoint], player)
      end
   end

   for spawnPoint, players in pairs(consumedSpawnPoints) do
      for _, player in ipairs(players) do
         print(player, spawnPoint.Position)
         sendPlayerToSpawnPosition(player, spawnPoint.Position)
      end
   end

   ArenaService.MapChangedTasks:Execute("parallel")
   CurrentGameState.applyValues({
      LivingPlayersInArena = livingPlayersInArena,
   })
end

function ArenaService.getAllMapModels()
   return mapFolder:GetChildren()
end

function ArenaService.getArenaModel(): Model?
   return arenaFolder:FindFirstChildWhichIsA("Model")
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
               wall.CollisionGroup = CollisionGroupConstants.ArenaWalls
            end
         end
      else
         warn(`map {c.Name} is missing Walls folder`)
      end

      local spawnpoints = c:FindFirstChild("SpawnPoints")
      if not spawnpoints then
         warn(`map {c.Name} is missing SpawnPoints folder`)
      end
      for _, c in pairs(spawnpoints:GetChildren()) do
         if c:IsA("SpawnLocation") then
            c.Duration = GlobalConfig.SpawnShieldDuration
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
