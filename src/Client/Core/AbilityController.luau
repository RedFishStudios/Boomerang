local AbilityController = {}

local UserInputService = game:GetService("UserInputService")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local abilityReplication = SimpleRemotes.getUnreliableEvent("AbilityReplication")

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

abilityReplication.OnClientEvent:Connect(function(abilityId: string, userId: number, timestamp: number)
   if userId == localPlayer.UserId or typeof(timestamp) ~= "number" then
      return
   end

   local logic = getLogic(abilityId)
   if not logic or not logic.simulateActivation then
      return
   end

   logic.simulateActivation(userId, timestamp)
end)

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
   logic.activate(localPlayer, ...)
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

      if input.UserInputType == Enum.UserInputType.MouseButton1 then
         AbilityController.activate("Stab")
      end
	end)
end

-- function AbilityController.start() end

-- function AbilityController.test() end

return AbilityController