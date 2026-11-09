--[[
	GamemodeHud

	In-round HUD: one line of text in the topbar row showing the gamemode and time left ("Team Elimination • 01:24").
	Shown while a round is running; hidden while a menu supersedes it.

	The previous banner HUD is kept for reference in LegacyBannerHud.luau.
]]

local GamemodeHudGui = {}
GamemodeHudGui.Type = "HUD"
GamemodeHudGui.Open = false
GamemodeHudGui.SupercededBy = {}

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = game:GetService("Players").LocalPlayer

local Gamemodes = require(ReplicatedStorage.Shared.Constants.Gamemodes)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FONT = Enum.Font.FredokaOne -- // Same as the topbar
local TEXT_COLOR = Color3.new(1, 1, 1)
local OUTLINE_COLOR = Color3.new(0, 0, 0)
local OUTLINE_THICKNESS = 2.5
local TEXT_HEIGHT_SCALE = 0.75 -- // Text height as a share of the topbar row height
local TEXT_WIDTH_SCALE = 0.4 -- // Max text width as a share of the screen (long names shrink to fit)
local SEPARATOR = " • "

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local Gui: ScreenGui
local Label: TextLabel

local gamemodeText = ""
local timerText = ""
local shownWholeSeconds: number?
local countdownConnection: RBXScriptConnection?
local isSuperceded = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Centers the label on the screen and vertically in the topbar row (GuiService.TopbarInset)
local function placeLabel()
	local topbar = GuiService.TopbarInset
	local rowHeight = topbar.Height
	Label.Position = UDim2.fromOffset(0, topbar.Min.Y + rowHeight / 2) + UDim2.fromScale(0.5, 0)
	Label.Size = UDim2.new(TEXT_WIDTH_SCALE, 0, 0, rowHeight * TEXT_HEIGHT_SCALE)
end

local function render()
	if gamemodeText ~= "" and timerText ~= "" then
		Label.Text = gamemodeText .. SEPARATOR .. timerText
	else
		Label.Text = gamemodeText .. timerText
	end
end

local function stopCountdown()
	if countdownConnection then
		countdownConnection:Disconnect()
		countdownConnection = nil
	end
	shownWholeSeconds = nil
end

local function updateTimer()
	local currentTimerEndsAt = GameStateLibrary.getGameStateData().CurrentTimerEndsAt:Get()
	if typeof(currentTimerEndsAt) ~= "number" then
		return
	end

	local secondsLeft = math.max(0, currentTimerEndsAt - workspace:GetServerTimeNow())
	local wholeSeconds = math.ceil(secondsLeft)
	if shownWholeSeconds ~= wholeSeconds then
		shownWholeSeconds = wholeSeconds
		timerText = string.format("%02d:%02d", wholeSeconds // 60, wholeSeconds % 60)
		render()
	end

	if secondsLeft <= 0 then
		stopCountdown()
	end
end

-- // `fallbackText` replaces the countdown when the round has no timer
local function startCountdown(fallbackText: string)
	stopCountdown()
	if typeof(GameStateLibrary.getGameStateData().CurrentTimerEndsAt:Get()) ~= "number" then
		timerText = fallbackText
		render()
		return
	end

	updateTimer()
	countdownConnection = RunService.Heartbeat:Connect(updateTimer)
end

local function applyRoundUi()
	local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
	local gamemodeName = if currentRoundData then currentRoundData.Gamemode else nil
	local gamemodeData = gamemodeName and Gamemodes[gamemodeName] or nil
	if gamemodeData and gamemodeName then
		gamemodeText = string.gsub(gamemodeData.Display or gamemodeName, "\n", " ")
		startCountdown(gamemodeData.Timer or "")
		return
	end

	gamemodeText = ""
	startCountdown("")
end

local function refreshUiFromGameState()
	if GameStateLibrary.getGameStateData().CurrentRoundData:Get() == nil then
		GamemodeHudGui.close()
		stopCountdown()
		gamemodeText, timerText = "", ""
		render()
		return
	end

	GamemodeHudGui.open()
	applyRoundUi()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GamemodeHudGui.open()
	if GamemodeHudGui.Open and not isSuperceded then
		return
	end

	GamemodeHudGui.Open = true
	if #GamemodeHudGui.SupercededBy > 0 then
		isSuperceded = true
		return
	end

	isSuperceded = false
	Gui.Enabled = true
end

function GamemodeHudGui.close(_instant: boolean?)
	if not GamemodeHudGui.Open and not Gui.Enabled then
		return
	end

	GamemodeHudGui.Open = false
	isSuperceded = false
	Gui.Enabled = false
end

function GamemodeHudGui.supercede()
	if not GamemodeHudGui.Open then
		return
	end

	isSuperceded = true
	Gui.Enabled = false
end

-- // The label sits in the topbar row, which the camera already leaves clear
function GamemodeHudGui.getCameraPadding(): number
	return 0
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	Gui = Instance.new("ScreenGui")
	Gui.Name = "GamemodeHud"
	Gui.ResetOnSpawn = false
	Gui.ScreenInsets = Enum.ScreenInsets.None -- // Positioned by placeLabel
	Gui.DisplayOrder = 10 -- // Same as the topbar
	Gui.Enabled = false

	Label = Instance.new("TextLabel")
	Label.Name = "GamemodeTimer"
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.BackgroundTransparency = 1
	Label.Font = FONT
	Label.TextScaled = true
	Label.TextColor3 = TEXT_COLOR
	Label.Text = ""
	Label.Parent = Gui

	local outline = Instance.new("UIStroke")
	outline.Color = OUTLINE_COLOR
	outline.Thickness = OUTLINE_THICKNESS
	outline.Parent = Label

	placeLabel()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeLabel)

	Gui.Parent = Player.PlayerGui
end
_init()

function GamemodeHudGui.start()
	GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(_snapshot, _reason)
		refreshUiFromGameState()
	end)
	refreshUiFromGameState()
end

return GamemodeHudGui
