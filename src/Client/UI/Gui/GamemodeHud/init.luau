--[[
	GamemodeHud

	In-round HUD: one line of text in the topbar row showing the gamemode and time left ("Team Elimination • 01:24"), on
	a straight red ribbon (ClientArt/Assets.GamemodeHud.Ribbon) that stretches sideways to fit the text (its curled ends
	keep their shape: 9-slice). Cream lettering with a dark outline, like the menus.
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

local TextService = game:GetService("TextService")

local Gamemodes = require(ReplicatedStorage.Shared.Constants.Gamemodes)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local RibbonArt = require(ReplicatedStorage.Client.UI.ClientArt.Assets).GamemodeHud
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FONT = Enum.Font.FredokaOne -- // Same as the topbar and menus
local TEXT_COLOR = Theme.Colors.Text
local OUTLINE_COLOR = Theme.Colors.Outline
local OUTLINE_THICKNESS = 2
local SEPARATOR = " • "

-- // The ribbon art (725 x 136): its curled ends stay unstretched; only the middle stretches to fit the text
local RIBBON_ART = Vector2.new(725, 136)
local RIBBON_SLICE = Rect.new(150, 0, 575, 136)
local RIBBON_HEIGHT_SCALE = 1.05 -- // Ribbon height as a share of the topbar row height
local TEXT_HEIGHT_SCALE = 0.5 -- // Text height as a share of the ribbon height (inside the red band)
local END_WIDTH_SCALE = 1.2 -- // Room for each curled end, as a share of the ribbon height
local MAX_WIDTH_SCALE = 0.6 -- // Widest the ribbon gets, as a share of the screen (longer text shrinks)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local Gui: ScreenGui
local Ribbon: ImageLabel
local Label: TextLabel

local gamemodeText = ""
local timerText = ""
local shownWholeSeconds: number?
local countdownConnection: RBXScriptConnection?
local isSuperceded = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Centers the ribbon on the screen and vertically in the topbar row (GuiService.TopbarInset), sized to its text
local function placeLabel()
	local topbar = GuiService.TopbarInset
	local rowHeight = topbar.Height
	local height = math.floor(rowHeight * RIBBON_HEIGHT_SCALE)
	local textHeight = math.floor(height * TEXT_HEIGHT_SCALE)
	-- // Measured with every digit as "0" so the ribbon doesn't change width as the timer ticks
	local measured = string.gsub(Label.Text, "%d", "0")
	local textWidth = TextService:GetTextSize(measured, textHeight, FONT, Vector2.new(math.huge, textHeight)).X
	local maxWidth = Gui.AbsoluteSize.X * MAX_WIDTH_SCALE
	local width = math.min(textWidth + height * END_WIDTH_SCALE * 2, maxWidth)
	width = math.max(width, height * RIBBON_ART.X / RIBBON_ART.Y * 0.6)

	Ribbon.Position = UDim2.fromOffset(0, topbar.Min.Y + rowHeight / 2) + UDim2.fromScale(0.5, 0)
	Ribbon.Size = UDim2.fromOffset(width, height)
	Ribbon.SliceScale = height / RIBBON_ART.Y
	Label.Size = UDim2.new(1, -height * END_WIDTH_SCALE * 2, 0, textHeight)
end

local function render()
	if gamemodeText ~= "" and timerText ~= "" then
		Label.Text = gamemodeText .. SEPARATOR .. timerText
	else
		Label.Text = gamemodeText .. timerText
	end
	placeLabel()
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

	Ribbon = Instance.new("ImageLabel")
	Ribbon.Name = "Ribbon"
	Ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	Ribbon.BackgroundTransparency = 1
	Ribbon.Image = RibbonArt.Ribbon
	Ribbon.ScaleType = Enum.ScaleType.Slice
	Ribbon.SliceCenter = RIBBON_SLICE
	Ribbon.Parent = Gui

	Label = Instance.new("TextLabel")
	Label.Name = "GamemodeTimer"
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Position = UDim2.fromScale(0.5, 0.47) -- // On the red band, between the gold rims
	Label.BackgroundTransparency = 1
	Label.Font = FONT
	Label.TextScaled = true
	Label.TextColor3 = TEXT_COLOR
	Label.Text = ""
	Label.ZIndex = 2
	Label.Parent = Ribbon

	local outline = Instance.new("UIStroke")
	outline.Color = OUTLINE_COLOR
	outline.Thickness = OUTLINE_THICKNESS
	outline.Parent = Label

	placeLabel()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeLabel)
	Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeLabel)

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
