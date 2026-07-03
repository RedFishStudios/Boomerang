--[[
  Handles player team assignment

  TODO:
  - When a player joins, if currently in a team-based match, assign to the team with the least players

  Author:
  @Soulsplosion
]]

local GameTeamService = {}

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

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GameTeamService.init()
	PlayersUtil.onPlayerAdded(function(player: Player)
      
	end)
end

function GameTeamService.start()

end

function GameTeamService.test()

end

return GameTeamService