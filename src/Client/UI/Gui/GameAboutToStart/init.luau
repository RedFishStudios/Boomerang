--[[
	GameAboutToStart

	Description:
	Shown in the middle of the screen during the short pause between voting and the round (GameplayPhases.LobbyEnded):
	"New round in" with the seconds left beneath it, in double-size lettering. Each time the number changes it pops:
	it springs up large, then settles back to its normal size. Closes when the round starts.
	Looks: only text, in the menus' cream lettering with a dark outline (ClientArt/Kit), like the other floating text
	(PendingPlayers, the end-of-round results). Laid out on a canvas scaled with the screen.
]]

local GameAboutToStartGui = {}
GameAboutToStartGui.Type = "HUD"
GameAboutToStartGui.Open = false

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Same scaling as the other floating text: a 900 px wide canvas scaled with the screen (reference 1280 x 720)
local CANVAS_WIDTH = 900
local REFERENCE = Vector2.new(1280, 720)
local MIN_SCALE, MAX_SCALE = 0.55, 1.6
local TITLE_TEXT = "New round in"
local TEXT_SIZE = { Title = 48, Number = 96 } -- // The number is double the title (Sol, 2026-11-15)
local TITLE_HEIGHT = 60
local NUMBER_HEIGHT = 120

-- // The pop on each new second: quickly up to POP_SCALE, then back down to normal
local POP_SCALE = 1.8
local POP_UP = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_DOWN = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local gui: ScreenGui
local holder: Frame
local fitScale: UIScale
local numberLabel: Frame
local numberScale: UIScale
local countdownConnection: RBXScriptConnection?
local shownSeconds: number? = nil
local popTween: Tween?
local lastRegisteredGameplayPhase = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Cream lettering with a dark outline (Kit.label), shrunk to fit its box
-- // Centred on `centreY` (canvas pixels), so the number's pop grows evenly from its middle
local function outlined(name: string, size: number, height: number, centreY: number): Frame
	local label = Kit.label("", size, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, centreY),
		Size = UDim2.fromOffset(CANVAS_WIDTH, height),
		Parent = holder,
	})
	for _, layer in label:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextScaled = true
			Kit.create("UITextSizeConstraint", { MaxTextSize = size, Parent = layer })
		end
	end
	return label
end

local function rescale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else REFERENCE
	fitScale.Scale = math.clamp(math.min(viewport.X / REFERENCE.X, viewport.Y / REFERENCE.Y), MIN_SCALE, MAX_SCALE)
end

-- // Springs the number up large, then settles it back to its normal size
local function pop()
	if popTween then
		popTween:Cancel()
	end
	numberScale.Scale = 1
	local up = TweenService:Create(numberScale, POP_UP, { Scale = POP_SCALE })
	popTween = up
	up.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			return
		end
		local down = TweenService:Create(numberScale, POP_DOWN, { Scale = 1 })
		popTween = down
		down:Play()
	end)
	up:Play()
end

-- // Whole seconds left on the pause before the round (GameStateLibrary.CurrentTimerEndsAt); pops on each change
local function updateCountdown()
	local endsAt = GameStateLibrary.getGameStateData().CurrentTimerEndsAt:Get()
	if not endsAt then
		return
	end
	local seconds = math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))
	if seconds ~= shownSeconds then
		shownSeconds = seconds
		Kit.setText(numberLabel, tostring(seconds))
		pop()
	end
end

local function build()
	gui = Kit.create("ScreenGui", {
		Name = "GameAboutToStart",
		Enabled = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	holder = Kit.create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CANVAS_WIDTH, TITLE_HEIGHT + NUMBER_HEIGHT),
		Parent = gui,
	})
	fitScale = Kit.create("UIScale", { Parent = holder })

	local title = outlined("Title", TEXT_SIZE.Title, TITLE_HEIGHT, TITLE_HEIGHT / 2)
	Kit.setText(title, TITLE_TEXT)
	numberLabel = outlined("Number", TEXT_SIZE.Number, NUMBER_HEIGHT, TITLE_HEIGHT + NUMBER_HEIGHT / 2)
	numberScale = Kit.create("UIScale", { Parent = numberLabel })

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

local function registerGameplayPhase(snapshot)
	local gameplayPhase = snapshot.GameplayPhase
	if gameplayPhase == lastRegisteredGameplayPhase then
		return
	end
	lastRegisteredGameplayPhase = gameplayPhase
	if gameplayPhase == GameplayPhases.LobbyEnded then
		GameAboutToStartGui.open()
	elseif GameAboutToStartGui.Open then
		GameAboutToStartGui.close()
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GameAboutToStartGui.open()
	if GameAboutToStartGui.Open then
		return
	end
	GameAboutToStartGui.Open = true
	rescale()
	shownSeconds = nil
	gui.Enabled = true
	updateCountdown()
	countdownConnection = RunService.Heartbeat:Connect(updateCountdown)
end

function GameAboutToStartGui.close(_instant: boolean?)
	GameAboutToStartGui.Open = false
	if countdownConnection then
		countdownConnection:Disconnect()
		countdownConnection = nil
	end
	if popTween then
		popTween:Cancel()
		popTween = nil
	end
	gui.Enabled = false
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	build()
end
_init()

function GameAboutToStartGui.start()
	if GameStateLibrary.HasSyncedState then
		registerGameplayPhase(GameStateLibrary.getSnapshot())
	end
	GameStateLibrary.GameStateSnapshotLoadedTasks:Add(registerGameplayPhase)
end

return GameAboutToStartGui
