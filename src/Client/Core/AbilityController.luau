local AbilityController = {}

local UserInputService = game:GetService("UserInputService")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightingService = game:GetService("Lighting")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

local localPlayer = Players.LocalPlayer

local AbilityLogics = ReplicatedStorage.Shared.Logics.AbilityLogics
local AbilityLogicModules = {}

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

function AbilityController.activate(abilityId: string, ...)
   local logic = getLogic(abilityId)
   if not logic then
      warn(`AbilityController: No logic found for ability {abilityId}`)
      return
   end
   if logic.canActivate and not logic.canActivate(localPlayer) then
      warn(`AbilityController: Player {localPlayer.Name} cannot activate ability {abilityId}`)
      return
   end
	abilityUsed:FireServer(abilityId)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AbilityController.init()
   UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

      if input.KeyCode == Enum.KeyCode.Space then
         AbilityController.activate("Dash")
		end
	end)
end

-- function AbilityController.start() end

-- function AbilityController.test() end

return AbilityController