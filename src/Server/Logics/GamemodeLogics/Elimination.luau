-- // Test game mode: First player to throw boomerang 3 times wins

local EliminationRoundLogic = {} 

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)
local WeaponService = require(ServerStorage.Server.Core.WeaponService)
local StormCloseSystem = require(ServerStorage.Server.Core.StormCloseSystem)

local CurrentGameState = require(ReplicatedStorage.Shared.Referential.CurrentGameState)

local PerMatchDestroyerFunctions: {()->()} = {}

local function clear()
end

function EliminationRoundLogic.setup()
   clear()
   GameTeamService.setFreeForAll()
   local arenaPosition = ArenaService.getCurrentArenaPosition() or Vector3.new(0, 0, 0)
   StormCloseSystem.begin(arenaPosition)
end

function EliminationRoundLogic.teardown()
   clear()
end

return EliminationRoundLogic