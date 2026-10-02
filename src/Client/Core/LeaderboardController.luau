--[[
	LeaderboardController

	Description:
	Draws the lobby leaderboards (T-032) on the physical boards in workspace.Lobby.Leaderboards.
	Each board has one SurfaceGui (in PlayerGui, adorned to the board part): a static background, and one
	CanvasGroup ("Fader") holding each period's title and entries (Monthly / All-Time). Every
	LeaderboardConstants.DisplaySwapInterval the Fader fades out, swaps period and fades back in (T-053).
	Entries come from LeaderboardService.
]]

local LeaderboardController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LeaderboardConstants = require(ReplicatedStorage.Shared.Constants.LeaderboardConstants)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Visuals match the Shop GUI: wooden frame, parchment panel, tan cards with brown outlines,
-- // dark brown FredokaOne text, lime-green chips with outlined white text, purple accent
local PIXELS_PER_STUD = 100
local MAX_DISTANCE = 200 -- // The boards aren't drawn beyond this many studs
local ROWS_PER_COLUMN = 15
local HEADER_HEIGHT = 0.16 -- // Fraction of the board height
local FRAME_COLOR = Color3.fromRGB(110, 60, 30) -- // Wooden frame
local FRAME_STROKE_COLOR = Color3.fromRGB(62, 32, 14)
local BANNER_COLOR = Color3.fromRGB(233, 185, 127) -- // Like the shop's Weapons / Skins tabs
local PANEL_COLOR = Color3.fromRGB(220, 168, 110) -- // Parchment
local OUTLINE_COLOR = Color3.fromRGB(110, 66, 34) -- // Card / panel outlines
local ROW_COLOR = Color3.fromRGB(240, 200, 150) -- // Item cards
local LOCAL_ROW_COLOR = Color3.fromRGB(190, 150, 235) -- // Purple corner-bracket accent
local TEXT_COLOR = Color3.fromRGB(64, 38, 20) -- // Dark brown, as the item names
local CHIP_STROKE_COLOR = Color3.fromRGB(66, 92, 14)
local CHIP_GRADIENT = ColorSequence.new(Color3.fromRGB(122, 168, 30), Color3.fromRGB(170, 212, 50)) -- // Price buttons
local OUTLINED_TEXT_STROKE_COLOR = Color3.fromRGB(40, 24, 12)
local RANK_COLORS = { -- // Top 3 get outlined coloured text, like "SALE!"
	[1] = Color3.fromRGB(255, 230, 40),
	[2] = Color3.fromRGB(235, 235, 245),
	[3] = Color3.fromRGB(240, 150, 70),
}
local FONT = Enum.Font.FredokaOne
local BANNER_SIZE = UDim2.fromScale(0.94, HEADER_HEIGHT * 0.86)
local BANNER_POSITION = UDim2.fromScale(0.03, HEADER_HEIGHT * 0.1)
local PANEL_SIZE = UDim2.fromScale(0.96, 1 - HEADER_HEIGHT - 0.03)
local PANEL_POSITION = UDim2.fromScale(0.02, HEADER_HEIGHT + 0.01)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type BoardGui = {
	Gui: SurfaceGui,
	Fader: CanvasGroup,
	Groups: { [string]: Frame },
	Lists: { [string]: Frame },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer

local boardGuis: { [string]: BoardGui } = {}
local shownPeriodIndex = 1
local swapCount = 0 -- // Lets a fade that was overtaken by a newer swap stop early
local nextSwapTime = 0

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function addOutline(label: TextLabel, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = label
end

local function createLabel(name: string, text: string, size: UDim2, position: UDim2, alignment: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = TEXT_COLOR
	label.Font = FONT
	label.TextScaled = true
	label.TextXAlignment = alignment or Enum.TextXAlignment.Center
	return label
end

local function addCorner(parent: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function addBorder(parent: GuiObject, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function addGradient(parent: GuiObject, color: ColorSequence)
	local gradient = Instance.new("UIGradient")
	gradient.Color = color
	gradient.Rotation = -90 -- // First colour at the bottom
	gradient.Parent = parent
end

local function createRow(entry: LeaderboardConstants.Entry): Frame
	local row = Instance.new("Frame")
	row.Name = `Rank{entry.Rank}`
	row.LayoutOrder = entry.Rank
	row.BackgroundColor3 = if entry.UserId == localPlayer.UserId then LOCAL_ROW_COLOR else ROW_COLOR
	row.BorderSizePixel = 0
	addCorner(row, UDim.new(0.25, 0))
	addBorder(row, OUTLINE_COLOR, 2)

	local rank = createLabel("Rank", `#{entry.Rank}`, UDim2.fromScale(0.14, 0.8), UDim2.fromScale(0.01, 0.1))
	local rankColor = RANK_COLORS[entry.Rank]
	if rankColor then
		rank.TextColor3 = rankColor
		addOutline(rank, OUTLINED_TEXT_STROKE_COLOR, 2)
	end
	rank.Parent = row

	local headshot = Instance.new("ImageLabel")
	headshot.Name = "Headshot"
	headshot.BackgroundTransparency = 1
	headshot.Size = UDim2.fromScale(0.9, 0.9)
	headshot.SizeConstraint = Enum.SizeConstraint.RelativeYY
	headshot.Position = UDim2.fromScale(0.16, 0.05)
	headshot.Image = `rbxthumb://type=AvatarHeadShot&id={entry.UserId}&w=48&h=48`
	headshot.Parent = row

	createLabel("PlayerName", entry.DisplayName, UDim2.fromScale(0.46, 0.7), UDim2.fromScale(0.27, 0.15), Enum.TextXAlignment.Left).Parent = row

	-- // Value in a lime-green chip, like the shop's price buttons
	local chip = Instance.new("Frame")
	chip.Name = "ValueChip"
	chip.BackgroundColor3 = Color3.new(1, 1, 1)
	chip.BorderSizePixel = 0
	chip.Size = UDim2.fromScale(0.24, 0.78)
	chip.Position = UDim2.fromScale(0.74, 0.11)
	addCorner(chip, UDim.new(0.3, 0))
	addBorder(chip, CHIP_STROKE_COLOR, 2)
	addGradient(chip, CHIP_GRADIENT)
	chip.Parent = row

	local value = createLabel("Value", tostring(entry.Value), UDim2.fromScale(0.86, 0.8), UDim2.fromScale(0.07, 0.1))
	value.TextColor3 = Color3.new(1, 1, 1)
	addOutline(value, CHIP_STROKE_COLOR, 2)
	value.Parent = chip

	return row
end

-- // Static board background: wooden frame, banner and parchment panel (the same for every period)
local function createBoardFrame(): Frame
	local root = Instance.new("Frame")
	root.Name = "Board"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = FRAME_COLOR
	root.BorderSizePixel = 0
	addCorner(root, UDim.new(0.04, 0))
	addBorder(root, FRAME_STROKE_COLOR, 8)

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.BackgroundColor3 = BANNER_COLOR
	banner.BorderSizePixel = 0
	banner.Size = BANNER_SIZE
	banner.Position = BANNER_POSITION
	addCorner(banner, UDim.new(0.25, 0))
	addBorder(banner, OUTLINE_COLOR, 4)
	banner.Parent = root

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BorderSizePixel = 0
	panel.Size = PANEL_SIZE
	panel.Position = PANEL_POSITION
	addCorner(panel, UDim.new(0.03, 0))
	addBorder(panel, OUTLINE_COLOR, 4)
	panel.Parent = root

	return root
end

-- // One period's contents (title + entries), laid over the static banner and panel. Lives inside the board's Fader.
local function createPeriodGroup(board: { Title: string }, period: string): (Frame, Frame)
	local group = Instance.new("Frame")
	group.Name = period
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1

	local titleArea = Instance.new("Frame")
	titleArea.Name = "TitleArea"
	titleArea.BackgroundTransparency = 1
	titleArea.Size = BANNER_SIZE
	titleArea.Position = BANNER_POSITION
	titleArea.Parent = group

	local title = createLabel("Title", `{LeaderboardConstants.PeriodTitles[period]} {board.Title}`, UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1))
	title.Parent = titleArea

	local listArea = Instance.new("Frame")
	listArea.Name = "ListArea"
	listArea.BackgroundTransparency = 1
	listArea.Size = PANEL_SIZE
	listArea.Position = PANEL_POSITION
	listArea.Parent = group

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(0.97, 0.96)
	list.Position = UDim2.fromScale(0.015, 0.02)
	list.Parent = listArea

	-- // Two columns of ROWS_PER_COLUMN, filled top to bottom
	local grid = Instance.new("UIGridLayout")
	grid.FillDirection = Enum.FillDirection.Vertical
	grid.FillDirectionMaxCells = ROWS_PER_COLUMN
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellSize = UDim2.new(0.5, -6, 1 / ROWS_PER_COLUMN, -4)
	grid.CellPadding = UDim2.fromOffset(6, 4)
	grid.Parent = list

	local empty = createLabel("Empty", "No entries yet", UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.1, 0.45))
	empty.Visible = false
	empty.Parent = group

	return group, list
end

local function createBoardGui(boardId: string, board: { Title: string, Face: Enum.NormalId }): BoardGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = `Leaderboard_{boardId}`
	gui.Face = board.Face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.MaxDistance = MAX_DISTANCE
	gui.ResetOnSpawn = false

	createBoardFrame().Parent = gui

	-- // A single CanvasGroup per board, holding only what changes between periods. Fading it out, swapping the
	-- // period and fading it back in halves CanvasGroup texture memory (was one per period): when that budget runs out, Roblox
	-- // draws CanvasGroups as plain frames and GroupTransparency stops working (the swap then looks instant).
	local fader = Instance.new("CanvasGroup")
	fader.Name = "Fader"
	fader.Size = UDim2.fromScale(1, 1)
	fader.BackgroundTransparency = 1
	fader.BorderSizePixel = 0
	fader.ZIndex = 2
	fader.Parent = gui

	local boardGui: BoardGui = { Gui = gui, Fader = fader, Groups = {}, Lists = {} }
	for i, period in LeaderboardConstants.Periods do
		local group, list = createPeriodGroup(board, period)
		group.Visible = i == shownPeriodIndex
		group.Parent = fader
		boardGui.Groups[period] = group
		boardGui.Lists[period] = list
	end

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return boardGui
end

local function renderEntries(boardGui: BoardGui, period: string, entries: { LeaderboardConstants.Entry }?)
	local list = boardGui.Lists[period]
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, entry in entries or {} do
		createRow(entry).Parent = list
	end
	local empty = boardGui.Groups[period]:FindFirstChild("Empty") :: TextLabel
	empty.Visible = not entries or #entries == 0
end

local function applyData(data: LeaderboardConstants.LeaderboardData)
	for boardId, boardGui in boardGuis do
		local boardData = data[boardId] or {}
		for _, period in LeaderboardConstants.Periods do
			renderEntries(boardGui, period, boardData[period])
		end
	end
end

local function tweenFader(fader: CanvasGroup, transparency: number): Tween
	local tween = TweenService:Create(fader, TweenInfo.new(LeaderboardConstants.FadeDuration / 2, Enum.EasingStyle.Sine), {
		GroupTransparency = transparency,
	})
	tween:Play()
	return tween
end

-- // Fade each board's contents out, show the next period, then fade back in
local function swapPeriods()
	local periods = LeaderboardConstants.Periods
	shownPeriodIndex = shownPeriodIndex % #periods + 1
	swapCount += 1
	nextSwapTime = os.clock() + LeaderboardConstants.DisplaySwapInterval
	local thisSwap = swapCount
	for _, boardGui in boardGuis do
		task.spawn(function()
			local fadeOut = tweenFader(boardGui.Fader, 1)
			if fadeOut.PlaybackState ~= Enum.PlaybackState.Completed then
				fadeOut.Completed:Wait()
			end
			if thisSwap ~= swapCount then
				return -- // A newer swap (e.g. from Cmdr) took over this board's fade
			end
			for i, period in periods do
				boardGui.Groups[period].Visible = i == shownPeriodIndex
			end
			tweenFader(boardGui.Fader, 0)
		end)
	end
end

-- // The board parts can stream in and out (StreamingEnabled), so re-adorn whenever one appears
local function watchBoardParts()
	local folder = workspace:WaitForChild("Lobby"):WaitForChild("Leaderboards")
	local function adorn(child: Instance)
		local boardGui = boardGuis[child.Name]
		if boardGui and child:IsA("BasePart") then
			boardGui.Gui.Adornee = child
		end
	end
	for _, child in folder:GetChildren() do
		adorn(child)
	end
	folder.ChildAdded:Connect(adorn)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LeaderboardController.init()
	for boardId, board in LeaderboardConstants.Boards do
		boardGuis[boardId] = createBoardGui(boardId, board)
	end
	SimpleRemotes.getEvent("LeaderboardsUpdated").OnClientEvent:Connect(applyData)
	SimpleRemotes.getEvent("SwapLeaderboardPeriods").OnClientEvent:Connect(swapPeriods)
end

function LeaderboardController.start()
	task.spawn(watchBoardParts)
	task.spawn(function()
		applyData(SimpleRemotes.getFunction("GetLeaderboards"):InvokeServer())
	end)
	task.spawn(function()
		-- // A swap (timed or from Cmdr) pushes nextSwapTime back, so each period always shows for the full interval
		nextSwapTime = os.clock() + LeaderboardConstants.DisplaySwapInterval
		while true do
			local remaining = nextSwapTime - os.clock()
			if remaining > 0 then
				task.wait(remaining)
			else
				swapPeriods()
			end
		end
	end)
end

return LeaderboardController
