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
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local SettingsController = require(ReplicatedStorage.Client.Core.SettingsController)
local SettingConstants = require(ReplicatedStorage.Shared.Constants.SettingConstants)
local CreateElement = require(ReplicatedStorage.Shared.Utils.CreateElement)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local GuiColors = require(ReplicatedStorage.Shared.Referential.GuiColors)
local UIUtil = require(ReplicatedStorage.Client.UI.UIUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Look: listing card art behind rows; borrowed shop art (wide button) for toggles and the slider track. All grayscale,
-- // tinted with ImageColor3
local TEXT_COLOR = Color3.fromRGB(92, 52, 20)
local OUTLINE_COLOR = Color3.fromRGB(45, 28, 12) -- // Same as the shop's text outline
local ROW_COLOR = GuiColors.CommonItemFrame -- // Same tan as owned listings in the Shop and Inventory
local TOGGLE_ON_COLOR = Color3.fromRGB(150, 255, 90) -- // The shop's currency button tint
local TOGGLE_OFF_COLOR = Color3.fromRGB(150, 150, 150) -- // The shop's "owned" button tint
local TRACK_COLOR = Color3.fromRGB(120, 85, 50)
local FILL_COLOR = Color3.fromRGB(70, 140, 235)
local KNOB_COLOR = Color3.new(1, 1, 1)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local CONTAINER_IMAGE = "rbxassetid://107079429198573" -- // Borrowed from the Stats menu (placeholder)
local EXIT_IMAGE = "rbxassetid://83841981001141"
local CONTAINER_ASPECT_RATIO = 1.46190941
local ROW_ASPECT_RATIO = 11 -- // Row width / height (rows span the list's width)
local HEADER_ASPECT_RATIO = 20 -- // Section header width / height
-- // Every label in a group shares one text size: the largest at which all of the group's texts fit their labels,
-- // but no bigger than this fraction of the row height (so short words don't come out huge)
local ROW_TEXT_MAX_HEIGHT_FRACTION = 0.42
local HEADER_TEXT_MAX_HEIGHT_FRACTION = 0.8
local TEXT_FONT = Enum.Font.FredokaOne -- // Same font as FONT, for measuring with TextService
local LIST_PADDING_PIXELS = 6 -- // Gap between rows in the list
local SCROLLBAR_THICKNESS = 6

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
local List: ScrollingFrame
local rows: { GuiObject } = {}
local headers: { GuiObject } = {}
local rowTextLabels: { TextLabel } = {} -- // Row titles, toggle texts, slider values: one shared text size
local headerTextLabels: { TextLabel } = {}
local textSizeQueued = false
local textsForLabel: { [TextLabel]: { string } } = {} -- // Every text a label can show (a toggle's two texts, a slider's widest values)
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
		Size = UDim2.fromScale(0.85, 0.75),
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 3,
	}, { createOutline() })
	table.insert(rowTextLabels, text)
	textsForLabel[text] = { setting.OnText or "On", setting.OffText or "Off" }
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
		Position = UDim2.fromScale(0.47, 0.5),
		Size = UDim2.fromScale(0.34, 0.22),
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
		Position = UDim2.fromScale(0.97, 0.5),
		Size = UDim2.fromScale(0.13, 0.5),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 2,
	}, { createOutline() })
	table.insert(rowTextLabels, valueLabel)
	textsForLabel[valueLabel] = { `{max}{setting.Suffix or ""}`, `{min}{setting.Suffix or ""}` }
	local holder = CreateElement("Frame", {
		Name = "Slider",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, { track, valueLabel })

	local function draw(value: number)
		local alpha = if max > min then math.clamp((value - min) / (max - min), 0, 1) else 0
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = `{math.floor(value + 0.5)}{setting.Suffix or ""}`
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

local function createRow(settingName: SettingConstants.SettingName, order: number): Frame
	local setting = SettingConstants.Settings[settingName]
	local control, update
	if setting.Type == SettingConstants.SettingTypes.Slider then
		control, update = createSlider(settingName, setting)
	else
		control, update = createToggle(settingName, setting)
	end
	rowUpdaters[settingName] = update

	local title = createLabel({
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.05, 0.5),
		Size = UDim2.fromScale(0.42, 0.75),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = setting.DisplayName,
		ZIndex = 2,
	}, { createOutline() })
	table.insert(rowTextLabels, title)
	local row = CreateElement("Frame", {
		Name = settingName,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 20), -- // Height is set by resizeList
		BackgroundTransparency = 1,
	}, {
		UIUtil.createListingCardArt(ROW_COLOR),
		title,
		control,
	})
	row.Parent = List
	table.insert(rows, row)
	return row
end

local function createHeader(title: string, order: number)
	local header = createLabel({
		Name = `{title}Header`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 20), -- // Height is set by resizeList
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	})
	header.Parent = List
	table.insert(headers, header)
	table.insert(headerTextLabels, header)
end

-- // Whether `text` fits a label of `size` at `textSize` (on one line, or wrapped if the label wraps)
local function textFits(label: TextLabel, text: string, textSize: number): boolean
	local size = label.AbsoluteSize
	local wrapWidth = if label.TextWrapped then size.X else math.huge
	local bounds = TextService:GetTextSize(text, textSize, TEXT_FONT, Vector2.new(wrapWidth, math.huge))
	return bounds.X <= size.X + 0.5 and bounds.Y <= size.Y + 0.5
end

-- // One text size for every label in the group: the largest that fits all of them, capped by maxSize
local function applySharedTextSize(labels: { TextLabel }, maxSize: number)
	local best = 1
	local low, high = 1, math.max(1, math.floor(maxSize))
	while low <= high do
		local candidate = math.floor((low + high) / 2)
		local fitsAll = true
		for _, label in labels do
			if label.AbsoluteSize.X <= 0 then
				continue
			end
			for _, text in textsForLabel[label] or { label.Text } do
				if not textFits(label, text, candidate) then
					fitsAll = false
					break
				end
			end
			if not fitsAll then
				break
			end
		end
		if fitsAll then
			best = candidate
			low = candidate + 1
		else
			high = candidate - 1
		end
	end
	for _, label in labels do
		label.TextScaled = false
		label.TextSize = best
	end
end

local function updateTextSizes()
	local rowHeight = if rows[1] then rows[1].AbsoluteSize.Y else 0
	local headerHeight = if headers[1] then headers[1].AbsoluteSize.Y else 0
	if rowHeight <= 0 then
		return
	end
	applySharedTextSize(rowTextLabels, rowHeight * ROW_TEXT_MAX_HEIGHT_FRACTION)
	applySharedTextSize(headerTextLabels, headerHeight * HEADER_TEXT_MAX_HEIGHT_FRACTION)
end

-- // After a resize the labels' AbsoluteSize updates once the frame is laid out: measure after that
local function queueTextSizes()
	if textSizeQueued then
		return
	end
	textSizeQueued = true
	task.spawn(function()
		RunService.Heartbeat:Wait()
		textSizeQueued = false
		updateTextSizes()
	end)
end

-- // Rows have pixel heights (a scrolling list can't size them by scale): kept in proportion to the list's width
local function resizeList()
	local width = List.AbsoluteSize.X - SCROLLBAR_THICKNESS * 2
	for _, header in headers do
		header.Size = UDim2.new(1, 0, 0, math.floor(width / HEADER_ASPECT_RATIO))
	end
	for _, row in rows do
		row.Size = UDim2.new(1, 0, 0, math.floor(width / ROW_ASPECT_RATIO))
	end
	queueTextSizes()
end

local function refreshAll()
	for settingName, update in rowUpdaters do
		update(SettingsController.getValue(settingName :: SettingConstants.SettingName))
	end
end

local function createGui(): ScreenGui
	-- // The parchment inside the brick border of the (borrowed) frame image, as in the Stats and Quests menus
	List = CreateElement("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromScale(0.118, 0.24),
		Size = UDim2.fromScale(0.765, 0.548),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = SCROLLBAR_THICKNESS,
		ScrollBarImageColor3 = TEXT_COLOR,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, {
		CreateElement("UIListLayout", {
			Padding = UDim.new(0, LIST_PADDING_PIXELS),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		CreateElement("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, SCROLLBAR_THICKNESS * 2),
		}),
	})
	local order = 0
	for _, section in SettingConstants.SettingSections do
		order += 1
		createHeader(section.Title, order)
		for _, settingName in section.Settings do
			order += 1
			createRow(settingName, order)
		end
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
	resizeList()
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

	List:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeList)
	if rows[1] then
		rows[1]:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueTextSizes)
	end
end

function SettingsGui.start()
	SettingsController.SettingChangedTasks:Add(function(settingName, value)
		local update = rowUpdaters[settingName]
		if update then
			update(value)
		end
	end)

	-- // Closes when the player goes into the arena (the lobby buttons hide then). It can still be opened during a round
	-- // from its topbar button, so it only closes on the way in, not whenever the arena's players change.
	local wasInArena = false
	GameStateLibrary.getGameStateData().LivingPlayersInArena:Subscribe(function(livingPlayers)
		local isInArena = table.find(livingPlayers or {}, player) ~= nil
		if isInArena and not wasInArena and SettingsGui.Open then
			SettingsGui.close()
		end
		wasInArena = isInArena
	end)
end

_init()

return SettingsGui
