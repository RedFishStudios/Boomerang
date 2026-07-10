--[[
  - Manages the game lobby

  TODO:
  - What other stuff does a lobby have? score boards, donation boards, etc...

  Author:
  @Soulsplosion
]]

local LobbyService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SharedConstants = ReplicatedStorage.Shared.Constants

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local lobbyFolder = game.Workspace.Lobby
local lobbySpawnPoint = lobbyFolder.LobbySpawnLocation

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function LobbyService.getSpawnPoint()
   return lobbySpawnPoint
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LobbyService.init()
	
end

-- function LobbyService.start() end

-- function LobbyService.test() end

return LobbyService