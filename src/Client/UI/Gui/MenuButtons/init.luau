--[[
	MenuButtons

	The lobby menu on the left side of the screen, in the client's art (from the client's scripter package, LeftHud):
		[   coins plank    ]   <- balance; click = Currency shop
		[Inventory] [ Shop ]
		[  Index  ] [Quests]   <- Index = the Inventory showing every item, owned or not
		[   AFK  (toggle)  ]   <- sits out the next rounds (OptOut, PlayerSessionService)
		[      Stats       ]
		[ Daily ] [Settings]   <- tiles like the four above (our own art from the client's tiles)
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

-- // Sizes are for a 900 px tall screen; everything scales with screen height (UIScale), clamped below
local REFERENCE_SCREEN_HEIGHT = 900
local MIN_SCALE, MAX_SCALE = 0.55, 1.2
local LEFT_MARGIN = 14
local VERTICAL_POSITION = 0.5 -- // Menu center as a fraction of screen height
local GAP = 10

-- // The client's art column, in mockup pixels (CANVAS), shown COLUMN_WIDTH wide
local CANVAS = Vector2.new(1011, 2649)
local COLUMN_WIDTH = 240
local COLUMN_SCALE = COLUMN_WIDTH / CANVAS.X
local COINS = { 23, 0, 930, 374 } -- // {x, y, w, h}
local COIN_TEXT = { 427, 95, 410, 215 } -- // Inside COINS: where the balance goes
local COIN_ICON = { 168, 98, 235, 215 } -- // Inside COINS: the coin icon
local TILES = {
	{ Id = "Skins", Art = "Inventory", Text = "Inventory", Rect = { 16, 406, 484, 478 } },
	{ Id = "Shop", Art = "Shop", Text = "Shop", Rect = { 512, 406, 488, 478 } },
	{ Id = "Index", Art = "Index", Text = "Index", Rect = { 16, 905, 484, 473 } },
	{ Id = "Quests", Art = "Quests", Text = "Quests", Rect = { 512, 905, 488, 473 } },
	{ Id = "Daily", Art = "Daily", Text = "Daily", Rect = { 16, 2171, 484, 478 } }, -- // Under Stats
	{ Id = "Settings", Art = "Settings", Text = "Settings", Rect = { 512, 2171, 484, 478 } },
}
-- // The name on a tile's ribbon, in the blank ribbon's own pixels (RIBBON_ART), scaled to each tile
local RIBBON_ART = Vector2.new(484, 478)
local RIBBON_TEXT = { 95, 330, 305, 82 }
local LABEL_TEXT_SIZE = 120 -- // Over 100: the lettering fills its box (Kit.label)
-- // AFK slide toggle, in the toggle art's own pixels (AFK_ART), scaled to AFK's width
local AFK = { 0, 1388, 1011, 371 }
local AFK_ART = Vector2.new(1580, 580)
local AFK_HIT = { 55, 50, 1465, 495 } -- // The wooden board only; the vines don't take clicks
local AFK_TRACK = { 208, 163, 600, 269 }
local AFK_KNOB_SIZE = 226
local AFK_KNOB_Y = 297 -- // Knob centre
local AFK_KNOB_X = { [false] = 345, [true] = 671 }
local AFK_TEXT = { 870, 160, 555, 260 }
local AFK_SLIDE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPTED_OUT_ATTRIBUTE = "OptedOut" -- // Set by PlayerSessionService
-- // Stats button (same frame size as AFK), directly beneath it
local STATS = { 0, 1779, 1011, 371 }
local STATS_ART = Vector2.new(948, 348)
local STATS_HIT = { 30, 28, 888, 300 }
local STATS_ICON = { 145, 95, 195, 185 } -- // In STATS_ART pixels
local STATS_TEXT = { 395, 85, 415, 200 }

-- // Every menu, in topbar order (Icon = its topbar icon)
local MENUS = {
	{ Id = "Shop", Text = "Shop", Icon = "rbxassetid://95884415147706" },
	{ Id = "Daily", Text = "Daily", Icon = "rbxassetid://126765785652910" },
	{ Id = "Skins", Text = "Inventory", Icon = `rbxassetid://{Icons.InventoryButton}` },
	{ Id = "Stats", Text = "Stats", Icon = "rbxassetid://124985088272789" },
	{ Id = "Quests", Text = "Quests", Icon = "rbxassetid://83981048085676" },
	{ Id = "Settings", Text = "Settings", Icon = "rbxassetid://118835487029221" },
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
	local coins = Kit.image("ImageButton", Art.CoinsBlank, COINS[1], COINS[2], COINS[3], COINS[4], {
		Name = "Currency",
		Parent = root,
	})
	Kit.image("ImageLabel", Art.IconCoins, COIN_ICON[1], COIN_ICON[2], COIN_ICON[3], COIN_ICON[4], {
		Name = "Icon",
		ScaleType = Enum.ScaleType.Fit,
		Parent = coins,
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
		-- // Stacked layers: framed background, icon, blank ribbon (always over the icon), name text
		local button = Kit.image("ImageButton", art.Bg, x + w / 2, y + h / 2, w, h, {
			Name = tile.Id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = root,
		})
		Kit.image("ImageLabel", art.Icon, 0, 0, w, h, { Name = "Icon", ZIndex = 2, Parent = button })
		Kit.image("ImageLabel", Art.RibbonBlank, 0, 0, w, h, { Name = "Ribbon", ZIndex = 3, Parent = button })
		local sx, sy = w / RIBBON_ART.X, h / RIBBON_ART.Y
		Kit.label(tile.Text, LABEL_TEXT_SIZE, {
			Name = "Label",
			Position = UDim2.fromOffset(RIBBON_TEXT[1] * sx, RIBBON_TEXT[2] * sy),
			Size = UDim2.fromOffset(RIBBON_TEXT[3] * sx, RIBBON_TEXT[4] * sy),
			ZIndex = 4,
			Parent = button,
		})
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
	Kit.image("ImageLabel", Art.AfkFrameBlank, 0, 0, AFK_ART.X, AFK_ART.Y, { Name = "Frame", Parent = art })
	Kit.label("AFK", LABEL_TEXT_SIZE, {
		Name = "Label",
		Position = UDim2.fromOffset(AFK_TEXT[1], AFK_TEXT[2]),
		Size = UDim2.fromOffset(AFK_TEXT[3], AFK_TEXT[4]),
		ZIndex = 2,
		Parent = art,
	})
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
		Art.StatsBlank,
		STATS[1] + STATS[3] / 2,
		STATS[2] + STATS[4] / 2,
		STATS_ART.X * sk,
		STATS_ART.Y * sk,
		{ Name = "Stats", AnchorPoint = Vector2.new(0.5, 0.5), Parent = root }
	)
	Kit.image("ImageLabel", Art.IconStats, STATS_ICON[1] * sk, STATS_ICON[2] * sk, STATS_ICON[3] * sk, STATS_ICON[4] * sk, {
		Name = "Icon",
		ScaleType = Enum.ScaleType.Fit,
		Parent = stats,
	})
	Kit.label("Stats", LABEL_TEXT_SIZE, {
		Name = "Label",
		Position = UDim2.fromOffset(STATS_TEXT[1] * sk, STATS_TEXT[2] * sk),
		Size = UDim2.fromOffset(STATS_TEXT[3] * sk, STATS_TEXT[4] * sk),
		Parent = stats,
	})
	local hit = Kit.create("TextButton", {
		Name = "Hit",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(STATS_HIT[1] * sk, STATS_HIT[2] * sk),
		Size = UDim2.fromOffset(STATS_HIT[3] * sk, STATS_HIT[4] * sk),
		ZIndex = 3,
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
