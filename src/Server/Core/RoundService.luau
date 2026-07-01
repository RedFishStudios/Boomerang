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

local isInRound = false
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

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RoundService.init()
	
end

-- function RoundService.start() end

-- function RoundService.test() end

return RoundService