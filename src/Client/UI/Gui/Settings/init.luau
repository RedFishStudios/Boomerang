--[[
	SettingsGui

	Description:
	The Settings menu (opened from the lobby's Settings tile). A scrolling list: one wooden header plank per section in
	SettingConstants.SettingSections, then one row per setting, with a toggle button or a slider. Changes go through
	SettingsController (applied at once, saved by the server).
	Looks: blank art in the style of the other new menus (ClientArt/Assets.SettingsScreen: window, row panel, header plank;
	the Quests close button, green / grey buttons and progress track; the AFK knob), with every text drawn as instances
	(ClientArt/Kit). Laid out in the frame image's own pixels (CANVAS) and fitted to the screen by Kit.window.
]]

local SettingsGui = {}
SettingsGui.Type = "HUD"
SettingsGui.Open = false
SettingsGui.RequiresMouse = true -- // Frees the mouse in a locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local SettingsController = require(ReplicatedStorage.Client.Core.SettingsController)
local SettingConstants = require(ReplicatedStorage.Shared.Constants.SettingConstants)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local Assets = require(ReplicatedStorage.Client.UI.ClientArt.Assets)

local Art = Assets.SettingsScreen
local QuestArt = Assets.QuestsScreen -- // Close button, green / grey buttons, progress track
local HudArt = Assets.LeftHud -- // The AFK knob, used as the slider knob

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // Redraws a row's control from the setting's current value
type RowUpdater = (value: SettingConstants.SettingValue) -> ()

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Layout in the frame art's pixels ({x, y, w, h})
local CANVAS = Vector2.new(1448, 900)
local TITLE = { 430, 40, 560, 88 } -- // On the ribbon
local CLOSE = { 1262, 50, 112, 110 }
local CLOSE_ICON_INSET = 0.22
local LIST = { 214, 192, 1026, 592 } -- // The scrolling list, inside the parchment (above the clouds)
local SCROLLBAR = 14
local LIST_GAP = 10

local ROW_SIZE = Vector2.new(1000, 124) -- // A row: the row panel (its image has a 10 px margin for the shadow)
local ROW_IMAGE_PAD = 10
local ROW_FACE_HEIGHT = 112 -- // The panel's flat top, above its thickness
local ROW_TITLE = { 32, 0, 440, ROW_FACE_HEIGHT }
local TOGGLE = { 706, 22, 262, 70 }
local TRACK = { 470, 40, 360, 34 }
local TRACK_INSET = 4
local KNOB_SIZE = 64
local SLIDER_VALUE = { 846, 0, 130, ROW_FACE_HEIGHT }

local HEADER_HEIGHT = 84
local PLANK = Vector2.new(459, 76) -- // The header plank image, centred in the header
local TEXT_SIZE = { Title = 64, Header = 40, Row = 40, Toggle = 34, Value = 36 }
local FILL_COLOR = Color3.fromRGB(110, 196, 52) -- // As the Quests progress bars

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local window: Kit.Window
local list: ScrollingFrame
local rowUpdaters: { [string]: RowUpdater } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function rect(r: { number }): (UDim2, UDim2)
	return UDim2.fromOffset(r[1], r[2]), UDim2.fromOffset(r[3], r[4])
end

-- // Cream lettering with a dark outline (Kit.label), wrapped and shrunk to fit its box
local function outlined(name: string, text: string, size: number, r: { number }, parent: Instance, zIndex: number?): Frame
	local label = Kit.label(text, size, { Name = name, ZIndex = zIndex or 2, Parent = parent })
	label.Position, label.Size = rect(r)
	for _, layer in label:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextWrapped = true
			layer.TextScaled = true
			layer.ZIndex += (zIndex or 2) - 1
			Kit.create("UITextSizeConstraint", { MaxTextSize = size, Parent = layer })
		end
	end
	return label
end

-- // Dark brown lettering printed on the cream rows
local function printed(name: string, text: string, size: number, r: { number }, parent: Instance): TextLabel
	local label = Kit.create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = text,
		TextColor3 = Theme.Colors.Ink,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 3,
	}, {
		Kit.create("UITextSizeConstraint", { MaxTextSize = size }),
	})
	label.Position, label.Size = rect(r)
	label.Parent = parent
	return label
end

local function createToggle(settingName: SettingConstants.SettingName, setting: SettingConstants.Setting, row: Frame): RowUpdater
	local button = Kit.create("ImageButton", {
		Name = "Toggle",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = QuestArt.ButtonGrey,
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(TOGGLE[1] + TOGGLE[3] / 2, TOGGLE[2] + TOGGLE[4] / 2),
		Size = UDim2.fromOffset(TOGGLE[3], TOGGLE[4]),
		ZIndex = 3,
		Parent = row,
	})
	local text = outlined("Text", "", TEXT_SIZE.Toggle, { TOGGLE[3] * 0.1, TOGGLE[4] * 0.12, TOGGLE[3] * 0.8, TOGGLE[4] * 0.76 }, button, 4)
	Kit.pressable(button)
	button.Activated:Connect(function()
		SettingsController.setValue(settingName, not SettingsController.getValue(settingName))
	end)

	return function(value: SettingConstants.SettingValue)
		local isOn = value == true
		Kit.setText(text, if isOn then (setting.OnText or "On") else (setting.OffText or "Off"))
		button.Image = if isOn then QuestArt.ButtonGreen else QuestArt.ButtonGrey
	end
end

local function createSlider(settingName: SettingConstants.SettingName, setting: SettingConstants.Setting, row: Frame): RowUpdater
	local min, max = setting.Min or 0, setting.Max or 1
	local dragging = false
	local dragInput: InputObject? = nil
	local dragValue: number? = nil -- // Shown while dragging; saved on release

	-- // The track takes clicks and drags; the fill and knob follow the value
	local track = Kit.create("ImageButton", {
		Name = "Track",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = QuestArt.ProgressTrack,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
		Parent = row,
	})
	track.Position, track.Size = rect(TRACK)
	local fillArea = Kit.create("Frame", {
		Name = "FillArea",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(TRACK_INSET, TRACK_INSET),
		Size = UDim2.new(1, -2 * TRACK_INSET, 1, -2 * TRACK_INSET),
		ZIndex = 4,
		Parent = track,
	})
	local fill = Kit.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = FILL_COLOR,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = fillArea,
	}, {
		Kit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Kit.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		}),
	})
	local knob = Kit.create("ImageLabel", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = HudArt.AfkKnob,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
		ZIndex = 5,
		Parent = track,
	})
	local valueLabel = printed("Value", "", TEXT_SIZE.Value, SLIDER_VALUE, row)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

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
			and dragInput
			and dragInput.UserInputType == Enum.UserInputType.MouseButton1
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

	return function(value: SettingConstants.SettingValue)
		if not dragging then
			draw(value :: number)
		end
	end
end

local function createRow(settingName: SettingConstants.SettingName, order: number)
	local setting = SettingConstants.Settings[settingName]
	local row = Kit.create("Frame", {
		Name = settingName,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromOffset(ROW_SIZE.X, ROW_SIZE.Y),
		Parent = list,
	})
	Kit.image("ImageLabel", Art.Row, -ROW_IMAGE_PAD, -ROW_IMAGE_PAD, ROW_SIZE.X + 2 * ROW_IMAGE_PAD, ROW_SIZE.Y + 2 * ROW_IMAGE_PAD, {
		Name = "Panel",
		ZIndex = 2,
		Parent = row,
	})
	printed("Title", setting.DisplayName, TEXT_SIZE.Row, ROW_TITLE, row).TextXAlignment = Enum.TextXAlignment.Left

	rowUpdaters[settingName] = if setting.Type == SettingConstants.SettingTypes.Slider
		then createSlider(settingName, setting, row)
		else createToggle(settingName, setting, row)
end

local function createHeader(title: string, order: number)
	local header = Kit.create("Frame", {
		Name = `{title}Header`,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromOffset(ROW_SIZE.X, HEADER_HEIGHT),
		Parent = list,
	})
	local x, y = (ROW_SIZE.X - PLANK.X) / 2, (HEADER_HEIGHT - PLANK.Y) / 2
	Kit.image("ImageLabel", Art.HeaderPlank, x, y, PLANK.X, PLANK.Y, { Name = "Plank", ZIndex = 2, Parent = header })
	outlined("Title", title, TEXT_SIZE.Header, { x + 30, y + 10, PLANK.X - 60, PLANK.Y - 20 }, header, 3)
end

local function refreshAll()
	for settingName, update in rowUpdaters do
		update(SettingsController.getValue(settingName :: SettingConstants.SettingName))
	end
end

local function build()
	window = Kit.window(player:WaitForChild("PlayerGui"), "Settings", Art.Window, CANVAS)
	local root = window.root

	outlined("Title", "Settings", TEXT_SIZE.Title, TITLE, root, 2)

	-- // Close button: the Quests menu's blank button + X icon
	local close = Kit.create("ImageButton", {
		Name = "Close",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = QuestArt.CloseBlank,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CLOSE[1] + CLOSE[3] / 2, CLOSE[2] + CLOSE[4] / 2),
		Size = UDim2.fromOffset(CLOSE[3], CLOSE[4]),
		ZIndex = 3,
		Parent = root,
	})
	Kit.create("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = QuestArt.IconClose,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromScale(CLOSE_ICON_INSET, CLOSE_ICON_INSET),
		Size = UDim2.fromScale(1 - 2 * CLOSE_ICON_INSET, 1 - 2 * CLOSE_ICON_INSET),
		ZIndex = 4,
		Parent = close,
	})
	Kit.pressable(close)
	close.Activated:Connect(function()
		SettingsGui.close()
	end)

	list = Kit.create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = SCROLLBAR,
		ScrollBarImageColor3 = Theme.Colors.WoodDark,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ZIndex = 2,
		Parent = root,
	}, {
		Kit.create("UIListLayout", {
			Padding = UDim.new(0, LIST_GAP),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Kit.create("UIPadding", {
			PaddingTop = UDim.new(0, ROW_IMAGE_PAD),
			PaddingBottom = UDim.new(0, ROW_IMAGE_PAD * 2),
			PaddingLeft = UDim.new(0, ROW_IMAGE_PAD),
		}),
	})
	list.Position, list.Size = rect(LIST)

	local order = 0
	for _, section in SettingConstants.SettingSections do
		order += 1
		createHeader(section.Title, order)
		for _, settingName in section.Settings do
			order += 1
			createRow(settingName, order)
		end
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SettingsGui.open()
	SettingsGui.Open = true
	refreshAll()
	window.open()
	UIController.supercede("Settings", "GamemodeHud")
	UIController.closeOtherMenus("Settings") -- // After superceding, so the closing menu doesn't restore the HUD
end

function SettingsGui.close()
	SettingsGui.Open = false
	window.close()
	UIController.unSupercede("Settings", "GamemodeHud")
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

function SettingsGui.start()
	SettingsController.SettingChangedTasks:Add(function(settingName, value)
		local update = rowUpdaters[settingName]
		if update then
			update(value)
		end
	end)

	-- // Closes only when the player enters the arena, not on every arena player change; it can still be opened during a
	-- // round from its topbar button.
	local wasInArena = false
	GameStateLibrary.getGameStateData().LivingPlayersInArena:Subscribe(function(livingPlayers)
		local isInArena = table.find(livingPlayers or {}, player) ~= nil
		if isInArena and not wasInArena and SettingsGui.Open then
			SettingsGui.close()
		end
		wasInArena = isInArena
	end)
end

build()

return SettingsGui
