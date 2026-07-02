--[[
  Relays round-related functionality and utilities for the client

  Author:
  @Soulsplosion
]]

local RoundService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SharedConstants = ReplicatedStorage.Shared.Constants

local RoundTypes = require(SharedConstants.RoundTypes)
local CurrentGameState = require(ServerStorage.Server.Referential.CurrentGameState)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function RoundService.isInRound(): boolean
   return CurrentGameState.IsInRound
end

function RoundService.getCurrentRoundTypeId(): string?
   return CurrentGameState.RoundTypeId
end

-- // Returns true if current round permits late joining for the given player
function RoundService.canSpawnIntoRound(player: Player): boolean
   if not CurrentGameState.IsInRound or not CurrentGameState.RoundTypeId then
      return false
   end
   return CurrentGameState.CanRespawn
end

function RoundService.setNextRound(roundTypeId: string, mapName: string)
   local roundType = RoundTypes[roundTypeId]
   CurrentGameState.RoundTypeId = roundTypeId
   CurrentGameState.CurrentMapName = mapName
   CurrentGameState.RemainingTime = roundType.TimeLasts
   CurrentGameState.IsInRound = true
   CurrentGameState.CanRespawn = roundType.CanRespawn
   ArenaService.setArena(mapName)
   -- TODO: update all clients (time remaining, round name they can display on screen, etc)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RoundService.init()
	task.spawn(function()
      task.wait(2)
      RoundService.setNextRound("Classic", "GenericA")
	end)
end

-- function RoundService.start() end

-- function RoundService.test() end

return RoundService