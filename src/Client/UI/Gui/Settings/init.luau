--[[
	SettingsGui

	Description:
	The Settings menu (opened from the lobby's Settings button). One row per setting in SettingConstants.SettingOrder:
	a toggle button or a slider. Changes go through SettingsController (applied at once, saved by the server).
	Built in code with a placeholder look (borrowed frame art) until the settings art exists.
]]

local SettingsGui = {}
SettingsGui.Type = "HUD"
SettingsGui.Open = false
SettingsGui.RequiresMouse = true -- // Clickable menu: frees the mouse in the locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local SettingsController = require(ReplicatedStorage.Client.Core.SettingsController)
local SettingConstants = require(ReplicatedStorage.Shared.Constants.SettingConstants)
local CreateElement = require(ReplicatedStorage.Shared.Utils.CreateElement)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Look: borrowed shop art (listing base for rows, wide button for toggles and the slider track; all grayscale,
-- // tinted with ImageColor3) until the settings art exists
local TEXT_COLOR = Color3.fromRGB(92, 52, 20)
local OUTLINE_COLOR = Color3.fromRGB(45, 28, 12) -- // Same as the shop's text outline
local ROW_COLOR = Color3.fromRGB(225, 160, 100) -- // The shop's unselected tab tint
local TOGGLE_ON_COLOR = Color3.fromRGB(150, 255, 90) -- // The shop's currency button tint
local TOGGLE_OFF_COLOR = Color3.fromRGB(150, 150, 150) -- // The shop's "owned" button tint
local TRACK_COLOR = Color3.fromRGB(120, 85, 50)
local FILL_COLOR = Color3.fromRGB(70, 140, 235)
local KNOB_COLOR = Color3.new(1, 1, 1)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local CONTAINER_IMAGE = "rbxassetid://107079429198573" -- // Borrowed from the Stats menu (placeholder)
local EXIT_IMAGE = "rbxassetid://83841981001141"
local CONTAINER_ASPECT_RATIO = 1.46190941
local ROW_HEIGHT_SCALE = 0.2 -- // Of the list's height
local ROW_GAP_SCALE = 0.03

local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // Redraws a row's control from the setting's current value
type RowUpdater = (value: SettingConstants.SettingValue) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local SettingsScreenGui: ScreenGui
local Container: GuiObject
local List: Frame
local containerGoalPosition: UDim2
local containerOffscreenPosition: UDim2
local activeTween: Tween?
local rowUpdaters: { [string]: RowUpdater } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // TextLabel with the menu's shared text look; [properties] override the defaults
local function createLabel(properties: { [string]: any }, children: { Instance }?)
	local merged = {
		BackgroundTransparency = 1,
		TextColor3 = TEXT_COLOR,
		TextScaled = true,
		FontFace = FONT,
		TextWrapped = true,
	}
	for property, value in properties do
		merged[property] = value
	end
	return CreateElement("TextLabel", merged, children)
end

-- // Text outline like the shop's (scales with the text)
local function createOutline(): UIStroke
	return CreateElement("UIStroke", {
		Color = OUTLINE_COLOR,
		Thickness = 0.08,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function createToggle(settingName: SettingConstants.SettingName, setting: SettingConstants.Setting): (GuiObject, RowUpdater)
	local text = createLabel({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.55),
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 3,
	}, { createOutline() })
	local button = CreateElement("ImageButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.95, 0.5),
		Size = UDim2.fromScale(0.42, 0.7),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{Icons.ShopWideButton}`,
		AutoButtonColor = true,
		ZIndex = 2,
		MouseButton1Click = function()
			SettingsController.setValue(settingName, not SettingsController.getValue(settingName))
		end,
	}, { text })
	local function update(value: SettingConstants.SettingValue)
		local isOn = value == true
		text.Text = if isOn then (setting.OnText or "On") else (setting.OffText or "Off")
		button.ImageColor3 = if isOn then TOGGLE_ON_COLOR else TOGGLE_OFF_COLOR
	end
	return button, update
end

local function createSlider(settingName: SettingConstants.SettingName, setting: SettingConstants.Setting): (GuiObject, RowUpdater)
	local min, max = setting.Min or 0, setting.Max or 1
	local dragging = false
	local dragInput: InputObject? = nil
	local dragValue: number? = nil -- // Shown while dragging; saved on release

	local fill = CreateElement("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = FILL_COLOR,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, { CreateElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	local knob = CreateElement("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(2.2, 2.2),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = KNOB_COLOR,
		ZIndex = 3,
	}, {
		CreateElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		CreateElement("UIStroke", { Color = TEXT_COLOR, Thickness = 2 }),
	})
	local track = CreateElement("ImageButton", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.33, 0.22),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{Icons.ShopWideButton}`,
		ImageColor3 = TRACK_COLOR,
		AutoButtonColor = false,
		ZIndex = 2,
	}, {
		fill,
		knob,
	})
	local valueLabel = createLabel({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.98, 0.5),
		Size = UDim2.fromScale(0.11, 0.55),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 2,
	}, { createOutline() })
	local holder = CreateElement("Frame", {
		Name = "Slider",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, { track, valueLabel })

	local function draw(value: number)
		local alpha = if max > min then math.clamp((value - min) / (max - min), 0, 1) else 0
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = tostring(math.floor(value + 0.5))
	end

	local function valueAt(screenX: number): number
		local alpha = math.clamp((screenX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		return (SettingConstants.sanitize(settingName, min + alpha * (max - min)) :: number?) or min
	end

	local function finishDrag()
		if not dragging then
			return
		end
		dragging = false
		dragInput = nil
		if dragValue ~= nil then
			SettingsController.setValue(settingName, dragValue)
		end
		dragValue = nil
	end

	track.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		dragInput = input
		dragValue = valueAt(input.Position.X)
		draw(dragValue)
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
			and dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1
		if isMouseMove or input == dragInput then
			dragValue = valueAt(input.Position.X)
			draw(dragValue)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
			finishDrag()
		end
	end)

	local function update(value: SettingConstants.SettingValue)
		if not dragging then
			draw(value :: number)
		end
	end
	return holder, update
end

local function createRow(settingName: SettingConstants.SettingName, order: number): ImageLabel
	local setting = SettingConstants.Settings[settingName]
	local control, update
	if setting.Type == SettingConstants.SettingTypes.Slider then
		control, update = createSlider(settingName, setting)
	else
		control, update = createToggle(settingName, setting)
	end
	rowUpdaters[settingName] = update

	local row = CreateElement("ImageLabel", {
		Name = settingName,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, ROW_HEIGHT_SCALE),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{Icons.ShopListingBase}`, -- // Stretched to the row
		ImageColor3 = ROW_COLOR,
	}, {
		createLabel({
			Name = "Title",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.06, 0.5),
			Size = UDim2.fromScale(0.4, 0.5),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = setting.DisplayName,
			ZIndex = 2,
		}, { createOutline() }),
		control,
	})
	row.Parent = List
	return row
end

local function refreshAll()
	for settingName, update in rowUpdaters do
		update(SettingsController.getValue(settingName :: SettingConstants.SettingName))
	end
end

local function createGui(): ScreenGui
	-- // The parchment inside the brick border of the (borrowed) frame image, as in the Stats and Quests menus
	List = CreateElement("Frame", {
		Name = "List",
		Position = UDim2.fromScale(0.118, 0.26),
		Size = UDim2.fromScale(0.765, 0.52),
		BackgroundTransparency = 1,
	}, {
		CreateElement("UIListLayout", {
			Padding = UDim.new(ROW_GAP_SCALE, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, settingName in SettingConstants.SettingOrder do
		createRow(settingName, order)
	end

	local title = createLabel({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.128),
		Size = UDim2.fromScale(0.36, 0.095),
		ZIndex = 2,
		Text = "SETTINGS",
		TextColor3 = Color3.new(1, 1, 1),
	}, { CreateElement("UIStroke", { Color = TEXT_COLOR, Thickness = 3 }) })

	local exit = CreateElement("ImageButton", {
		Name = "Exit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.955, 0.1),
		Size = UDim2.fromScale(0.085, 0.085),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Image = EXIT_IMAGE,
		MouseButton1Click = function()
			SettingsGui.close()
		end,
	}, { CreateElement("UIAspectRatioConstraint", {}) })

	Container = CreateElement("ImageLabel", {
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.85),
		BackgroundTransparency = 1,
		Image = CONTAINER_IMAGE,
		ScaleType = Enum.ScaleType.Fit,
	}, {
		CreateElement("UIAspectRatioConstraint", { AspectRatio = CONTAINER_ASPECT_RATIO }),
		title,
		exit,
		List,
	})

	return CreateElement("ScreenGui", {
		Name = "Settings",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, { Container })
end

local function playContainerTween(tweenInfo: TweenInfo, goalPosition: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(Container, tweenInfo, { Position = goalPosition })
	activeTween:Play()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SettingsGui.open()
	SettingsGui.Open = true
	SettingsScreenGui.Enabled = true
	refreshAll()
	Container.Position = containerOffscreenPosition
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
	UIController.supercede("Settings", "GamemodeHud")
end

function SettingsGui.close()
	SettingsGui.Open = false
	playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
	UIController.unSupercede("Settings", "GamemodeHud")

	task.delay(CONTAINER_TWEEN_INFO_OUT.Time, function()
		if not SettingsGui.Open then
			SettingsScreenGui.Enabled = false
		end
	end)
end

function SettingsGui.toggle()
	if SettingsGui.Open then
		SettingsGui.close()
	else
		SettingsGui.open()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	SettingsScreenGui = createGui()
	SettingsScreenGui.Parent = player:WaitForChild("PlayerGui")

	containerGoalPosition = Container.Position
	containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)
end

function SettingsGui.start()
	SettingsController.SettingChangedTasks:Add(function(settingName, value)
		local update = rowUpdaters[settingName]
		if update then
			update(value)
		end
	end)

	-- // A lobby menu: it closes when the player goes into the arena (the lobby buttons hide then too)
	GameStateLibrary.getGameStateData().LivingPlayersInArena:Subscribe(function(livingPlayers)
		if SettingsGui.Open and table.find(livingPlayers or {}, player) then
			SettingsGui.close()
		end
	end)
end

_init()

return SettingsGui
