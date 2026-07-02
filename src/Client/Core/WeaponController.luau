-- // TEST: Fires throw remote when player presses E

local WeaponController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local throwEvent = SimpleRemotes.getEvent("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")

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
		end

		if input.KeyCode == Enum.KeyCode.F then
			recallEvent:FireServer()
		end
	end)
end

function WeaponController.start() end

return WeaponController
