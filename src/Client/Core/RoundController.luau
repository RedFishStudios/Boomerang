--[[
  Relays round-related functionality and utilities for the client

  Author:
  @Soulsplosion
]]

local RoundController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local GamemodeLogicsFolder = ReplicatedStorage.Shared.Logics.GamemodeLogics
local GamemodeLogics: {[string]: any} = {}

local lastRoundGamemode: string? = nil

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(gamemode: string): any
  if GamemodeLogics[gamemode] then
    return GamemodeLogics[gamemode]
  end

  local logicModule = GamemodeLogicsFolder:FindFirstChild(gamemode)
  if logicModule then
    local logic = require(logicModule)
    GamemodeLogics[gamemode] = logic
    return logic
  end

  return nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function RoundController.isInRound(): boolean
  return GameStateLibrary.getGameStateData().CurrentRoundData:Get() ~= nil
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RoundController.init()
   local gameStateData = GameStateLibrary.getGameStateData()

   gameStateData.CurrentRoundData:Subscribe(function(roundData)
      print(roundData)
      if roundData then
         -- Round has started
         local newGamemode = roundData.Gamemode
         local logic = getLogic(newGamemode)
         if logic and logic.setup then
            logic.setup(roundData)
         end
         lastRoundGamemode = newGamemode
      else
         -- Round has ended
         if lastRoundGamemode then
            local logic = getLogic(lastRoundGamemode)
            if logic and logic.teardown then
               logic.teardown()
            end
         end
      end
   end)
end

-- function RoundController.start() end

-- function RoundController.test() end

return RoundController
