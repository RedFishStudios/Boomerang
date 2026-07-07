-- // TEST: Fires throw remote when player presses E

local WeaponController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

local ToolLogics = ReplicatedStorage.Shared.Logics.WeaponLogics
local ToolLogicModules = {}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local throwEvent = SimpleRemotes.getEvent("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(toolId: string)
	if not ToolLogicModules[toolId] then
		local module = require(ToolLogics:WaitForChild(toolId))
		ToolLogicModules[toolId] = module
	end
	return ToolLogicModules[toolId]
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function WeaponController.startThrownWeapon(_player: Player, toolId: string, toolData: Tools.Tool)
   ThrownWeapons.Data[_player] = {
         ToolId = toolId,
         State = ThrownWeapons.StateEnum.Outgoing,
         ReplicationPart = nil,
         TestRaycastVisualizers = {}
      }
      for i = 1, 3 do
         local part = Instance.new("Part")
         part.Size = Vector3.new(1, 1, 1)
         part.Anchored = true
         part.CanTouch = false
         part.CanQuery = false
         part.CanCollide = false
         part.Parent = workspace
         ThrownWeapons.Data[_player].TestRaycastVisualizers[i] = part
      end

      local Logic = getLogic(toolData.LogicClass)
      Logic.throw(_player, toolId, toolData, ThrownWeapons.Data[_player])

   local logic = getLogic("Boomerang")
   logic.throw()
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function WeaponController.init()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			throwEvent:FireServer("ClassicBoomerang")
         WeaponController.startThrownWeapon(game.Players.LocalPlayer, "ClassicBoomerang", Tools["ClassicBoomerang"]) -- PLACEHOLDER IMMEDIATE REPLICATION
		end

		if input.KeyCode == Enum.KeyCode.F then
			recallEvent:FireServer()
		end
	end)
end

function WeaponController.start() end

return WeaponController
