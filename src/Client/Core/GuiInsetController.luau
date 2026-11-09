--[[
	GuiInsetController

	Description:
	Applies the player's GUI insets (Settings: Left / Right / Top / Bottom Inset, in pixels). On every ScreenGui in the
	PlayerGui, Roblox's safe-area insets are turned off (ScreenInsets = None, IgnoreGuiInset = true) and a UIPadding named
	PlayerGuiInsets applies the player's insets. ScreenGuis added later (cloned GUIs, Cmdr...) are handled as they appear.

	A ScreenGui with attribute KeepRobloxInsets = true (set before parenting) is left alone, keeping Roblox's insets.
	The Topbar uses this to line up with Roblox's own topbar buttons.
]]

local GuiInsetController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsController = require(ReplicatedStorage.Client.Core.SettingsController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local PADDING_NAME = "PlayerGuiInsets"
local OPT_OUT_ATTRIBUTE = "KeepRobloxInsets"
local INSET_SETTINGS = {
	GuiInsetLeft = "PaddingLeft",
	GuiInsetRight = "PaddingRight",
	GuiInsetTop = "PaddingTop",
	GuiInsetBottom = "PaddingBottom",
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local playerGui: PlayerGui

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function applyInsets(padding: UIPadding)
	for settingName, property in INSET_SETTINGS do
		(padding :: any)[property] = UDim.new(0, SettingsController.getValue(settingName :: any) :: number)
	end
end

local function setUpScreenGui(screenGui: ScreenGui)
	screenGui.ScreenInsets = Enum.ScreenInsets.None
	screenGui.IgnoreGuiInset = true
	local padding = screenGui:FindFirstChild(PADDING_NAME)
	if not (padding and padding:IsA("UIPadding")) then
		padding = Instance.new("UIPadding")
		padding.Name = PADDING_NAME
		padding.Parent = screenGui
	end
	applyInsets(padding :: UIPadding)
end

local function onChildAdded(child: Instance)
	if child:IsA("ScreenGui") and child:GetAttribute(OPT_OUT_ATTRIBUTE) ~= true then
		setUpScreenGui(child)
	end
end

local function applyToAll()
	for _, child in playerGui:GetChildren() do
		onChildAdded(child)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GuiInsetController.init()
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	playerGui.ChildAdded:Connect(onChildAdded)
	applyToAll()

	SettingsController.SettingChangedTasks:Add(function(settingName, _value)
		if INSET_SETTINGS[settingName] then
			for _, child in playerGui:GetChildren() do
				local padding = child:IsA("ScreenGui") and child:FindFirstChild(PADDING_NAME)
				if padding and padding:IsA("UIPadding") then
					applyInsets(padding)
				end
			end
		end
	end)
end

function GuiInsetController.start()
	applyToAll() -- // GUIs parented by other modules during init
end

return GuiInsetController
