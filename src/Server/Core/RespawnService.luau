--[[
  Relays round-related functionality and utilities for the client

  Author:
  @Soulsplosion
]]

local RespawnService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SharedConstants = ReplicatedStorage.Shared.Constants

local RoundTypes = require(SharedConstants.RoundTypes)
local CurrentGameState = require(ServerStorage.Server.Referential.CurrentGameState)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

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

RespawnService.PlayerDiedTasks = TasksList.new() :: TasksList.TasksList<PlayerDiedEventTask>

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

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RespawnService.init()
	PlayersUtil.onPlayerAdded(function(player: Player)
      player.CharacterAdded:Connect(function()
         local character = safeGetPlayerCharacter(player)
         if not character then
            return
         end
         local humanoid = safeGetHumanoid(character)
         if not humanoid then
            return
         end

         -- Send to round arena or respawn location
         if CurrentGameState.IsInRound and CurrentGameState.CanRespawn then
            ArenaService.sendToArena(player)
         else
            -- TODO: send to lobby
         end

         -- Death connection
         humanoid.Died:Connect(function()
            RespawnService.PlayerDiedTasks:Execute("parallel", player)
            -- TODO: display death screen, respawn time, etc
         end)
      end)
	end)
end

function RespawnService.start()

end

function RespawnService.test()

end

return RespawnService