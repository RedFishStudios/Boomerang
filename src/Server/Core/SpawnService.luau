--[[
  Manages where players should spawn

  Author:
  @Soulsplosion
]]

local SpawnService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)

local LobbyService = require(ServerStorage.Server.Core.LobbyService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type PlayerDiedEventTask = (player: Player) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SpawnService.PlayerDiedTasks = TasksList.new() :: TasksList.TasksList<PlayerDiedEventTask>
SpawnService.PlayerSpawnedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, inArena: boolean)->()>

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

local function safeGetHumanoid(character)
   return character:WaitForChild("Humanoid", 5)
end

local function setPlayerSpawnpoint(player: Player)
   local gameStateData = CurrentGameState.getGameStateData()
   if gameStateData.IsInRound:Get() and gameStateData.CanRespawn:Get() then
      player.RespawnLocation = ArenaService.getSpawnPoint(player)
   else
      player.RespawnLocation = LobbyService.getSpawnPoint()
      GameTeamService.setOutOfGame(player)
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

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
	PlayersUtil.onPlayerAdded(function(player: Player)
      setPlayerSpawnpoint(player)

      player.CharacterAdded:Connect(function()
         SpawnService.PlayerSpawnedTasks:Execute("parallel", player, if player.RespawnLocation then player.RespawnLocation:IsDescendantOf(game.Workspace.Arena) else false)
         local humanoid = safeGetHumanoid(safeGetPlayerCharacter(player))
         if humanoid then
            humanoid.Died:Connect(function()
               setPlayerSpawnpoint(player)
               SpawnService.PlayerDiedTasks:Execute("parallel", player)
               -- TODO: display death screen, respawn time, etc
            end)
         end
      end)
	end)
end

function SpawnService.start()

end

function SpawnService.test()

end

return SpawnService