--[[
  Relays round-related functionality and utilities for the client

  Author:
  @Soulsplosion
]]

local RoundService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedConstants = ReplicatedStorage.Shared.Constants

local RoundTypes = require(SharedConstants.RoundTypes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isInRound = true
local currentRoundTypeId: string? = nil

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
   return isInRound
end

function RoundService.getCurrentRoundTypeId(): string?
   return currentRoundTypeId
end

-- // Returns true if current round permits late joining for the given player
function RoundService.canSpawnIntoRound(player: Player): boolean
   if not isInRound or not currentRoundTypeId then
      return false
   end
   local roundType = RoundTypes[currentRoundTypeId]
   return roundType.CanLateJoin
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RoundService.init()
	
end

-- function RoundService.start() end

-- function RoundService.test() end

return RoundService