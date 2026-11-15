--[[
	PendingPlayers

	Description:
	Shown in the lobby while the server waits for enough players to start (GameplayPhase PendingPlayers): the red results
	ribbon with "Waiting for players" and, under it, how many are here out of how many are needed ("1 / 2 players",
	GlobalConfig.PlayersRequiredToStart). The count updates as players join and leave.
	Looks: the results ribbon (ClientArt/Assets.RoundResults.Ribbon) and the menus' cream lettering (ClientArt/Kit).
]]

local PendingPlayersGui = {}
PendingPlayersGui.Type = "HUD"
PendingPlayersGui.Open = false

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).RoundResults

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Same scaling as the results and death screen: a 900 px wide canvas scaled with the screen (reference 1280 x 720)
local CANVAS_WIDTH = 900
local REFERENCE = Vector2.new(1280, 720)
local MIN_SCALE, MAX_SCALE = 0.55, 1.6
local SHOWN_Y = 0.3
local RIBBON = Vector2.new(520, 130) -- // The 725 x 164 ribbon art, wider than the results' one for the longer title
local RIBBON_TEXT = { 78, 26, 364, 66 } -- // Same proportions as the results' title box
local TEXT_SIZE = { Ribbon = 52, Count = 40 }

local SLIDE_IN = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local gui: ScreenGui
local holder: Frame
local fitScale: UIScale
local countLabel: Frame
local activeTween: Tween?
local closeId = 0
local lastRegisteredGameplayPhase = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Cream lettering with a dark outline (Kit.label), shrunk to fit its box
local function outlined(name: string, size: number, parent: Instance, props: { [string]: any }): Frame
	local label = Kit.label("", size, { Name = name, Parent = parent })
	for key, value in props do
		(label :: any)[key] = value
	end
	for _, layer in label:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextScaled = true
			layer.TextWrapped = true
			Kit.create("UITextSizeConstraint", { MaxTextSize = size, Parent = layer })
		end
	end
	return label
end

-- // Only players who aren't AFK count, like the server's PlayersRequiredToStart check (RoundCyclingService)
local OPTED_OUT_ATTRIBUTE = "OptedOut" -- // On the Player, set by PlayerSessionService (the lobby's AFK toggle)

local function updateCount()
	if countLabel then
		local active = 0
		for _, other in Players:GetPlayers() do
			if other:GetAttribute(OPTED_OUT_ATTRIBUTE) ~= true then
				active += 1
			end
		end
		Kit.setText(countLabel, `{active} / {GlobalConfig.PlayersRequiredToStart} players`)
	end
end

local function rescale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else REFERENCE
	fitScale.Scale = math.clamp(math.min(viewport.X / REFERENCE.X, viewport.Y / REFERENCE.Y), MIN_SCALE, MAX_SCALE)
end

local function slide(info: TweenInfo, goal: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(holder, info, { Position = goal })
	activeTween:Play()
end

local function build()
	gui = Kit.create("ScreenGui", {
		Name = "PendingPlayers",
		Enabled = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	holder = Kit.create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, -1, 0),
		Size = UDim2.fromOffset(CANVAS_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, {
		Kit.create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})
	fitScale = Kit.create("UIScale", { Parent = holder })

	local ribbon = Kit.create("ImageLabel", {
		Name = "Ribbon",
		BackgroundTransparency = 1,
		Image = Art.Ribbon,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(RIBBON.X, RIBBON.Y),
		Parent = holder,
	})
	local title = outlined("Title", TEXT_SIZE.Ribbon, ribbon, {
		Position = UDim2.fromOffset(RIBBON_TEXT[1], RIBBON_TEXT[2]),
		Size = UDim2.fromOffset(RIBBON_TEXT[3], RIBBON_TEXT[4]),
		ZIndex = 2,
	})
	Kit.setText(title, "Waiting for players")
	countLabel = outlined("Count", TEXT_SIZE.Count, holder, { LayoutOrder = 2, Size = UDim2.fromOffset(CANVAS_WIDTH, 50) })
	updateCount()

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
	if gameplayPhase == GameplayPhases.PendingPlayers then
		PendingPlayersGui.open()
	elseif PendingPlayersGui.Open then
		PendingPlayersGui.close()
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PendingPlayersGui.open()
	updateCount()
	if PendingPlayersGui.Open then
		return
	end
	PendingPlayersGui.Open = true
	closeId += 1
	rescale()
	gui.Enabled = true
	holder.Position = UDim2.new(0.5, 0, -1, 0)
	slide(SLIDE_IN, UDim2.fromScale(0.5, SHOWN_Y))
end

function PendingPlayersGui.close(_instant: boolean?)
	PendingPlayersGui.Open = false
	closeId += 1
	local thisClose = closeId
	slide(SLIDE_OUT, UDim2.new(0.5, 0, -1, 0))
	task.delay(SLIDE_OUT.Time, function()
		if closeId == thisClose then
			gui.Enabled = false
		end
	end)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	build()
	-- // PlayerRemoving fires before the player leaves the list, so count on the next frame
	local function watch(other: Player)
		other:GetAttributeChangedSignal(OPTED_OUT_ATTRIBUTE):Connect(updateCount)
		updateCount()
	end
	Players.PlayerAdded:Connect(watch)
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerRemoving:Connect(function()
		task.defer(updateCount)
	end)
end
_init()

function PendingPlayersGui.start()
	if GameStateLibrary.HasSyncedState then
		registerGameplayPhase(GameStateLibrary.getSnapshot())
	end
	GameStateLibrary.GameStateSnapshotLoadedTasks:Add(registerGameplayPhase)
end

return PendingPlayersGui
