local AbilityService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityLogics = ReplicatedStorage.Shared.Logics.AbilityLogics
local AbilityLogicModules = {}

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local abilityUsed = SimpleRemotes.getEvent("AbilityUsed")
local abilityStopped = SimpleRemotes.getEvent("AbilityStopped")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(abilityId: string)
	if not AbilityLogicModules[abilityId] then
      local _module = AbilityLogics:WaitForChild(abilityId, 5)
      if not _module then
         warn(`AbilityService.getLogic: Ability logic module {abilityId} not found`)
         return
      end
		local module = require(_module)
		AbilityLogicModules[abilityId] = module
	end
	return AbilityLogicModules[abilityId]
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AbilityService.init()
   SimpleRemotes.getUnreliableEvent("AbilityReplication")

   abilityUsed.OnServerEvent:Connect(function(player: Player, abilityId: string, ...)
      local logic = getLogic(abilityId)
      if not logic then
         warn(`AbilityService.init: No logic found for ability {abilityId}`)
         return
      end
      if logic.canActivate and not logic.canActivate(player, ...) then
         warn(`AbilityService.init: Player {player.Name} cannot activate ability {abilityId}`)
         return
      end
      if logic.activate then
         logic.activate(player, ...)
      end
   end)
end

-- function AbilityService.start() end

-- function AbilityService.test() end

return AbilityService