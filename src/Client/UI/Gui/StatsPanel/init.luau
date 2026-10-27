--[[
	StatsPanel (T-130)

	A small panel on the right edge of the screen (centred vertically on PC, top-right corner on touch devices) that replaces
	Roblox's player list (StarterGuiController turns that off). Only its arrow tab shows until it is opened: clicking the tab,
	or pressing Tab, slides it out (and back in). Always present, in the lobby and in rounds.

	Contents, under the "Stats" header:
	- This round: every player's elims and defeats (columns Name / Elims / Defeats), most elims first.
	- A divider line.
	- All time: every player's total elims, defeats, wins and losses (two lines per player: the name, then the numbers), the local
	  player first, then the best elims-to-defeats ratio.

	Built in code with CreateElement; the frame art is one image (FRAME_IMAGE, with the arrow tab and header plank in it). The numbers
	come from attributes the server puts on each Player (Shared/Constants/PlayerStatAttributes, LifetimeStatsService).
]]

local StatsPanelGui = {}
StatsPanelGui.Type = "HUD"
StatsPanelGui.Open = false
StatsPanelGui.SupercededBy = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local CreateElement = require(ReplicatedStorage.Shared.Utils.CreateElement)
local PlayerStatAttributes = require(ReplicatedStorage.Shared.Constants.PlayerStatAttributes)
local PlatformController = require(ReplicatedStorage.Client.Core.PlatformController)

-- // CreateElement also returns its cleanup list; only the instance is wanted here (so it can sit in a children list)
local function create(className: string, properties: { [string]: any }, children: { Instance }?): any
	local element = CreateElement(className, properties, children)
	return element
end

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FRAME_IMAGE = "rbxassetid://127212661618035"
local FRAME_ASPECT_RATIO = 0.878 -- // Width / height of the frame image

-- // Where things sit on the frame image, as fractions of its width (X) and height (Y)
local TAB_POSITION = UDim2.fromScale(0.05, 0.31) -- // The arrow tab on the left edge
local TAB_SIZE = UDim2.fromScale(0.14, 0.26)
local HEADER_POSITION = UDim2.fromScale(0.37, 0.025) -- // The plank at the top
local HEADER_SIZE = UDim2.fromScale(0.43, 0.09)
local CONTENT_POSITION = UDim2.fromScale(0.29, 0.155) -- // The parchment
local CONTENT_SIZE = UDim2.fromScale(0.66, 0.655)
local CLOSED_SLIDE = 0.81 -- // When closed the image slides right by this much of its width, leaving only the tab on screen

local PC_HEIGHT = 0.55 -- // Panel height as a fraction of the screen height
local TOUCH_HEIGHT = 0.45
local SLIDE_TIME = 0.25

local TEXT_COLOR = Color3.fromRGB(92, 52, 20)
local HEADER_TEXT_COLOR = Color3.fromRGB(92, 52, 20)
local LOCAL_ROW_COLOR = Color3.fromRGB(245, 225, 190)
local DIVIDER_COLOR = Color3.fromRGB(150, 95, 45)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

-- // Text sizes, as a share of the panel's height (cells shrink below this only when their text doesn't fit)
local ROW_TEXT_SIZE = 0.034
local HEADER_TEXT_SIZE = 0.032

local ROUND_VISIBLE_ROWS = 10 -- // Listings that fit in a list before it scrolls (each is this share of the list's height)
local ALL_TIME_VISIBLE_ROWS = 6 -- // All-time listings are two lines each (name, then the numbers)
local REFRESH_INTERVAL = 0.2 -- // Seconds: changes are gathered and the lists rebuilt at most this often

-- // Columns: the name column takes what the numbers leave
local ROUND_COLUMNS = { { Label = "Name", Width = 0.56 }, { Label = "Elims", Width = 0.22 }, { Label = "Defeats", Width = 0.22 } }
-- // All time: each listing is the name on one line and these numbers under it (the header shows "All Time" over their labels)
local ALL_TIME_COLUMNS = {
	{ Label = "Elims", Width = 0.25 },
	{ Label = "Defeats", Width = 0.25 },
	{ Label = "Wins", Width = 0.25 },
	{ Label = "Losses", Width = 0.25 },
}

-------------------------------------------------------------------------------
-- GUI
-------------------------------------------------------------------------------

local holder: Frame -- // Set below; text sizes follow its height
local Gui: ScreenGui -- // Set below

local function getMaxTextSize(kind: string): number
	local height = if holder then holder.AbsoluteSize.Y else 0
	return math.max(1, math.floor(height * (if kind == "Header" then HEADER_TEXT_SIZE else ROW_TEXT_SIZE)))
end

-- // kind: "Row" or "Header" (capped text size, so every cell of a kind matches), or nil (just fills its box)
local function text(properties: { [string]: any }, kind: string?): Instance
	local merged = {
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextColor3 = TEXT_COLOR,
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in pairs(properties) do
		merged[key] = value
	end
	local children = {}
	if kind then
		table.insert(children, create("UITextSizeConstraint", { Name = kind, MaxTextSize = getMaxTextSize(kind) }))
	end
	return create("TextLabel", merged, children)
end

local function updateTextSizes()
	for _, descendant in ipairs(Gui:GetDescendants()) do
		if descendant:IsA("UITextSizeConstraint") then
			descendant.MaxTextSize = getMaxTextSize(descendant.Name)
		end
	end
end

-- // Cells laid out left to right by the columns' widths, on one line of a listing (top and height are shares of the listing)
local function addCells(cells: { Instance }, columns, values: { string }, top: number, height: number, isHeader: boolean, firstLeft: boolean)
	local x = 0
	for index, column in ipairs(columns) do
		table.insert(cells, text({
			Name = `Cell{#cells + 1}`,
			Text = values[index] or "",
			Position = UDim2.fromScale(x, top),
			Size = UDim2.fromScale(column.Width, height),
			TextXAlignment = if index == 1 and firstLeft then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			TextTransparency = if isHeader then 0.15 else 0,
		}, if isHeader then "Header" else "Row"))
		x += column.Width
	end
end

local function getColumnLabels(columns): { string }
	local labels = {}
	for _, column in ipairs(columns) do
		table.insert(labels, column.Label)
	end
	return labels
end

-- // A listing (or header): one line of cells, or with `nameLine` two: that text on its own line, then the cells
local function createRow(columns, values: { string }, order: number, isHeader: boolean, highlight: boolean, nameLine: string?): Instance
	local cells = {}
	if nameLine then
		table.insert(cells, text({
			Name = "Name",
			Text = nameLine,
			Position = UDim2.fromScale(0, 0.05),
			Size = UDim2.fromScale(1, 0.42),
			TextXAlignment = if isHeader then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center, -- // A listing's name is centred
			TextTransparency = if isHeader then 0.15 else 0,
		}, if isHeader then "Header" else "Row"))
		addCells(cells, columns, values, 0.53, 0.42, isHeader, false)
	else
		addCells(cells, columns, values, 0.1, 0.8, isHeader, true)
	end
	if highlight then
		table.insert(cells, create("UICorner", { CornerRadius = UDim.new(0.25, 0) }))
	end
	return create("Frame", {
		Name = if isHeader then "Header" else `Row{order}`,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = LOCAL_ROW_COLOR,
		BackgroundTransparency = if highlight then 0.2 else 1,
		BorderSizePixel = 0,
	}, cells)
end

local function createList(name: string, order: number, height: number): ScrollingFrame
	return create("ScrollingFrame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 1), -- // Set by setRows: tall enough for every listing
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = DIVIDER_COLOR,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) }),
	}) :: ScrollingFrame
end

local roundHeaderHolder = create("Frame", { Name = "RoundHeader", LayoutOrder = 1, Size = UDim2.fromScale(1, 0.09), BackgroundTransparency = 1 })
local roundList = createList("RoundList", 2, 0.34)
local divider = create("Frame", {
	Name = "Divider",
	LayoutOrder = 3,
	Size = UDim2.fromScale(1, 0.012),
	BackgroundColor3 = DIVIDER_COLOR,
	BorderSizePixel = 0,
})
local allTimeHeaderHolder = create("Frame", { Name = "AllTimeHeader", LayoutOrder = 4, Size = UDim2.fromScale(1, 0.12), BackgroundTransparency = 1 })
local allTimeList = createList("AllTimeList", 5, 0.40)

-- // Header rows fill their holders (the holder's height is a share of the panel)
local function fillHeader(holder: Instance, columns, nameLine: string?)
	local row = createRow(columns, getColumnLabels(columns), 0, true, false, nameLine)
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = holder
end
fillHeader(roundHeaderHolder, ROUND_COLUMNS)
fillHeader(allTimeHeaderHolder, ALL_TIME_COLUMNS, "All Time")

local content = create("Frame", {
	Name = "Content",
	Position = CONTENT_POSITION,
	Size = CONTENT_SIZE,
	BackgroundTransparency = 1,
}, {
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.01, 0) }),
	roundHeaderHolder,
	roundList,
	divider,
	allTimeHeaderHolder,
	allTimeList,
})

local tabButton = create("TextButton", {
	Name = "Tab",
	Position = TAB_POSITION,
	Size = TAB_SIZE,
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
})

local frameImage = create("ImageLabel", {
	Name = "Frame",
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(CLOSED_SLIDE, 0),
	BackgroundTransparency = 1,
	Image = FRAME_IMAGE,
	ScaleType = Enum.ScaleType.Stretch,
}, {
	text({
		Name = "Title",
		Text = "Stats",
		Position = HEADER_POSITION,
		Size = HEADER_SIZE,
		TextColor3 = HEADER_TEXT_COLOR,
		TextTruncate = Enum.TextTruncate.None,
	}),
	tabButton,
	content,
}) :: ImageLabel

holder = create("Frame", {
	Name = "Holder",
	BackgroundTransparency = 1,
}, {
	create("UIAspectRatioConstraint", { AspectRatio = FRAME_ASPECT_RATIO, DominantAxis = Enum.DominantAxis.Height }),
	frameImage,
}) :: Frame

Gui = create("ScreenGui", {
	Name = "StatsPanel",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	Enabled = false,
}, { holder }) :: ScreenGui

-------------------------------------------------------------------------------
-- LAYOUT & SLIDING
-------------------------------------------------------------------------------

local isOut = false

-- // PC: centred on the right edge. Touch: the top-right corner (the right side lower down is the aim stick and buttons).
local function applyPlacement()
	if PlatformController.getDominantControlScheme() == "Touch" then
		holder.AnchorPoint = Vector2.new(1, 0)
		holder.Position = UDim2.fromScale(1, 0)
		holder.Size = UDim2.fromScale(1, TOUCH_HEIGHT)
	else
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.fromScale(1, 0.5)
		holder.Size = UDim2.fromScale(1, PC_HEIGHT)
	end
end

local function setOut(out: boolean)
	isOut = out
	local target = UDim2.fromScale(if out then 0 else CLOSED_SLIDE, 0)
	TweenService:Create(frameImage, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
end

function StatsPanelGui.toggle()
	setOut(not isOut)
end

-------------------------------------------------------------------------------
-- LISTS
-------------------------------------------------------------------------------

-- // How a player is named in the lists: "DisplayName (@Username)"
local function getListingName(player: Player): string
	return `{player.DisplayName} (@{player.Name})`
end

local function getStat(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if type(value) == "number" then value else 0
end

local function clearRows(list: Instance)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- // Each listing is 1/visibleRows of the list's height; the canvas grows past the list when there are more (all in Scale:
-- // a child's Scale inside a ScrollingFrame is a share of the canvas, so the row's share is divided by the canvas's)
local function setRows(list: ScrollingFrame, rows: { Instance }, visibleRows: number)
	local canvasScale = math.max(1, #rows / visibleRows)
	list.CanvasSize = UDim2.fromScale(0, canvasScale)
	for _, row in ipairs(rows) do
		(row :: Frame).Size = UDim2.fromScale(1, 1 / visibleRows / canvasScale)
		row.Parent = list
	end
end

local function rebuild()
	local players = Players:GetPlayers()

	-- // This round: most elims first (fewer defeats, then name, break ties)
	local byRound = table.clone(players)
	table.sort(byRound, function(a, b)
		local elimsA, elimsB = getStat(a, PlayerStatAttributes.RoundElims), getStat(b, PlayerStatAttributes.RoundElims)
		if elimsA ~= elimsB then
			return elimsA > elimsB
		end
		local defeatsA, defeatsB = getStat(a, PlayerStatAttributes.RoundDefeats), getStat(b, PlayerStatAttributes.RoundDefeats)
		if defeatsA ~= defeatsB then
			return defeatsA < defeatsB
		end
		return a.DisplayName < b.DisplayName
	end)
	clearRows(roundList)
	local roundRows = {}
	for index, player in ipairs(byRound) do
		table.insert(roundRows, createRow(ROUND_COLUMNS, {
			getListingName(player),
			tostring(getStat(player, PlayerStatAttributes.RoundElims)),
			tostring(getStat(player, PlayerStatAttributes.RoundDefeats)),
		}, index, false, player == Player))
	end
	setRows(roundList, roundRows, ROUND_VISIBLE_ROWS)

	-- // All time: the local player first, then the best elims-to-defeats ratio (no defeats: the elims themselves)
	local function ratio(player: Player): number
		return getStat(player, PlayerStatAttributes.Elims) / math.max(1, getStat(player, PlayerStatAttributes.Defeats))
	end
	local byRatio = table.clone(players)
	table.sort(byRatio, function(a, b)
		if a == Player or b == Player then
			return a == Player
		end
		local ratioA, ratioB = ratio(a), ratio(b)
		if ratioA ~= ratioB then
			return ratioA > ratioB
		end
		return a.DisplayName < b.DisplayName
	end)
	clearRows(allTimeList)
	local allTimeRows = {}
	for index, player in ipairs(byRatio) do
		table.insert(allTimeRows, createRow(ALL_TIME_COLUMNS, {
			tostring(getStat(player, PlayerStatAttributes.Elims)),
			tostring(getStat(player, PlayerStatAttributes.Defeats)),
			tostring(getStat(player, PlayerStatAttributes.Wins)),
			tostring(getStat(player, PlayerStatAttributes.Losses)),
		}, index, false, player == Player, getListingName(player)))
	end
	setRows(allTimeList, allTimeRows, ALL_TIME_VISIBLE_ROWS)
end

-- // Many attribute changes can arrive at once (a round starting resets everyone): rebuild at most every REFRESH_INTERVAL
local dirty = true
local lastRebuildAt = 0
local function markDirty()
	dirty = true
end

local watchedAttributes: { [string]: boolean } = {}
for _, attribute in pairs(PlayerStatAttributes) do
	watchedAttributes[attribute] = true
end

local function watchPlayer(player: Player)
	player.AttributeChanged:Connect(function(attribute: string)
		if watchedAttributes[attribute] then
			markDirty()
		end
	end)
	player:GetPropertyChangedSignal("DisplayName"):Connect(markDirty)
	markDirty()
end

-------------------------------------------------------------------------------
-- UI MODULE
-------------------------------------------------------------------------------

function StatsPanelGui.open()
	StatsPanelGui.Open = true
	if #StatsPanelGui.SupercededBy > 0 then
		return
	end
	Gui.Enabled = true
end

function StatsPanelGui.close(_Instant: boolean?)
	StatsPanelGui.Open = false
	Gui.Enabled = false
end

function StatsPanelGui.supercede()
	if not StatsPanelGui.Open then
		return
	end
	Gui.Enabled = false
end

local function _init()
	Gui.Parent = Player:WaitForChild("PlayerGui")
	applyPlacement()
end
_init()

function StatsPanelGui.start()
	PlatformController.DominantControlSchemeChanged:Add(function()
		applyPlacement()
	end)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTextSizes)
	updateTextSizes()

	tabButton.Activated:Connect(StatsPanelGui.toggle)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent or input.KeyCode ~= Enum.KeyCode.Tab then
			return
		end
		StatsPanelGui.toggle()
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(markDirty)

	RunService.Heartbeat:Connect(function()
		if dirty and os.clock() - lastRebuildAt >= REFRESH_INTERVAL then
			dirty = false
			lastRebuildAt = os.clock()
			rebuild()
		end
	end)

	StatsPanelGui.open()
end

return StatsPanelGui
