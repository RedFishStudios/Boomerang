--[[
  CollisionService

  Description:
  Service responsible for handling collision groups

  Author:
  @SixthAtom

  Date:
  23-03-2026
]]

local CollisionService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)

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

local function loadCollisionGroups()
	-- Collision groups and relations are initialized when CollisionGroupConstants is required.
	local _ = CollisionGroupConstants
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CollisionService.init()
	loadCollisionGroups()
end

function CollisionService.start() end

function CollisionService.test() end

return CollisionService
