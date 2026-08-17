--[[
  Relays round-related functionality and utilities for the client

  Author:
  @Soulsplosion
]]

local RoundController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

function RoundController.isInRound(): boolean
  return CurrentGameState.getGameStateData().CurrentRoundData:Get() ~= nil
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RoundController.init()
	
end

-- function RoundController.start() end

-- function RoundController.test() end

return RoundController
