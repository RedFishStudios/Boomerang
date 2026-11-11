--[[
	MenuButtons

	The lobby menu on the left side of the screen, in the client's art (from the client's scripter package, LeftHud):
		[   coins plank    ]   <- balance; click = Currency shop
		[Inventory] [ Shop ]
		[  Index  ] [Quests]   <- Index = the Inventory showing every item, owned or not
		[   AFK  (toggle)  ]   <- sits out the next rounds (OptOut, PlayerSessionService)
		[      Stats       ]
		[ Daily ] [Settings]   <- no client art for these yet: our older wooden-frame buttons
	The art column is laid out in the mockup's own pixels (CANVAS) and scaled down; ids are in ClientArt/Assets.
	The same menus are also topbar buttons (TopbarGui), which stay visible in rounds.
	Hidden while the local player is alive in the arena (lobby menu).
]]

local MenuButtonsGui = {}
MenuButtonsGui.Type = "Dynamic" -- // Manages its own visibility (lobby only)
MenuButtonsGui.Open = true

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local EconomyController = require(ReplicatedStorage.Client.Core.EconomyController)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local TopbarGui = require(ReplicatedStorage.Client.UI.Gui.Topbar)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).LeftHud

local LocalPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FONT = Enum.Font.FredokaOne
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local TEXT_STROKE_COLOR = Color3.fromRGB(60, 35, 15)

-- // Sizes are for a 900 px tall screen; everything scales with screen height (UIScale), clamped below
local REFERENCE_SCREEN_HEIGHT = 900
local MIN_SCALE, MAX_SCALE = 0.55, 1.2
local LEFT_MARGIN = 14
local VERTICAL_POSITION = 0.5 -- // Menu center as a fraction of screen height
local GAP = 10

-- // The client's art column, in mockup pixels (CANVAS), shown COLUMN_WIDTH wide
local CANVAS = Vector2.new(1011, 2150)
local COLUMN_WIDTH = 240
local COLUMN_SCALE = COLUMN_WIDTH / CANVAS.X
local COINS = { 23, 0, 930, 374 } -- // {x, y, w, h}
local COIN_TEXT = { 427, 95, 410, 215 } -- // Inside COINS: where the balance goes
local TILES = {
	{ Id = "Skins", Art = "Inventory", Rect = { 16, 406, 484, 478 } },
	{ Id = "Shop", Art = "Shop", Rect = { 512, 406, 488, 478 } },
	{ Id = "Index", Art = "Index", Rect = { 16, 905, 484, 473 } },
	{ Id = "Quests", Art = "Quests", Rect = { 512, 905, 488, 473 } },
}
-- // AFK slide toggle, in the toggle art's own pixels (AFK_ART), scaled to AFK's width
local AFK = { 0, 1388, 1011, 371 }
local AFK_ART = Vector2.new(1580, 580)
local AFK_HIT = { 55, 50, 1465, 495 } -- // The wooden board only; the vines don't take clicks
local AFK_TRACK = { 208, 163, 600, 269 }
local AFK_KNOB_SIZE = 226
local AFK_KNOB_Y = 297 -- // Knob centre
local AFK_KNOB_X = { [false] = 345, [true] = 671 }
local AFK_SLIDE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPTED_OUT_ATTRIBUTE = "OptedOut" -- // Set by PlayerSessionService
-- // Stats button (same frame size as AFK), directly beneath it
local STATS = { 0, 1779, 1011, 371 }
local STATS_ART = Vector2.new(948, 348)
local STATS_HIT = { 30, 28, 888, 300 }

-- // Older wooden-frame buttons, for the menus the client's art doesn't cover (Daily, Settings)
local OLD_BUTTON_WIDTH = (COLUMN_WIDTH - GAP) / 2
local OLD_BUTTON_SIZE = Vector2.new(OLD_BUTTON_WIDTH, math.round(OLD_BUTTON_WIDTH * 753 / 838)) -- // Frame art proportions
local FRAME_IMAGE = "rbxassetid://78059494085912" -- // Hollow wooden frame with a name board at the bottom
local FRAME_FULL = Rect.new(0, 0, 838, 753)
local FRAME_ICON_AREA = Rect.new(160, 120, 680, 510) -- // Free window inside the frame
local FRAME_BOARD_TEXT = Rect.new(145, 560, 700, 695) -- // Free space on the name board, between the two rivets
local INTERIOR_IMAGE = "rbxassetid://138558379535634" -- // Grayscale interior, recolored live with ImageColor3
local INTERIOR_IMAGE_SIZE = Vector2.new(686, 674)
local INTERIOR_BLEED = Rect.new(70, 60, 770, 572) -- // Drawn larger than the window so the frame covers its edges
local INTERIOR_CROP_HEIGHT = INTERIOR_IMAGE_SIZE.X * INTERIOR_BLEED.Height / INTERIOR_BLEED.Width

-- // Every menu, in topbar order. OldStyle = drawn as an older wooden-frame button under the art column.
-- // Icon = the topbar icon (and the old-style button's icon); Color tints an old-style button's interior.
local MENUS = {
	{ Id = "Shop", Text = "Shop", Icon = "rbxassetid://95884415147706" },
	{ Id = "Daily", Text = "Daily", Icon = "rbxassetid://126765785652910", Color = Color3.fromRGB(205, 130, 255), OldStyle = true },
	{ Id = "Skins", Text = "Inventory", Icon = `rbxassetid://{Icons.InventoryButton}` },
	{ Id = "Stats", Text = "Stats", Icon = "rbxassetid://124985088272789" },
	{ Id = "Quests", Text = "Quests", Icon = "rbxassetid://83981048085676" },
	{ Id = "Settings", Text = "Settings", Icon = "rbxassetid://118835487029221", Color = Color3.fromRGB(190, 200, 215), OldStyle = true },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local screenGui: ScreenGui
local coinsAmount: Frame
local coinsPop: UIScale
local buttonInstances: { [string]: GuiObject } = {}
local buttonCallbacks: { [string]: () -> () } = {}
local setOptOutRemote = SimpleRemotes.getEvent("SetOptOut")

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

-- // Maps a rectangle of an image's free space to a position inside the GUI object showing that image
local function rectInRegion(rect: Rect, region: Rect): (UDim2, UDim2)
	local position = UDim2.fromScale((rect.Min.X - region.Min.X) / region.Width, (rect.Min.Y - region.Min.Y) / region.Height)
	local size = UDim2.fromScale(rect.Width / region.Width, rect.Height / region.Height)
	return position, size
end

local function toggleGui(guiName: string)
	local guiModule = UIController.get(guiName)
	if guiModule and guiModule.toggle then
		guiModule.toggle()
	end
end

-- // Placeholder: no Robux shop for buying Currency exists yet
local function openCurrencyShop()
	if RunService:IsStudio() then
		print("[MenuButtons] Currency shop isn't built yet (placeholder)")
	end
end

local function runCallback(buttonId: string)
	local callback = buttonCallbacks[buttonId]
	if callback then
		callback()
	end
end

-- // Hover / press feedback for a button whose clickable area is a transparent overlay on art (AFK, Stats)
local function addOverlayFeedback(hit: GuiButton, target: GuiObject)
	local scale = Kit.create("UIScale", { Parent = target })
	local hovering, pressing = false, false
	local function apply()
		local value = if pressing then Theme.Motion.Press elseif hovering then Theme.Motion.Hover else 1
		TweenService:Create(scale, TweenInfo.new(Theme.Motion.Time), { Scale = value }):Play()
	end
	hit.MouseEnter:Connect(function()
		hovering = true
		apply()
	end)
	hit.MouseLeave:Connect(function()
		hovering, pressing = false, false
		apply()
	end)
	hit.MouseButton1Down:Connect(function()
		pressing = true
		apply()
	end)
	hit.MouseButton1Up:Connect(function()
		pressing = false
		apply()
	end)
end

local function buildCoins(root: Frame)
	local coins = Kit.image("ImageButton", Art.Coins, COINS[1], COINS[2], COINS[3], COINS[4], {
		Name = "Currency",
		Parent = root,
	})
	coinsAmount = Kit.label("0", 150, {
		Name = "Amount",
		Position = UDim2.fromOffset(COIN_TEXT[1], COIN_TEXT[2]),
		Size = UDim2.fromOffset(COIN_TEXT[3], COIN_TEXT[4]),
		Parent = coins,
	})
	for _, layer in coinsAmount:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	coinsPop = Kit.create("UIScale", { Parent = coinsAmount })
	coins.Activated:Connect(openCurrencyShop)
	buttonInstances.Currency = coins
end

local function buildTiles(root: Frame)
	for _, tile in TILES do
		local x, y, w, h = table.unpack(tile.Rect)
		local art = Art[tile.Art]
		-- // Three stacked layers: framed background, icon, name ribbon (always over the icon)
		local button = Kit.image("ImageButton", art.Bg, x + w / 2, y + h / 2, w, h, {
			Name = tile.Id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = root,
		})
		Kit.image("ImageLabel", art.Icon, 0, 0, w, h, { Name = "Icon", ZIndex = 2, Parent = button })
		Kit.image("ImageLabel", art.Ribbon, 0, 0, w, h, { Name = "Ribbon", ZIndex = 3, Parent = button })
		Kit.pressable(button)
		button.Activated:Connect(function()
			runCallback(tile.Id)
		end)
		buttonInstances[tile.Id] = button
	end
end

local function buildAfkToggle(root: Frame)
	local k = AFK[3] / AFK_ART.X
	local toggle = Kit.create("Frame", {
		Name = "AfkToggle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(AFK[1] + AFK[3] / 2, AFK[2] + AFK[4] / 2),
		Size = UDim2.fromOffset(AFK_ART.X * k, AFK_ART.Y * k),
		Parent = root,
	})
	local art = Kit.create("Frame", {
		Name = "Art",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(AFK_ART.X, AFK_ART.Y),
		Parent = toggle,
	}, {
		Kit.create("UIScale", { Scale = k }),
	})
	Kit.image("ImageLabel", Art.AfkFrame, 0, 0, AFK_ART.X, AFK_ART.Y, { Name = "Frame", Parent = art })
	Kit.image("ImageLabel", Art.AfkTrackOff, AFK_TRACK[1], AFK_TRACK[2], AFK_TRACK[3], AFK_TRACK[4], {
		Name = "TrackOff",
		ZIndex = 2,
		Parent = art,
	})
	local trackOn = Kit.image("ImageLabel", Art.AfkTrackOn, AFK_TRACK[1], AFK_TRACK[2], AFK_TRACK[3], AFK_TRACK[4], {
		Name = "TrackOn",
		ZIndex = 3,
		ImageTransparency = 1,
		Parent = art,
	})
	local knob = Kit.image("ImageLabel", Art.AfkKnob, AFK_KNOB_X[false], AFK_KNOB_Y, AFK_KNOB_SIZE, AFK_KNOB_SIZE, {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 4,
		Parent = art,
	})
	local hit = Kit.create("TextButton", {
		Name = "Hit",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(AFK_HIT[1] * k, AFK_HIT[2] * k),
		Size = UDim2.fromOffset(AFK_HIT[3] * k, AFK_HIT[4] * k),
		ZIndex = 5,
		Parent = toggle,
	})
	addOverlayFeedback(hit, toggle)
	buttonInstances.Afk = toggle

	local shown = false
	local function show(isAfk: boolean, animate: boolean)
		shown = isAfk
		local info = if animate then AFK_SLIDE else TweenInfo.new(0)
		TweenService:Create(knob, info, { Position = UDim2.fromOffset(AFK_KNOB_X[isAfk], AFK_KNOB_Y) }):Play()
		TweenService:Create(trackOn, info, { ImageTransparency = if isAfk then 0 else 1 }):Play()
	end

	-- // Flip at once (feels instant), then follow whatever the server reports
	hit.Activated:Connect(function()
		show(not shown, true)
		setOptOutRemote:FireServer(shown)
	end)
	LocalPlayer:GetAttributeChangedSignal(OPTED_OUT_ATTRIBUTE):Connect(function()
		local isAfk = LocalPlayer:GetAttribute(OPTED_OUT_ATTRIBUTE) == true
		if isAfk ~= shown then
			show(isAfk, true)
		end
	end)
	show(LocalPlayer:GetAttribute(OPTED_OUT_ATTRIBUTE) == true, false)
end

local function buildStats(root: Frame)
	local sk = STATS[3] / STATS_ART.X
	local stats = Kit.image(
		"ImageLabel",
		Art.Stats,
		STATS[1] + STATS[3] / 2,
		STATS[2] + STATS[4] / 2,
		STATS_ART.X * sk,
		STATS_ART.Y * sk,
		{ Name = "Stats", AnchorPoint = Vector2.new(0.5, 0.5), Parent = root }
	)
	local hit = Kit.create("TextButton", {
		Name = "Hit",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(STATS_HIT[1] * sk, STATS_HIT[2] * sk),
		Size = UDim2.fromOffset(STATS_HIT[3] * sk, STATS_HIT[4] * sk),
		ZIndex = 2,
		Parent = stats,
	})
	addOverlayFeedback(hit, stats)
	hit.Activated:Connect(function()
		runCallback("Stats")
	end)
	buttonInstances.Stats = stats
end

local function buildArtColumn(parent: Instance)
	local column = Kit.create("Frame", {
		Name = "ArtColumn",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(COLUMN_WIDTH, math.round(CANVAS.Y * COLUMN_SCALE)),
		LayoutOrder = 1,
		Parent = parent,
	})
	local root = Kit.create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
		Parent = column,
	}, {
		Kit.create("UIScale", { Scale = COLUMN_SCALE }),
	})
	buildCoins(root)
	buildTiles(root)
	buildAfkToggle(root)
	buildStats(root)
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

local function buildOldStyleButton(info, layoutOrder: number, parent: Instance)
	local button = Instance.new("TextButton")
	button.Name = info.Id
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.LayoutOrder = layoutOrder
	button.Parent = parent
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

	-- // Bottom to top: recolored interior, wooden frame, icon, name text
	local interior = newImage("Interior", INTERIOR_IMAGE, button, 1)
	interior.ImageColor3 = info.Color
	interior.ImageRectSize = Vector2.new(INTERIOR_IMAGE_SIZE.X, INTERIOR_CROP_HEIGHT)
	interior.ImageRectOffset = Vector2.new(0, (INTERIOR_IMAGE_SIZE.Y - INTERIOR_CROP_HEIGHT) / 2)
	interior.Position, interior.Size = rectInRegion(INTERIOR_BLEED, FRAME_FULL)

	local frame = newImage("Frame", FRAME_IMAGE, button, 2)
	frame.Size = UDim2.fromScale(1, 1)

	local icon = newImage("Icon", info.Icon, button, 3)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Position, icon.Size = rectInRegion(FRAME_ICON_AREA, FRAME_FULL)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = info.Text
	label.TextColor3 = TEXT_COLOR
	label.TextStrokeColor3 = TEXT_STROKE_COLOR
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Position, label.Size = rectInRegion(FRAME_BOARD_TEXT, FRAME_FULL)
	label.ZIndex = 4
	label.Parent = button

	button.Activated:Connect(function()
		runCallback(info.Id)
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
	container.Size = UDim2.fromOffset(COLUMN_WIDTH, 0)
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

	buildArtColumn(container)

	local grid = Instance.new("Frame")
	grid.Name = "OldStyleGrid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(COLUMN_WIDTH, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = 2
	grid.Parent = container

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(OLD_BUTTON_SIZE.X, OLD_BUTTON_SIZE.Y)
	gridLayout.CellPadding = UDim2.fromOffset(GAP, GAP)
	gridLayout.FillDirectionMaxCells = 2
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	for index, info in ipairs(MENUS) do
		if info.OldStyle then
			buildOldStyleButton(info, index, grid)
		end
	end

	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function setCoins(value: number, pop: boolean)
	Kit.setText(coinsAmount, formatNumber(value))
	if pop then
		Kit.pop(coinsPop)
	end
end

-- // Hidden while the local player is alive in the arena
local function updateVisibility()
	local livingPlayersInArena = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get() or {}
	screenGui.Enabled = table.find(livingPlayersInArena, LocalPlayer) == nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Shows or hides a button by id. onActivated replaces the button's click action if given.
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
		toggleGui("CosmeticsShop") -- // The Weapons Shop has its own topbar button (below)
	end
	buttonCallbacks.Daily = buttonCallbacks.Daily or function()
		toggleGui("DailyClaims")
	end
	buttonCallbacks.Skins = buttonCallbacks.Skins or function()
		toggleGui("Inventory")
	end
	buttonCallbacks.Index = buttonCallbacks.Index or function()
		-- // The Inventory showing every item, owned or not
		local inventory = UIController.get("Inventory")
		if inventory and inventory.toggleIndex then
			inventory.toggleIndex()
		end
	end
	buttonCallbacks.Stats = buttonCallbacks.Stats or function()
		toggleGui("Stats")
	end
	buttonCallbacks.Quests = buttonCallbacks.Quests or function()
		toggleGui("Quests")
	end
	buttonCallbacks.Settings = buttonCallbacks.Settings or function()
		toggleGui("Settings")
	end

	-- // The same menus as compact topbar buttons, which are always visible (unlike the lobby menu).
	-- // The two shops go on the left; Daily, Inventory, Stats, Quests and Settings on the right (before the currency).
	local RIGHT_SIDE_BUTTONS = { Daily = true, Skins = true, Stats = true, Quests = true, Settings = true }
	for order, entry in MENUS do
		TopbarGui.addButton({
			Id = `Menu{entry.Id}`,
			Icon = entry.Icon,
			Side = if RIGHT_SIDE_BUTTONS[entry.Id] then "Right" else "Left",
			Order = order * 10,
			onActivated = function()
				runCallback(entry.Id)
			end,
		})
	end
	-- // Weapons Shop: topbar only, right after the Shop button
	TopbarGui.addButton({
		Id = "MenuWeaponsShop",
		Icon = `rbxassetid://{Icons.StatsThrows}`, -- // A boomerang being thrown
		Side = "Left",
		Order = 15,
		onActivated = function()
			toggleGui("WeaponsShop")
		end,
	})

	setCoins(EconomyController.getBalance(), false)
	-- // Currency (coin + amount) in the topbar, always visible; clicking it does what the lobby coins plank does
	TopbarGui.addButton({
		Id = "Currency",
		Text = formatNumber(EconomyController.getBalance()),
		Icon = `rbxassetid://{Icons.CurrencyIcon}`,
		Side = "Right",
		Order = 1000, -- // Far right of the right-side buttons, next to Roblox's own
		onActivated = openCurrencyShop,
	})
	EconomyController.CurrencyChangedTasks:Add(function(value: number)
		setCoins(value or 0, true)
		TopbarGui.setButtonText("Currency", formatNumber(value or 0))
	end)

	updateVisibility()
	GameStateLibrary.getGameStateData().LivingPlayersInArena:Subscribe(updateVisibility)
end

return MenuButtonsGui
