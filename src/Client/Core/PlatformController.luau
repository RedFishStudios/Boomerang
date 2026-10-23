local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TasksList = require(game.ReplicatedStorage.Shared.Classes.TasksList)

local PlatformController = {}

PlatformController.NewInputGadget = TasksList.new() :: TasksList.TasksList<(newGadget: Gadget)->()>
PlatformController.DominantControlSchemeChanged = TasksList.new() :: TasksList.TasksList<(newScheme: "PC" | "Console" | "Touch")->()>

export type Gadget = "Mouse" | "Keyboard" | "Console" | "Touchscreen"

local Workspace = game.Workspace

local InputsToGadget: {[Enum.UserInputType]: Gadget} = {
	[Enum.UserInputType.Touch] = "Touchscreen",
	[Enum.UserInputType.MouseMovement] = "Mouse",
	[Enum.UserInputType.MouseButton1] = "Mouse",
	[Enum.UserInputType.MouseButton2] = "Mouse",
	[Enum.UserInputType.MouseButton3] = "Mouse",
	[Enum.UserInputType.MouseWheel] = "Mouse",
	[Enum.UserInputType.Keyboard] = "Keyboard",
	[Enum.UserInputType.Gamepad1] = "Console",
	[Enum.UserInputType.Gamepad2] = "Console",
	[Enum.UserInputType.Gamepad3] = "Console",
	[Enum.UserInputType.Gamepad4] = "Console",
	[Enum.UserInputType.Gamepad5] = "Console",
	[Enum.UserInputType.Gamepad6] = "Console",
	[Enum.UserInputType.Gamepad7] = "Console",
	[Enum.UserInputType.Gamepad8] = "Console",
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

-- // T-116: on a laptop with a touchscreen (and on some tablets), the OS turns every touch into mouse input as well: a touch is
-- // followed right away by mouse movement / clicks at the same spot. Without this, the scheme switched to Touch and straight back
-- // to PC, so the touch controls never stayed visible. Mouse input this soon after a touch is treated as part of that touch.
local MOUSE_AFTER_TOUCH_IGNORE_SECONDS = 0.6

-- // TEMPORARY DEBUG (T-116, touchscreen laptop): prints the input the client sees, prefixed [TOUCHDBG]. Remove once solved.
local TOUCH_DEBUG = true
local function touchDebug(message: string)
	if TOUCH_DEBUG then
		print(`[TOUCHDBG] {message}`)
	end
end

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

-- // Keyboard and mouse both count as the "PC" scheme
local function gadgetToScheme(gadget: Gadget): "PC" | "Console" | "Touch"
	if gadget == "Console" then
		return "Console"
	elseif gadget == "Touchscreen" then
		return "Touch"
	end
	return "PC"
end

local function getInitialControlScheme(): "PC" | "Console" | "Touch"
	local gadget = PlatformController.getLastInputGadget()
	if gadget then
		return gadgetToScheme(gadget)
	end

	-- // No input yet: fall back to the device's preferred input
	local preferredInput = UserInputService.PreferredInput
	if preferredInput == Enum.PreferredInput.Touch then
		return "Touch"
	elseif preferredInput == Enum.PreferredInput.Gamepad or GuiService:IsTenFootInterface() then
		return "Console"
	elseif preferredInput == Enum.PreferredInput.KeyboardAndMouse then
		return "PC"
	end
	return if UserInputService.TouchEnabled then "Touch" else "PC"
end

local function setControlScheme(newScheme: "PC" | "Console" | "Touch")
	if newScheme == dominantControlScheme then
		return
	end
	touchDebug(`control scheme {tostring(dominantControlScheme)} -> {newScheme}`)
	dominantControlScheme = newScheme
	PlatformController.NewInputGadget:Execute("serial", newScheme)
	PlatformController.DominantControlSchemeChanged:Execute("serial", newScheme)
end

local function _init()
	dominantControlScheme = getInitialControlScheme()
	if dominantControlScheme == "Touch" then
		GadgetsUsed["Touchscreen" :: Gadget] = os.clock()
	end

	local function registerDetectedInputObject(input: InputObject, gameProcessedEvent: boolean)
		local inputType = input.UserInputType
		-- // TEMPORARY DEBUG: every input except plain mouse movement (too many), with the state it is in
		if TOUCH_DEBUG and inputType ~= Enum.UserInputType.MouseMovement then
			touchDebug(`input {inputType.Name} {input.UserInputState.Name} key={input.KeyCode.Name} gameProcessed={tostring(gameProcessedEvent)} scheme={tostring(dominantControlScheme)}`)
		end

		-- // Only real device input switches the scheme (not Focus, TextInput, etc.)
		local gadget = InputsToGadget[inputType]
		if not gadget then
			return
		end
		local now = os.clock()
		-- // T-116: mouse events the OS makes from a touch (see MOUSE_AFTER_TOUCH_IGNORE_SECONDS) neither count as mouse use nor
		-- // switch the controls back to PC; they extend the touch instead
		local lastTouchAt = GadgetsUsed["Touchscreen" :: Gadget]
		local isMouseFromTouch = gadget == "Mouse" and lastTouchAt ~= nil and now - lastTouchAt < MOUSE_AFTER_TOUCH_IGNORE_SECONDS
		if isMouseFromTouch then
			touchDebug(`mouse input {inputType.Name} treated as part of a touch`)
			GadgetsUsed["Touchscreen" :: Gadget] = now
		else
			GadgetsUsed[gadget] = now
		end

		-- // Typing into a TextBox (e.g. the on-screen keyboard in chat) shouldn't hide the touch controls
		local isTyping = gadget == "Keyboard" and (gameProcessedEvent or UserInputService:GetFocusedTextBox() ~= nil)
		if not isTyping and not isMouseFromTouch then
			setControlScheme(gadgetToScheme(gadget))
		end

		if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
			local position = input.Position
			if not gameProcessedEvent then
				lastValidMousePositionInWorld = position + Vector3.new(0, 60, 0) -- offset to account for topbar
			end
		end
	end

	UserInputService.InputBegan:Connect(registerDetectedInputObject)
	UserInputService.InputChanged:Connect(registerDetectedInputObject)

	-- // TEMPORARY DEBUG: what the device reports, and the touch-specific signals (fire even if touches don't come through InputBegan)
	touchDebug(`device: TouchEnabled={tostring(UserInputService.TouchEnabled)} KeyboardEnabled={tostring(UserInputService.KeyboardEnabled)} MouseEnabled={tostring(UserInputService.MouseEnabled)} GamepadEnabled={tostring(UserInputService.GamepadEnabled)} PreferredInput={UserInputService.PreferredInput.Name} LastInputType={UserInputService:GetLastInputType().Name} initialScheme={tostring(dominantControlScheme)}`)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		touchDebug(`PreferredInput -> {UserInputService.PreferredInput.Name}`)
	end)
	UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
		if lastInputType ~= Enum.UserInputType.MouseMovement then
			touchDebug(`LastInputType -> {lastInputType.Name}`)
		end
	end)
	UserInputService.TouchStarted:Connect(function(_touch, gameProcessedEvent)
		touchDebug(`TouchStarted gameProcessed={tostring(gameProcessedEvent)}`)
	end)
	UserInputService.TouchTap:Connect(function()
		touchDebug("TouchTap")
	end)
end
_init()

return PlatformController