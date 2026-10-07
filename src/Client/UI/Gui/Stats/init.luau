--[[
	Stats (T-074)

	Description:
	The Stats menu, opened from the Stats button in the left lobby menu (MenuButtons).
	Left: six cards with the player's main lifetime stats (time played, eliminations, defeats, games played,
	games won, throws). Right: a scrolling list of smaller stats (times each ability was used, times each pickup was collected).
	Built entirely in code with CreateElement (no GUI instances stored under this script); the card art and frame
	are image assets, and every icon is an emoji TextLabel (cards: CARD_DEFS, rows: LISTING_EMOJIS).
	Reads the replicated profile (PlayerDataController); the stats are written by LifetimeStatsService on the server.
]]

local StatsGui = {}
StatsGui.Type = "HUD"
StatsGui.Open = false
StatsGui.RequiresMouse = true -- // Clickable menu: frees the mouse in the locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local AcquirableThingData = require(ReplicatedStorage.Shared.Referential.AcquirableThingData)
local CreateElement = require(ReplicatedStorage.Shared.Utils.CreateElement)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SECONDS_IN_HOUR = 3600
local SECONDS_IN_MINUTE = 60

-- // Look
local TEXT_COLOR = Color3.fromRGB(92, 52, 20)
local ROW_COLOR = Color3.fromRGB(245, 225, 190)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local CONTAINER_IMAGE = "rbxassetid://127382807461790"
local EXIT_IMAGE = "rbxassetid://83841981001141"
local CARD_IMAGE = "rbxassetid://105517889005779"
local CONTAINER_ASPECT_RATIO = 1.46190941

-- // The six cards on the left, in display order. Field = profile field shown; Name = card instance name
local CARD_DEFS = {
	{ Name = "TimePlayed", Field = "TimePlayed", Label = "Time Played", Emoji = "⏱️" },
	{ Name = "Elims", Field = "Elims", Label = "Eliminations", Emoji = "☠️" },
	{ Name = "Defeats", Field = "Defeats", Label = "Defeats", Emoji = "😵" },
	{ Name = "RoundsPlayed", Field = "RoundsPlayed", Label = "Games Played", Emoji = "🎮" },
	{ Name = "Wins", Field = "Wins", Label = "Games Won", Emoji = "🏆" },
	{ Name = "Throws", Field = "Throws", Label = "Throws", Emoji = "🪃" },
}

local LISTING_ASPECT_RATIO = 7 -- // Row width / height
local ABILITY_ORDER_OFFSET = 0
local PICKUP_ORDER_OFFSET = 1000 -- // Pickups are listed after abilities

-- // Emoji shown as the icon on each right-hand row, keyed by ability / pickup id (no entry = blank icon)
local LISTING_EMOJIS = {
	Stab = "🗡️",
	Dash = "💨",
	BattleRoyale = "👑",
	DashNoclip = "👻",
	Decoy = "🎭",
	Disguise = "👤",
	ExplosiveBoomerang = "💥",
	ExtraBoomerang = "➕",
	FireBoomerang = "🔥",
	IceBoomerang = "❄️",
	MultiBoomerang = "🔱",
	Shield = "🛡️",
	Speedup = "👟",
	TelekinesisBoomerang = "🔮",
	TeleportBoomerang = "🌀",
	ElectricBoomerang = "⚡",
	HomingBoomerang = "🎯",
}

local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local AbilityLogics = ReplicatedStorage.Shared.Logics.AbilityLogics
local PickupLogics = ReplicatedStorage.Shared.Logics.PickupLogics

local StatsScreenGui: ScreenGui
local Container: GuiObject
local Cards: Frame
local Listings: ScrollingFrame
local containerGoalPosition: UDim2
local containerOffscreenPosition: UDim2
local activeTween: Tween?

-- // Rows on the right, keyed by "AbilityUses/<id>" or "PickupsAcquired/<id>"
local listingRows: { [string]: { Row: Frame, Count: TextLabel, Field: string, Id: string, Offset: number } } = {}

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

local function formatTimePlayed(seconds: number): string
	if seconds < SECONDS_IN_HOUR then
		return `{math.floor(seconds / SECONDS_IN_MINUTE)} Min`
	end
	local hours = math.floor(seconds / SECONDS_IN_HOUR)
	return `{formatNumber(hours)} {if hours == 1 then "Hour" else "Hours"}`
end

-- // The title the item-acquired notification uses (AcquirableThingData); ids without an entry
-- // (e.g. abilities) fall back to the spaced-out id: "FireBoomerang" -> "Fire Boomerang"
local function toDisplayName(id: string): string
	local data = AcquirableThingData[id]
	if data and data.Title then
		return data.Title
	end
	return (id:gsub("(%l)(%u)", "%1 %2"))
end

-- // Ability ids and enabled pickup class ids, from their logic folders
local function getListedIds(): { { Field: string, Id: string, Offset: number } }
	local entries = {}
	for _, module in AbilityLogics:GetChildren() do
		if module:IsA("ModuleScript") then
			table.insert(entries, { Field = "AbilityUses", Id = module.Name, Offset = ABILITY_ORDER_OFFSET })
		end
	end
	for _, module in PickupLogics:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, logic = pcall(require, module)
			if ok and type(logic) == "table" and logic.Disabled then
				continue -- // Stub pickups can't be collected yet
			end
			table.insert(entries, { Field = "PickupsAcquired", Id = module.Name, Offset = PICKUP_ORDER_OFFSET })
		end
	end
	return entries
end

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

local function createCard(def, order: number): Instance
	local card = CreateElement("ImageLabel", {
		Name = def.Name,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Image = CARD_IMAGE,
	}, {
		createLabel({
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.6, 0.34),
			Text = def.Emoji,
			TextColor3 = Color3.new(1, 1, 1),
		}, { CreateElement("UIAspectRatioConstraint", {}) }),
		createLabel({
			Name = "Value",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.85, 0.13),
			Text = "0",
		}),
		createLabel({
			Name = "StatName",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.69),
			Size = UDim2.fromScale(0.85, 0.11),
			Text = def.Label,
		}),
	})
	return card
end

local function createListingRow(entry: { Field: string, Id: string, Offset: number })
	local icon = createLabel({
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.02, 0.5),
		Size = UDim2.fromScale(0.1, 0.8),
		Text = LISTING_EMOJIS[entry.Id] or "",
		TextColor3 = Color3.new(1, 1, 1),
	}, { CreateElement("UIAspectRatioConstraint", {}) })

	local statName = createLabel({
		Name = "StatName",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.15, 0.5),
		Size = UDim2.fromScale(0.55, 0.45),
		Text = toDisplayName(entry.Id),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local count = createLabel({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.96, 0.5),
		Size = UDim2.fromScale(0.25, 0.45),
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local row = CreateElement("Frame", {
		Name = `{entry.Field}_{entry.Id}`,
		Size = UDim2.new(1, 0, 0, 44), -- // Height is set by resizeListings
		BackgroundColor3 = ROW_COLOR,
		BorderSizePixel = 0,
	}, {
		CreateElement("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
		CreateElement("UIStroke", { Color = TEXT_COLOR, Thickness = 2 }),
		icon,
		statName,
		count,
	})

	return row, count
end

local function createGui(): ScreenGui
	local cardChildren: { Instance } = {
		CreateElement("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.03, 0.03),
			CellSize = UDim2.fromScale(0.31, 0.485),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for order, def in CARD_DEFS do
		table.insert(cardChildren, createCard(def, order))
	end

	Cards = CreateElement("Frame", {
		Name = "Cards",
		Size = UDim2.fromScale(0.55, 1),
		BackgroundTransparency = 1,
	}, cardChildren)

	Listings = CreateElement("ScrollingFrame", {
		Name = "Listings",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.42, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = TEXT_COLOR,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, {
		CreateElement("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		CreateElement("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 12),
		}),
	})

	local content = CreateElement("Frame", {
		Name = "Content",
		Position = UDim2.fromScale(0.105, 0.2),
		Size = UDim2.fromScale(0.79, 0.61),
		BackgroundTransparency = 1,
	}, { Cards, Listings })

	local title = createLabel({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.053),
		Size = UDim2.fromScale(0.44, 0.085),
		ZIndex = 2,
		Text = "STATS",
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
			StatsGui.close()
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
		content,
	})

	local screenGui = CreateElement("ScreenGui", {
		Name = "Stats",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, { Container })

	return screenGui
end

local function resizeListings()
	local rowHeight = math.floor(Listings.AbsoluteSize.X / LISTING_ASPECT_RATIO)
	for _, listing in listingRows do
		listing.Row.Size = UDim2.new(1, 0, 0, rowHeight)
	end
end

local function buildListings()
	for _, entry in getListedIds() do
		local row, count = createListingRow(entry)
		row.Parent = Listings
		listingRows[`{entry.Field}/{entry.Id}`] = {
			Row = row,
			Count = count,
			Field = entry.Field,
			Id = entry.Id,
			Offset = entry.Offset,
		}
	end
	resizeListings()
end

local function updateStats()
	local data = PlayerDataController.get()
	if not data then
		return
	end

	for _, def in CARD_DEFS do
		local card = Cards:FindFirstChild(def.Name)
		local value = data[def.Field] or 0
		if card then
			card.Value.Text = if def.Field == "TimePlayed" then formatTimePlayed(value) else formatNumber(value)
		end
	end

	-- // Each group (abilities, then pickups) is sorted by count, most used first
	local sorted = {}
	for _, listing in listingRows do
		local counts = data[listing.Field] or {}
		local count = counts[listing.Id] or 0
		listing.Count.Text = formatNumber(count)
		table.insert(sorted, { Listing = listing, Count = count })
	end
	table.sort(sorted, function(a, b)
		if a.Listing.Offset ~= b.Listing.Offset then
			return a.Listing.Offset < b.Listing.Offset
		end
		if a.Count ~= b.Count then
			return a.Count > b.Count
		end
		return a.Listing.Row.Name < b.Listing.Row.Name
	end)
	for index, entry in sorted do
		entry.Listing.Row.LayoutOrder = index
	end
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

function StatsGui.open()
	StatsGui.Open = true
	StatsScreenGui.Enabled = true
	updateStats()
	resizeListings()
	Container.Position = containerOffscreenPosition
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
	UIController.supercede("Stats", "GamemodeHud")
end

function StatsGui.close()
	StatsGui.Open = false
	playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
	UIController.unSupercede("Stats", "GamemodeHud")

	task.delay(CONTAINER_TWEEN_INFO_OUT.Time, function()
		if not StatsGui.Open then
			StatsScreenGui.Enabled = false
		end
	end)
end

function StatsGui.toggle()
	if StatsGui.Open then
		StatsGui.close()
	else
		StatsGui.open()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	StatsScreenGui = createGui()
	StatsScreenGui.Parent = player:WaitForChild("PlayerGui")

	containerGoalPosition = Container.Position
	containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)

	Listings:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeListings)
end

function StatsGui.start()
	buildListings()

	-- // Keep the numbers current while the menu is open (e.g. time played is saved every minute)
	PlayerDataController.UpdatedTasks:Add(function()
		if StatsGui.Open then
			updateStats()
		end
	end)
end

_init()

return StatsGui
