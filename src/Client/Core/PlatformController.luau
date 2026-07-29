local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TasksList = require(game.ReplicatedStorage.Shared.Classes.TasksList)

local PlatformController = {}

PlatformController.NewInputGadget = TasksList.new() :: TasksList.TasksList<(newGadget: Gadget)->()>

export type Gadget = "Mouse" | "Keyboard" | "Console" | "Touchscreen"

local Workspace = game.Workspace

local InputsToGadget: {[Enum.UserInputType]: Gadget} = {
	[Enum.UserInputType.Touch] = "Touchscreen",
	[Enum.UserInputType.MouseMovement] = "Mouse",
	[Enum.UserInputType.Keyboard] = "Keyboard",
	[Enum.UserInputType.Gamepad1] = "Console",
	[Enum.UserInputType.Gamepad2] = "Console",
	[Enum.UserInputType.Gamepad3] = "Console",
	[Enum.UserInputType.Gamepad4] = "Console"
}

local GadgetsUsed: {
	[Gadget]: number? -- os.clock() representing the last time this gadget was detected as being used
} = {
	Mouse = nil,
	Keyboard = nil,
	Console = nil,
	Touchscreen = nil
}

-- Keyboard/Mouse devices are treated as the same control scheme when it comes to displaying keybinds
local dominantControlScheme: "PC" | "Console" | "Touch" | nil = nil

-- Last position of touch or mouse movement which was not obstructed by a gui
local lastValidMousePositionInWorld: Vector3? = nil

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public

function PlatformController.getDominantControlScheme(): "PC" | "Console" | "Touch"
	return dominantControlScheme
end

-- https://create.roblox.com/docs/reference/engine/enums/KeyCode
function PlatformController.matchKeycodeToGadget(keycode: Enum.KeyCode): Gadget?
	if keycode == Enum.KeyCode.Unknown then
		return nil
	elseif keycode.Value >= Enum.KeyCode.ButtonA.Value and keycode.Value <= Enum.KeyCode.Thumbstick2Right.Value then
		return "Console"
	elseif keycode.Value >= Enum.KeyCode.MouseLeftButton.Value and keycode.Value <= Enum.KeyCode.MouseMiddleButton.Value then
		return "Mouse"
	else
		return "Keyboard"
	end
end

function PlatformController.getLastInputGadget(): Gadget?
	local inputType = UserInputService:GetLastInputType()
	if InputsToGadget[inputType] then
		return InputsToGadget[inputType]
	end
	return nil
end

function PlatformController.used(gadget: Gadget): number?
	return GadgetsUsed[gadget]
end

function PlatformController.getLastMousePositionInWorld(): Vector3?
	return lastValidMousePositionInWorld
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Init

local function _init()
	if UserInputService.TouchEnabled then
		dominantControlScheme = "Touch"
		GadgetsUsed["Touchscreen" :: Gadget] = os.clock()
	elseif GuiService:IsTenFootInterface() then
		dominantControlScheme = "Console"
	else
		dominantControlScheme = "PC"
	end

	local function registerDetectedInputObject(input: InputObject, gameProcessedEvent: boolean)
		local inputType = input.UserInputType
		if InputsToGadget[inputType] then
			GadgetsUsed[InputsToGadget[inputType]] = os.clock()
		end

		local gadget = PlatformController.getLastInputGadget()
		local newScheme = nil
		if gadget == "Console" then
			newScheme = "Console"
		elseif gadget == "Touchscreen" then
			newScheme = "Touch"
		else
			newScheme = "PC"
		end

		if newScheme ~= dominantControlScheme then
			dominantControlScheme = newScheme
			PlatformController.NewInputGadget:Execute("serial", newScheme)
		end

      if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
         local position = input.Position
         if not gameProcessedEvent then
             lastValidMousePositionInWorld = position
         end
      end
	end

	UserInputService.InputBegan:Connect(registerDetectedInputObject)
	UserInputService.InputChanged:Connect(registerDetectedInputObject)

	if UserInputService.TouchEnabled then
		GadgetsUsed["Touchscreen" :: Gadget] = os.clock()
	end
end
_init()

return PlatformController