--[[
	ControlSchemeController (T-140)

	PC mouse/keyboard control schemes, switched with P (for every player, for the client's test). Not saved: every session
	starts on Classic.

	- Classic: WASD move, Space dash, left click Stab, hold right click to aim (mouse) and release to throw, E recall.
	- Experimental: WASD move, Space dash, right click Stab, hold left click to charge: the player stops and WASD aims instead
	  of moving (8 directions), release to throw; movement comes back once thrown. E recall.

	The scheme only changes which inputs the client turns into which actions (WeaponController, AbilityController); the server
	receives the same aim/throw/stab requests either way. Touch and gamepad controls aren't affected.
]]

local ControlSchemeController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

export type ControlScheme = "Classic" | "Experimental"

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local TOGGLE_KEY = Enum.KeyCode.P
local SCHEME_DISPLAY_NAMES: { [ControlScheme]: string } = {
	Classic = "Classic controls",
	Experimental = "Experimental controls",
}

-- // The toast saying which scheme is on (HUD text style: Fredoka One, white, dark brown outline)
local TOAST_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local TOAST_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local TOAST_STROKE_COLOR = Color3.fromRGB(60, 35, 15)
local TOAST_STROKE_THICKNESS = 2
local TOAST_SECONDS = 2
local TOAST_FADE_SECONDS = 0.4

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ControlSchemeController.SchemeChanged = TasksList.new() :: TasksList.TasksList<(scheme: ControlScheme) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local currentScheme: ControlScheme = "Classic"
local toastLabel: TextLabel? = nil
local toastStroke: UIStroke? = nil
local toastToken = 0

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getToast(): (TextLabel, UIStroke)
	if toastLabel and toastLabel.Parent and toastStroke then
		return toastLabel, toastStroke
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ControlSchemeToast"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 50
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Toast"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.14)
	label.Size = UDim2.fromScale(0.4, 0.05)
	label.BackgroundTransparency = 1
	label.FontFace = TOAST_FONT
	label.TextColor3 = TOAST_TEXT_COLOR
	label.TextScaled = true
	label.TextTransparency = 1
	label.Parent = screenGui

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = TOAST_STROKE_COLOR
	stroke.Thickness = TOAST_STROKE_THICKNESS
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = 1
	stroke.Parent = label

	toastLabel, toastStroke = label, stroke
	return label, stroke
end

local function showToast(text: string)
	local label, stroke = getToast()
	toastToken += 1
	local token = toastToken
	label.Text = text
	label.TextTransparency = 0
	stroke.Transparency = 0
	task.delay(TOAST_SECONDS, function()
		if token ~= toastToken then
			return -- // Toggled again meanwhile: that toast takes over
		end
		local fadeInfo = TweenInfo.new(TOAST_FADE_SECONDS)
		TweenService:Create(label, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fadeInfo, { Transparency = 1 }):Play()
	end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ControlSchemeController.getScheme(): ControlScheme
	return currentScheme
end

function ControlSchemeController.isExperimental(): boolean
	return currentScheme == "Experimental"
end

function ControlSchemeController.setScheme(scheme: ControlScheme)
	if scheme == currentScheme then
		return
	end
	currentScheme = scheme
	showToast(SCHEME_DISPLAY_NAMES[scheme])
	ControlSchemeController.SchemeChanged:Execute("parallel", scheme)
end

function ControlSchemeController.toggleScheme()
	ControlSchemeController.setScheme(if currentScheme == "Classic" then "Experimental" else "Classic")
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ControlSchemeController.init()
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if UserInputService:GetFocusedTextBox() then
			return -- // Typing in chat or a text box
		end
		if input.KeyCode == TOGGLE_KEY then
			ControlSchemeController.toggleScheme()
		end
	end)
end

function ControlSchemeController.start() end

return ControlSchemeController
