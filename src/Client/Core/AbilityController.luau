local AbilityController = {}

local UserInputService = game:GetService("UserInputService")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local LobbyController = require(ReplicatedStorage.Client.Core.LobbyController)

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
local abilityReplication = SimpleRemotes.getEvent("AbilityReplication") -- // Reliable, so no ability use is lost

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
   if not logic or not logic.onPickup then
      return
   end

   logic.onPickup(userId, timestamp)
end)

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function AbilityController.activate(abilityId: string, ...)
   local logic = getLogic(abilityId)
   if not logic or not logic.onPickup then
      return
   end
   if logic.canActivate and not logic.canActivate(localPlayer, ...) then
      return
   end
   local params = nil
   if logic.getParams then
      params = logic.getParams()
   end
   logic.onPickup(localPlayer.UserId, game.Workspace:GetServerTimeNow(), params)
   SharedTasks.PlayerUsedAbility:Execute("parallel", localPlayer, abilityId)
	abilityUsed:FireServer(abilityId, params)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

-- // Jump/dash input: jumps in the lobby, dashes in the arena.
-- // In the arena, Space and gamepad already press the replicated jump input; on-screen buttons use Dash.pressInput.
function AbilityController.useMovementInput()
   if LobbyController.isInLobby() then
      local character = localPlayer.Character
      local humanoid = character and character:FindFirstChildOfClass("Humanoid")
      if humanoid then
         humanoid.Jump = true
      end
      return
   end
   local dash = getLogic("Dash")
   if dash and dash.pressInput then
      dash.pressInput()
   end
end

function AbilityController.init()
   -- // Dash runs inside the simulation, so load it before first use
   task.spawn(getLogic, "Dash")

   UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

      -- // In the arena Space presses the jump input itself; only the lobby needs handling here
      if input.KeyCode == Enum.KeyCode.Space and LobbyController.isInLobby() then
         AbilityController.useMovementInput()
		end

      if input.UserInputType == Enum.UserInputType.MouseButton1 then
         AbilityController.activate("Stab")
      end
	end)
end

-- function AbilityController.start() end

-- function AbilityController.test() end

return AbilityController