-- // Manages live player stats within the game
--    Health, stamina, etc

local PlayerStatService = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

type PlayerStats = {
   Health: number,
   Speed: number -- TODO: incorporate with "Caffeinated" pickup
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local PlayerLiveStats: {[Player]: PlayerStats} = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PlayerStatService.init()
   
end

function PlayerStatService.start()
end

function PlayerStatService.test()
end

return PlayerStatService
