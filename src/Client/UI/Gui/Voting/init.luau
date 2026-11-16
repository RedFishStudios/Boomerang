--[[
	Voting

	Description:
	The gamemode vote shown at the top of the screen while the lobby is voting (GameplayPhases.LobbyVoting). Two options from
	GameStateLibrary's IntermissionData (VoteOptions, VoteCount); clicking one sends VoteUpdated (1 or 2) to the server.
	Under the window floats "Voting ends in N", counting down the voting timer (CurrentTimerEndsAt).
	Looks: blank art in the style of the other new menus (ClientArt/Assets.VoteScreen; close button from the Quests menu),
	with every text drawn as instances (ClientArt/Kit). Laid out in the frame image's own pixels (CANVAS) and scaled to the
	screen.
]]

local VotingGui = {}
VotingGui.Type = "HUD"
VotingGui.Open = false
VotingGui.RequiresMouse = true -- // Frees the mouse in a locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Gamemodes = require(ReplicatedStorage.Shared.Constants.Gamemodes)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Assets = require(ReplicatedStorage.Client.UI.ClientArt.Assets)

local Art = Assets.VoteScreen
local CloseArt = Assets.QuestsScreen

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Layout in the frame art's pixels ({x, y, w, h})
local CANVAS = Vector2.new(1448, 720)
local TITLE = { 430, 40, 560, 88 } -- // On the ribbon
local TITLE_TEXT = "Vote for the next round!"
local CLOSE = { 1262, 50, 112, 110 }
local CLOSE_ICON_INSET = 0.22
local OPTIONS = { { 205, 184, 512, 424 }, { 733, 184, 512, 424 } } -- // The two panels (their raised face)
local OPTION_RADIUS = 30
local OPTION_TEXT = { 40, 60, 432, 304 } -- // Inside a panel
local BADGE = { 397, -50, 140, 140 } -- // Inside a panel: over its top-right corner
local BADGE_TEXT_INSET = 0.2
local TEXT_SIZE = { Title = 64, Option = 96, Count = 72, Countdown = 72 }
-- // "Voting ends in N", floating just under the window (in canvas pixels, so it slides and scales with it)
local COUNTDOWN = { 224, CANVAS.Y + 6, 1000, 96 }

-- // On screen: top centre, as wide as fits in these fractions of the screen
local SCREEN_WIDTH = 0.5
local SCREEN_HEIGHT = 0.36
local TOP_MARGIN = 0.02 -- // Fraction of screen height

local SLIDE_IN = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)
-- // Tuck: a slight wind-up downwards, then it shoots up and stops exactly in place (no overshoot at the end)
local TUCK = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local UNTUCK = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- // Back down smoothly

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local voteRemote = SimpleRemotes.getEvent("VoteUpdated")
local OPTED_OUT_ATTRIBUTE = "OptedOut" -- // On the Player, set by PlayerSessionService (the lobby's AFK toggle)

local gui: ScreenGui
local holder: Frame -- // Slides in and out
local fitScale: UIScale
local optionTexts: { Frame } = {}
local countTexts: { Frame } = {}
local activeTween: Tween?
local closeId = 0
local countdownText: Frame
local countdownConnection: RBXScriptConnection?
local shownSeconds: number? = nil
local tucked = false -- // Closed with the X: only the countdown shows (until voting ends)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function rect(r: { number }): (UDim2, UDim2)
	return UDim2.fromOffset(r[1], r[2]), UDim2.fromOffset(r[3], r[4])
end

-- // Cream lettering with a dark outline (Kit.label), wrapped and shrunk to fit its box
local function outlined(name: string, text: string, size: number, r: { number }, parent: Instance, zIndex: number?): Frame
	local label = Kit.label(text, size, { Name = name, ZIndex = zIndex or 2, Parent = parent })
	label.Position, label.Size = rect(r)
	for _, layer in label:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextWrapped = true
			layer.TextScaled = true
			layer.ZIndex += (zIndex or 2) - 1
			Kit.create("UITextSizeConstraint", { MaxTextSize = size, Parent = layer })
		end
	end
	return label
end

local function getGamemodeDisplayName(gamemodeId: string?): string
	if gamemodeId and Gamemodes[gamemodeId] then
		return Gamemodes[gamemodeId].Display or gamemodeId
	end
	return gamemodeId or ""
end

-- // Tucked away (the X button): the window slides up until only "Voting ends in N" is left on screen
local function tuckedPosition(): UDim2
	return UDim2.new(0.5, 0, TOP_MARGIN, -COUNTDOWN[2] * fitScale.Scale)
end

local function rescale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	fitScale.Scale = math.min(viewport.X * SCREEN_WIDTH / CANVAS.X, viewport.Y * SCREEN_HEIGHT / CANVAS.Y)
	if tucked and VotingGui.Open and holder then
		holder.Position = tuckedPosition() -- // Its offset depends on the scale
	end
end

local function shownPosition(): UDim2
	return UDim2.new(0.5, 0, TOP_MARGIN, 0)
end

local function hiddenPosition(): UDim2
	return UDim2.new(0.5, 0, -1, 0)
end

local function slide(info: TweenInfo, goal: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(holder, info, { Position = goal })
	activeTween:Play()
end

local function buildOption(index: number, root: Frame)
	local r = OPTIONS[index]
	local button = Kit.create("ImageButton", {
		Name = `Option{index}`,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = "",
		ZIndex = 2,
		Parent = root,
	})
	button.Position, button.Size = rect(r)
	-- // Lightens on hover, darkens on press, without changing size (the art is part of the window)
	Kit.pressable(button, { style = "surface", surface = { x = 0, y = 0, w = r[3], h = r[4], radius = OPTION_RADIUS } })
	button.Activated:Connect(function()
		voteRemote:FireServer(index)
		VotingGui.tuck() -- // Voting tucks the window away; tap the countdown to change the vote
	end)

	optionTexts[index] = outlined("Name", "", TEXT_SIZE.Option, OPTION_TEXT, button, 4)

	local badge = Kit.create("ImageLabel", {
		Name = "Badge",
		BackgroundTransparency = 1,
		Image = Art.Badge,
		ZIndex = 5,
		Parent = button,
	})
	badge.Position, badge.Size = rect(BADGE)
	local inset = BADGE[3] * BADGE_TEXT_INSET
	countTexts[index] = outlined("Count", "0", TEXT_SIZE.Count, { inset, inset, BADGE[3] - 2 * inset, BADGE[4] - 2 * inset }, badge, 6)
end

local function build()
	gui = Kit.create("ScreenGui", {
		Name = "Voting",
		Enabled = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	holder = Kit.create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = hiddenPosition(),
		Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
		Parent = gui,
	})
	fitScale = Kit.create("UIScale", { Parent = holder })
	local root = Kit.create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
		Parent = holder,
	})
	Kit.image("ImageLabel", Art.Window, 0, 0, CANVAS.X, CANVAS.Y, { Name = "Window", Parent = root })

	outlined("Title", TITLE_TEXT, TEXT_SIZE.Title, TITLE, root, 2)

	-- // Close button: the Quests menu's blank button + X icon
	local close = Kit.create("ImageButton", {
		Name = "Close",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = CloseArt.CloseBlank,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CLOSE[1] + CLOSE[3] / 2, CLOSE[2] + CLOSE[4] / 2),
		Size = UDim2.fromOffset(CLOSE[3], CLOSE[4]),
		ZIndex = 3,
		Parent = root,
	})
	Kit.create("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = CloseArt.IconClose,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromScale(CLOSE_ICON_INSET, CLOSE_ICON_INSET),
		Size = UDim2.fromScale(1 - 2 * CLOSE_ICON_INSET, 1 - 2 * CLOSE_ICON_INSET),
		ZIndex = 4,
		Parent = close,
	})
	Kit.pressable(close)
	close.Activated:Connect(function()
		VotingGui.tuck()
	end)

	for index in OPTIONS do
		buildOption(index, root)
	end

	countdownText = outlined("Countdown", "", TEXT_SIZE.Countdown, COUNTDOWN, root, 2)
	-- // Tapping the countdown while tucked brings the window back
	local reopen = Kit.create("TextButton", {
		Name = "CountdownButton",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = root,
	})
	reopen.Position, reopen.Size = rect(COUNTDOWN)
	reopen.Activated:Connect(function()
		VotingGui.untuck()
	end)

	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
		rescale()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- // "Voting ends in N": whole seconds left on the voting timer (GameStateLibrary.CurrentTimerEndsAt), counting down
-- // while the window is open
local function updateCountdown()
	local gameStateData = GameStateLibrary.getGameStateData()
	local endsAt = gameStateData.CurrentTimerEndsAt:Get()
	if not endsAt or gameStateData.GameplayPhase:Get() ~= GameplayPhases.LobbyVoting then
		return
	end
	local seconds = math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))
	if seconds ~= shownSeconds then
		shownSeconds = seconds
		Kit.setText(countdownText, `Voting ends in {seconds}`)
	end
end

local function setCountdownRunning(running: boolean)
	if running and not countdownConnection then
		shownSeconds = nil
		updateCountdown()
		countdownConnection = RunService.Heartbeat:Connect(updateCountdown)
	elseif not running and countdownConnection then
		countdownConnection:Disconnect()
		countdownConnection = nil
	end
end

local function refreshUi(snapshot)
	local intermissionData = snapshot.IntermissionData
	local isVoting = snapshot.GameplayPhase == GameplayPhases.LobbyVoting
	local options = intermissionData and intermissionData.VoteOptions
	local voteCount = intermissionData and intermissionData.VoteCount

	-- // AFK players (the lobby's AFK toggle) don't vote: the window stays hidden for them
	local isAfk = player:GetAttribute(OPTED_OUT_ATTRIBUTE) == true
	if not isVoting or isAfk or not options or not voteCount or #options < 2 then
		-- // Voting over: switched off at once, timer included (Sol, 2026-11-15: GameAboutToStart takes over); going AFK
		-- // mid-vote still slides it away
		VotingGui.close(not isVoting)
		return
	end

	for index = 1, 2 do
		Kit.setText(optionTexts[index], getGamemodeDisplayName(options[index]))
		Kit.setText(countTexts[index], tostring(voteCount[index] or 0))
	end
	VotingGui.open()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function VotingGui.open()
	if VotingGui.Open then
		return
	end
	VotingGui.Open = true
	tucked = false
	VotingGui.RequiresMouse = true
	setCountdownRunning(true)
	closeId += 1
	rescale()
	gui.Enabled = true
	holder.Position = hiddenPosition()
	slide(SLIDE_IN, shownPosition())
end

-- // The X button, or voting: slides the window up so only "Voting ends in N" stays on screen (wind-up, then no
-- // overshoot at the end). It stays tucked (vote count updates don't bring it back) and no longer frees the mouse, until the
-- // countdown is tapped (VotingGui.untuck) or voting ends.
function VotingGui.tuck()
	if not VotingGui.Open or tucked then
		return
	end
	tucked = true
	VotingGui.RequiresMouse = false
	slide(TUCK, tuckedPosition())
end

-- // Tapping the countdown while tucked: the whole window comes back, so the vote can be changed
function VotingGui.untuck()
	if not VotingGui.Open or not tucked then
		return
	end
	tucked = false
	VotingGui.RequiresMouse = true
	slide(UNTUCK, shownPosition())
end

function VotingGui.close(instant: boolean?)
	if not VotingGui.Open and not gui.Enabled then
		return
	end
	VotingGui.Open = false
	tucked = false
	VotingGui.RequiresMouse = true
	setCountdownRunning(false)
	closeId += 1
	local thisClose = closeId
	if instant then
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end
		holder.Position = hiddenPosition()
		gui.Enabled = false
		return
	end

	slide(SLIDE_OUT, hiddenPosition())
	task.delay(SLIDE_OUT.Time, function()
		if closeId == thisClose then
			gui.Enabled = false
		end
	end)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

build()

function VotingGui.start()
	GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(snapshot, _reason)
		refreshUi(snapshot)
	end)
	refreshUi(GameStateLibrary.getSnapshot())
	player:GetAttributeChangedSignal(OPTED_OUT_ATTRIBUTE):Connect(function()
		refreshUi(GameStateLibrary.getSnapshot())
	end)
end

return VotingGui
