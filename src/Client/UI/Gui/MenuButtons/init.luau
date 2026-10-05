--[[
	MenuButtons (T-037)

	The player's menu buttons on the left side of the screen, laid out like Sol's mockup:
		[      Currency      ]   <- as wide as two buttons: boomerang icon + balance; click = Currency shop (later)
		[ Shop ] [ Daily ]
		[ Skins] [Quests]
		[Achievements]
	Buttons sit in a 2-column grid; hidden buttons are skipped, so the grid closes up.
	Quests and Achievements stay hidden until their features exist; the feature turns its button on with
		MenuButtonsGui.setButtonEnabled("Quests", true, QuestsGui.toggle)

	Code-built placeholder art (colored tiles + emoji). Sol's assets can replace it later: every size, color and icon
	is in the constants / BUTTONS table below.
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
local BUTTON_SIZE = Vector2.new(96, 104) -- // Small buttons: slightly taller than wide, like the mockup
local GAP = 10
local CURRENCY_HEIGHT = 60
local CURRENCY_WIDTH = BUTTON_SIZE.X * 2 + GAP -- // Two small buttons wide
local LEFT_MARGIN = 14
local VERTICAL_POSITION = 0.42 -- // Center of the menu, as a fraction of screen height (clear of the mobile thumbstick)

local FRAME_COLOR = Color3.fromRGB(122, 78, 42) -- // Wooden border
local CURRENCY_COLOR = Color3.fromRGB(214, 178, 128)
local CORNER_RADIUS = 12
local STROKE_THICKNESS = 3

-- // The buttons, in grid order. Enabled = shown from the start.
local BUTTONS = {
	{ Id = "Shop", Text = "Shop", Icon = "🛒", Color = Color3.fromRGB(196, 72, 58), Enabled = true },
	{ Id = "Daily", Text = "Daily", Icon = "🎁", Color = Color3.fromRGB(150, 92, 190), Enabled = true },
	{ Id = "Skins", Text = "Skins", Icon = "🪃", Color = Color3.fromRGB(58, 132, 196), Enabled = true }, -- // T-072
	{ Id = "Quests", Text = "Quests", Icon = "📜", Color = Color3.fromRGB(222, 170, 60), Enabled = false }, -- // T-038
	{ Id = "Achievements", Text = "Achievements", Icon = "🏆", Color = Color3.fromRGB(92, 160, 74), Enabled = false }, -- // T-039
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

local function addCornerAndStroke(guiObject: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CORNER_RADIUS)
	corner.Parent = guiObject
	local stroke = Instance.new("UIStroke")
	stroke.Color = FRAME_COLOR
	stroke.Thickness = STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = guiObject
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

local function buildCurrency(parent: Instance)
	local button = Instance.new("TextButton")
	button.Name = "Currency"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = CURRENCY_COLOR
	button.Size = UDim2.fromOffset(CURRENCY_WIDTH, CURRENCY_HEIGHT)
	button.LayoutOrder = 1
	button.Parent = parent
	addCornerAndStroke(button)
	addPressFeedback(button)

	-- // Room for the boomerang icon on the left (placeholder emoji; swap for Sol's image)
	local icon = newLabel("Icon", "🪃", button)
	icon.Size = UDim2.new(0, CURRENCY_HEIGHT - 12, 1, -12)
	icon.Position = UDim2.fromOffset(8, 6)

	currencyLabel = newLabel("Amount", "0", button)
	currencyLabel.Size = UDim2.new(1, -(CURRENCY_HEIGHT + 14), 1, -14)
	currencyLabel.Position = UDim2.fromOffset(CURRENCY_HEIGHT + 4, 7)
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Left

	button.Activated:Connect(openCurrencyShop)
end

local function buildButton(info, layoutOrder: number, parent: Instance)
	local button = Instance.new("TextButton")
	button.Name = info.Id
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = info.Color
	button.LayoutOrder = layoutOrder
	button.Visible = info.Enabled
	button.Parent = parent
	addCornerAndStroke(button)
	addPressFeedback(button)

	local icon = newLabel("Icon", info.Icon, button)
	icon.Size = UDim2.new(0.7, 0, 0.55, 0)
	icon.Position = UDim2.fromScale(0.15, 0.08)

	-- // Name plate along the bottom, like the mockup
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.BackgroundColor3 = FRAME_COLOR
	plate.Size = UDim2.new(1, -8, 0.28, 0)
	plate.Position = UDim2.new(0, 4, 0.68, 0)
	plate.Parent = button
	local plateCorner = Instance.new("UICorner")
	plateCorner.CornerRadius = UDim.new(0, 8)
	plateCorner.Parent = plate
	local label = newLabel("Label", info.Text, plate)
	label.Size = UDim2.new(1, -6, 1, -4)
	label.Position = UDim2.fromOffset(3, 2)

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
		toggleGui("Skins")
	end

	currencyLabel.Text = formatNumber(EconomyController.getBalance())
	EconomyController.CurrencyChangedTasks:Add(function(value: number)
		currencyLabel.Text = formatNumber(value or 0)
	end)

	updateVisibility()
	GameStateLibrary.getGameStateData().LivingPlayersInArena:Subscribe(updateVisibility)
end

return MenuButtonsGui
