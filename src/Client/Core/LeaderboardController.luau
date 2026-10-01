--[[
	LeaderboardController

	Description:
	Draws the lobby leaderboards (T-032) on the physical boards in workspace.Lobby.Leaderboards.
	Each board has one SurfaceGui (in PlayerGui, adorned to the board part) with a CanvasGroup per
	period (Monthly / All-Time); they cross-fade every LeaderboardConstants.DisplaySwapInterval.
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

-- TODO: placeholder visuals; Sol to restyle (colours, fonts, layout)
local PIXELS_PER_STUD = 100
local MAX_DISTANCE = 200 -- // The boards aren't drawn beyond this many studs
local ROWS_PER_COLUMN = 15
local HEADER_HEIGHT = 0.16 -- // Fraction of the board height
local BACKGROUND_COLOR = Color3.fromRGB(20, 22, 35)
local ROW_COLOR = Color3.fromRGB(40, 44, 66)
local LOCAL_ROW_COLOR = Color3.fromRGB(60, 90, 160)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local RANK_COLORS = {
	[1] = Color3.fromRGB(255, 205, 60),
	[2] = Color3.fromRGB(200, 210, 225),
	[3] = Color3.fromRGB(215, 140, 80),
}
local FONT = Enum.Font.GothamBold

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type BoardGui = {
	Gui: SurfaceGui,
	Groups: { [string]: CanvasGroup },
	Lists: { [string]: Frame },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer

local boardGuis: { [string]: BoardGui } = {}
local shownPeriodIndex = 1

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

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

local function createRow(entry: LeaderboardConstants.Entry): Frame
	local row = Instance.new("Frame")
	row.Name = `Rank{entry.Rank}`
	row.LayoutOrder = entry.Rank
	row.BackgroundColor3 = if entry.UserId == localPlayer.UserId then LOCAL_ROW_COLOR else ROW_COLOR
	row.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = row

	local rank = createLabel("Rank", `#{entry.Rank}`, UDim2.fromScale(0.14, 0.8), UDim2.fromScale(0.01, 0.1))
	rank.TextColor3 = RANK_COLORS[entry.Rank] or TEXT_COLOR
	rank.Parent = row

	local headshot = Instance.new("ImageLabel")
	headshot.Name = "Headshot"
	headshot.BackgroundTransparency = 1
	headshot.Size = UDim2.fromScale(0.9, 0.9)
	headshot.SizeConstraint = Enum.SizeConstraint.RelativeYY
	headshot.Position = UDim2.fromScale(0.16, 0.05)
	headshot.Image = `rbxthumb://type=AvatarHeadShot&id={entry.UserId}&w=48&h=48`
	headshot.Parent = row

	createLabel("PlayerName", entry.DisplayName, UDim2.fromScale(0.48, 0.7), UDim2.fromScale(0.27, 0.15), Enum.TextXAlignment.Left).Parent = row
	createLabel("Value", tostring(entry.Value), UDim2.fromScale(0.22, 0.7), UDim2.fromScale(0.76, 0.15), Enum.TextXAlignment.Right).Parent = row

	return row
end

local function createPeriodGroup(board: { Title: string }, period: string): (CanvasGroup, Frame)
	local group = Instance.new("CanvasGroup")
	group.Name = period
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundColor3 = BACKGROUND_COLOR
	group.BorderSizePixel = 0

	local title = createLabel("Title", `{LeaderboardConstants.PeriodTitles[period]} {board.Title}`, UDim2.fromScale(0.9, HEADER_HEIGHT * 0.8), UDim2.fromScale(0.05, HEADER_HEIGHT * 0.1))
	title.Parent = group

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(0.96, 1 - HEADER_HEIGHT - 0.02)
	list.Position = UDim2.fromScale(0.02, HEADER_HEIGHT)
	list.Parent = group

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

	local boardGui: BoardGui = { Gui = gui, Groups = {}, Lists = {} }
	for i, period in LeaderboardConstants.Periods do
		local group, list = createPeriodGroup(board, period)
		local shown = i == shownPeriodIndex
		group.GroupTransparency = if shown then 0 else 1
		group.Visible = shown
		group.Parent = gui
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

local function fade(group: CanvasGroup, show: boolean)
	if show then
		group.Visible = true
	end
	local tween = TweenService:Create(group, TweenInfo.new(LeaderboardConstants.FadeDuration), {
		GroupTransparency = if show then 0 else 1,
	})
	tween.Completed:Once(function(state)
		-- // Hidden groups don't need to be drawn
		if not show and state == Enum.PlaybackState.Completed then
			group.Visible = false
		end
	end)
	tween:Play()
end

local function swapPeriods()
	local periods = LeaderboardConstants.Periods
	shownPeriodIndex = shownPeriodIndex % #periods + 1
	for _, boardGui in boardGuis do
		for i, period in periods do
			fade(boardGui.Groups[period], i == shownPeriodIndex)
		end
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
end

function LeaderboardController.start()
	task.spawn(watchBoardParts)
	task.spawn(function()
		applyData(SimpleRemotes.getFunction("GetLeaderboards"):InvokeServer())
	end)
	task.spawn(function()
		while true do
			task.wait(LeaderboardConstants.DisplaySwapInterval)
			swapPeriods()
		end
	end)
end

return LeaderboardController
