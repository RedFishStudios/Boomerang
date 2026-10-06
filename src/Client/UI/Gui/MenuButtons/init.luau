--[[
	MenuButtons (T-037)

	The player's menu buttons on the left side of the screen, laid out like Sol's mockup:
		[      Currency      ]   <- as wide as two buttons: boomerang icon + balance; click = Currency shop (later)
		[ Shop ] [ Daily ]
		[ Skins] [ Stats]
		[Quests] [Achievements]
	Buttons sit in a 2-column grid; hidden buttons are skipped, so the grid closes up.
	Quests and Achievements stay hidden until their features exist; the feature turns its button on with
		MenuButtonsGui.setButtonEnabled("Quests", true, QuestsGui.toggle)

	Art: Sol's wooden frame + recolorable grayscale interior for the buttons, and the currency bar image. The button icons
	are still emoji placeholders (the currency icon too). Every size, color, icon and the art's layout rectangles are in
	the constants / BUTTONS table below.
	Hidden while the local player is alive in the arena (it's a lobby menu; the round camera locks the mouse anyway).
]]

local MenuButtonsGui = {}
MenuButtonsGui.Type = "Dynamic" -- // Manages its own visibility (lobby only); not opened/closed with the other HUD guis
MenuButtonsGui.Open = true

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local EconomyController = require(ReplicatedStorage.Client.Core.EconomyController)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local LocalPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FONT = Enum.Font.FredokaOne
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local TEXT_STROKE_COLOR = Color3.fromRGB(60, 35, 15)

-- // Sizes at a 900 px tall screen; everything scales with the screen height (UIScale), clamped below
local REFERENCE_SCREEN_HEIGHT = 900
local MIN_SCALE, MAX_SCALE = 0.55, 1.2
local BUTTON_SIZE = Vector2.new(100, 90) -- // Same proportions as the frame art (838 x 753)
local GAP = 10
local CURRENCY_WIDTH = BUTTON_SIZE.X * 2 + GAP -- // Two small buttons wide
local LEFT_MARGIN = 14
local VERTICAL_POSITION = 0.42 -- // Center of the menu, as a fraction of screen height (clear of the mobile thumbstick)

-- // Sol's image assets. All the rectangles below are in pixels of the source image and get converted to Scale, so the
-- // text and icons stay inside the art's free space at any size.
local FRAME_IMAGE = "rbxassetid://78059494085912" -- // Hollow wooden frame with a name board at the bottom
local FRAME_IMAGE_SIZE = Vector2.new(838, 753)
local FRAME_FULL = Rect.new(0, 0, 838, 753)
local FRAME_ICON_AREA = Rect.new(160, 120, 680, 510) -- // Free window inside the frame (the window itself is 99,92 to 742,538)
local FRAME_BOARD_TEXT = Rect.new(145, 560, 700, 695) -- // Free space on the name board, between the two rivets
local INTERIOR_IMAGE = "rbxassetid://138558379535634" -- // Grayscale interior, recolored live with ImageColor3
local INTERIOR_IMAGE_SIZE = Vector2.new(686, 674)
local INTERIOR_BLEED = Rect.new(70, 60, 770, 572) -- // Drawn bigger than the window so the frame covers its edges
local INTERIOR_SLICE = 56 -- // Bevel width in interior image pixels; 9-sliced so the bevel doesn't stretch

local BAR_IMAGE = "rbxassetid://97631724752812" -- // Currency bar (transparent margin around the painted part)
local BAR_IMAGE_SIZE = Vector2.new(1024, 512)
local BAR_CONTENT = Rect.new(32, 56, 1006, 464) -- // The painted part; this is what gets CURRENCY_WIDTH wide
local BAR_COIN_AREA = Rect.new(90, 131, 340, 381) -- // Free space for the boomerang coin on the left
local BAR_TEXT_AREA = Rect.new(360, 140, 860, 372) -- // Free space for the balance
local CURRENCY_HEIGHT = math.round(CURRENCY_WIDTH * BAR_CONTENT.Height / BAR_CONTENT.Width)

-- // The buttons, in grid order. Enabled = shown from the start.
-- // Color is a tint multiplied over the grayscale interior (average gray is about 50%), so it can't make the interior
-- // brighter than the source art. Keep channels as high as they can go and vary the others.
local BUTTONS = {
	{ Id = "Shop", Text = "Shop", Icon = "🛒", Color = Color3.fromRGB(255, 120, 95), Enabled = true },
	{ Id = "Daily", Text = "Daily", Icon = "🎁", Color = Color3.fromRGB(205, 130, 255), Enabled = true },
	{ Id = "Skins", Text = "Skins", Icon = "🪃", Color = Color3.fromRGB(110, 175, 255), Enabled = true }, -- // T-072
	{ Id = "Stats", Text = "Stats", Icon = "📊", Color = Color3.fromRGB(100, 255, 225), Enabled = true }, -- // T-074
	{ Id = "Quests", Text = "Quests", Icon = "📜", Color = Color3.fromRGB(255, 215, 90), Enabled = false }, -- // T-038
	{ Id = "Achievements", Text = "Achievements", Icon = "🏆", Color = Color3.fromRGB(150, 255, 120), Enabled = false }, -- // T-039
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local screenGui: ScreenGui
local currencyLabel: TextLabel
local buttonInstances: { [string]: TextButton } = {}
local buttonCallbacks: { [string]: () -> () } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted, count
	repeat
		formatted, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = formatted
	until count == 0
	return text
end

-- // Where a rectangle of an image's free space lands inside a GUI object that shows that image (or its painted part)
local function rectInRegion(rect: Rect, region: Rect): (UDim2, UDim2)
	local position = UDim2.fromScale((rect.Min.X - region.Min.X) / region.Width, (rect.Min.Y - region.Min.Y) / region.Height)
	local size = UDim2.fromScale(rect.Width / region.Width, rect.Height / region.Height)
	return position, size
end

local function newLabel(name: string, text: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextColor3 = TEXT_COLOR
	label.TextStrokeColor3 = TEXT_STROKE_COLOR
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = parent
	return label
end

-- // Small press feedback, shared by every button
local function addPressFeedback(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		scale.Scale = 1.04
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	button.MouseButton1Down:Connect(function()
		scale.Scale = 0.95
	end)
	button.MouseButton1Up:Connect(function()
		scale.Scale = 1.04
	end)
end

local function toggleGui(guiName: string)
	local guiModule = UIController.get(guiName)
	if guiModule and guiModule.toggle then
		guiModule.toggle()
	end
end

-- // Placeholder: the Robux shop for buying Currency doesn't exist yet (Sol, 2026-10-03). Wire it here when it does.
local function openCurrencyShop()
	if RunService:IsStudio() then
		print("[MenuButtons] Currency shop isn't built yet (T-037 placeholder)")
	end
end

local function newImage(name: string, image: string, parent: Instance, zIndex: number): ImageLabel
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = name
	imageLabel.BackgroundTransparency = 1
	imageLabel.Image = image
	imageLabel.ZIndex = zIndex
	imageLabel.Parent = parent
	return imageLabel
end

local function buildCurrency(parent: Instance)
	local button = Instance.new("TextButton")
	button.Name = "Currency"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromOffset(CURRENCY_WIDTH, CURRENCY_HEIGHT)
	button.LayoutOrder = 1
	button.Parent = parent
	addPressFeedback(button)

	-- // The image has a transparent margin: stretch it so its painted part exactly fills the button
	local bar = newImage("Bar", BAR_IMAGE, button, 1)
	bar.Position = UDim2.fromScale(-BAR_CONTENT.Min.X / BAR_CONTENT.Width, -BAR_CONTENT.Min.Y / BAR_CONTENT.Height)
	bar.Size = UDim2.fromScale(BAR_IMAGE_SIZE.X / BAR_CONTENT.Width, BAR_IMAGE_SIZE.Y / BAR_CONTENT.Height)

	-- // Boomerang coin on the left (placeholder emoji; swap for Sol's coin image)
	local icon = newLabel("Icon", "🪃", button)
	icon.Position, icon.Size = rectInRegion(BAR_COIN_AREA, BAR_CONTENT)
	icon.ZIndex = 2

	currencyLabel = newLabel("Amount", "0", button)
	currencyLabel.Position, currencyLabel.Size = rectInRegion(BAR_TEXT_AREA, BAR_CONTENT)
	currencyLabel.ZIndex = 2

	button.Activated:Connect(openCurrencyShop)
end

local function buildButton(info, layoutOrder: number, parent: Instance)
	local button = Instance.new("TextButton")
	button.Name = info.Id
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.LayoutOrder = layoutOrder
	button.Visible = info.Enabled
	button.Parent = parent
	addPressFeedback(button)

	-- // Bottom to top: recolored interior, wooden frame, icon, name text
	local interior = newImage("Interior", INTERIOR_IMAGE, button, 1)
	interior.ImageColor3 = info.Color
	interior.ScaleType = Enum.ScaleType.Slice
	interior.SliceCenter = Rect.new(
		INTERIOR_SLICE,
		INTERIOR_SLICE,
		INTERIOR_IMAGE_SIZE.X - INTERIOR_SLICE,
		INTERIOR_IMAGE_SIZE.Y - INTERIOR_SLICE
	)
	interior.SliceScale = BUTTON_SIZE.X / FRAME_IMAGE_SIZE.X
	interior.Position, interior.Size = rectInRegion(INTERIOR_BLEED, FRAME_FULL)

	local frame = newImage("Frame", FRAME_IMAGE, button, 2)
	frame.Size = UDim2.fromScale(1, 1)

	local icon = newLabel("Icon", info.Icon, button)
	icon.Position, icon.Size = rectInRegion(FRAME_ICON_AREA, FRAME_FULL)
	icon.ZIndex = 3

	local label = newLabel("Label", info.Text, button)
	label.Position, label.Size = rectInRegion(FRAME_BOARD_TEXT, FRAME_FULL)
	label.ZIndex = 4

	button.Activated:Connect(function()
		local callback = buttonCallbacks[info.Id]
		if callback then
			callback()
		end
	end)
	buttonInstances[info.Id] = button
end

local function updateScale(uiScale: UIScale)
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else REFERENCE_SCREEN_HEIGHT
	uiScale.Scale = math.clamp(height / REFERENCE_SCREEN_HEIGHT, MIN_SCALE, MAX_SCALE)
end

local function build()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MenuButtons"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 1

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0, 0.5)
	container.Position = UDim2.new(0, LEFT_MARGIN, VERTICAL_POSITION, 0)
	container.Size = UDim2.fromOffset(CURRENCY_WIDTH, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Parent = screenGui

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = container
	updateScale(uiScale)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			updateScale(uiScale)
		end)
	end

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, GAP)
	listLayout.Parent = container

	buildCurrency(container)

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(CURRENCY_WIDTH, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = 2
	grid.Parent = container

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y)
	gridLayout.CellPadding = UDim2.fromOffset(GAP, GAP)
	gridLayout.FillDirectionMaxCells = 2
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	for index, info in ipairs(BUTTONS) do
		buildButton(info, index, grid)
	end

	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- // Lobby menu: hidden while the local player is alive in the arena
local function updateVisibility()
	local livingPlayersInArena = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get() or {}
	screenGui.Enabled = table.find(livingPlayersInArena, LocalPlayer) == nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Shows or hides a button (e.g. Quests once T-038 exists). onActivated replaces the button's click action if given.
function MenuButtonsGui.setButtonEnabled(buttonId: string, enabled: boolean, onActivated: (() -> ())?)
	if onActivated then
		buttonCallbacks[buttonId] = onActivated
	end
	local button = buttonInstances[buttonId]
	if button then
		button.Visible = enabled
	end
end

function MenuButtonsGui.open() end
function MenuButtonsGui.close() end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function MenuButtonsGui.start()
	build()

	buttonCallbacks.Shop = buttonCallbacks.Shop or function()
		toggleGui("Shop")
	end
	buttonCallbacks.Daily = buttonCallbacks.Daily or function()
		toggleGui("DailyClaims")
	end
	buttonCallbacks.Skins = buttonCallbacks.Skins or function()
		toggleGui("Inventory")
	end
	buttonCallbacks.Stats = buttonCallbacks.Stats or function()
		toggleGui("Stats")
	end

	currencyLabel.Text = formatNumber(EconomyController.getBalance())
	EconomyController.CurrencyChangedTasks:Add(function(value: number)
		currencyLabel.Text = formatNumber(value or 0)
	end)

	updateVisibility()
	GameStateLibrary.getGameStateData().LivingPlayersInArena:Subscribe(updateVisibility)
end

return MenuButtonsGui
