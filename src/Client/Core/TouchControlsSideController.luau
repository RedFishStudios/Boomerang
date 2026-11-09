--[[
	TouchControlsSideController

	Description:
	Left-handed touch layout (Settings: Touch Controls): moves Roblox's touch controls (the PlayerModule's movement
	thumbstick area and jump button, in PlayerGui.TouchGui.TouchControlFrame) to the opposite side so they don't overlap
	the game's aim thumbstick and buttons, which move left (CustomTouchscreen).

	Relies on Roblox's TouchGui layout (frame names, thumbstick reading its frame's on-screen area). Roblox re-lays these
	frames out (e.g. on screen resize), so they're mirrored again whenever they move.
]]

local TouchControlsSideController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsController = require(ReplicatedStorage.Client.Core.SettingsController)
local GuiMirror = require(ReplicatedStorage.Client.UI.GuiMirror)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Roblox's touch control frames on one side of the screen. Excludes the Classic thumbstick's "ThumbstickFrame",
-- // which follows the finger and can't be mirrored this way.
local MIRRORED_FRAME_NAMES = {
	DynamicThumbstickFrame = true,
	JumpButton = true,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local watched: { [GuiObject]: RBXScriptConnection } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isLeftHanded(): boolean
	return SettingsController.getValue("LeftHandedTouch") == true
end

local function watch(frame: GuiObject)
	if watched[frame] then
		return
	end
	-- // Roblox moved it (re-layout): mirror again from its new place
	watched[frame] = frame:GetPropertyChangedSignal("Position"):Connect(function()
		if isLeftHanded() and not GuiMirror.isMirrored(frame) then
			GuiMirror.setMirrored(frame, true)
		end
	end)
	frame.Destroying:Once(function()
		local connection = watched[frame]
		if connection then
			connection:Disconnect()
		end
		watched[frame] = nil
	end)
	GuiMirror.setMirrored(frame, isLeftHanded())
end

local function onDescendantAdded(descendant: Instance)
	if descendant:IsA("GuiObject") and MIRRORED_FRAME_NAMES[descendant.Name] then
		watch(descendant)
	end
end

local function onTouchGui(touchGui: Instance)
	touchGui.DescendantAdded:Connect(onDescendantAdded)
	for _, descendant in touchGui:GetDescendants() do
		onDescendantAdded(descendant)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function TouchControlsSideController.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "TouchGui" then
			onTouchGui(child)
		end
	end)
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if touchGui then
		onTouchGui(touchGui)
	end

	SettingsController.SettingChangedTasks:Add(function(settingName, _value)
		if settingName == "LeftHandedTouch" then
			for frame in watched do
				GuiMirror.setMirrored(frame, isLeftHanded())
			end
		end
	end)
end

return TouchControlsSideController
