--[[
  Manages where players should spawn

  Author:
  @Soulsplosion
]]

local SpawnService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CurrentGameState = require(ReplicatedStorage.Shared.Referential.CurrentGameState)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

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
   if CurrentGameState.IsInRound and CurrentGameState.CanRespawn then
      player.RespawnLocation = ArenaService.getSpawnPoint(player)
   else
      player.RespawnLocation = LobbyService.getSpawnPoint()
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

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