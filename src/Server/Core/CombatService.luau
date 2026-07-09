-- // Handles behavior of thrown weapons

--[[
  Handles equipping/unequipping of tools to the character
  - Boomerangs, shuricans, fans, special weapons, etc
]]

local CombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
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

CombatService.PlayerKilledPlayerTasks = TasksList.new() :: TasksList.TasksList<(killer: Player, victim: Player, weaponId: string) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character then
		return character:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CombatService.damagePlayer(attacker: Player?, attackerToolId: string?, victim: Player, victimHumanoid: Humanoid?, damageAmount: number)
   local humanoid = victimHumanoid or getHumanoid(victim)
   if not humanoid then
      return
   end
   humanoid:TakeDamage(damageAmount)
   if attacker and attackerToolId then
      CombatService.PlayerKilledPlayerTasks:Execute("parallel", attacker, victim, attackerToolId)
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CombatService.init()
end

function CombatService.start() end

function CombatService.test() end

return CombatService