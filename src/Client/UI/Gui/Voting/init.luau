local VotingGui = {}
VotingGui.Type = "HUD"
VotingGui.Open = false

local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedMods = ReplicatedStorage.Shared

local Gamemodes = require(SharedMods.Constants.Gamemodes)
local GameplayPhases = require(SharedMods.Constants.Enums.GameplayPhases)
local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
local SimpleRemotes = require(SharedMods.Networking.SimpleRemotes)

local Gui = script:WaitForChild("Voting") :: ScreenGui
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local Container = Gui:WaitForChild("Container") :: ImageLabel
local OptionAText = Container:WaitForChild("OptionAText") :: TextLabel
local OptionBText = Container:WaitForChild("OptionBText") :: TextLabel
local OptionAButton = Container:WaitForChild("OptionA") :: ImageButton
local OptionBButton = Container:WaitForChild("OptionB") :: ImageButton
local ExitButton = Container:WaitForChild("Exit") :: ImageButton
local OptionACount = Container:WaitForChild("OptionACount"):WaitForChild("TextLabel") :: TextLabel
local OptionBCount = Container:WaitForChild("OptionBCount"):WaitForChild("TextLabel") :: TextLabel

-- // Animation Values // --

local containerGoalPosition = Container.Position
local containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)
local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local instanceKey = nil
local activeTween = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getGamemodeDisplayName(gamemodeId: string?): string
	if gamemodeId and Gamemodes[gamemodeId] then
		return Gamemodes[gamemodeId].Display or gamemodeId
	end
	return gamemodeId or ""
end

local function updateOptionTextSize(textLabel: TextLabel)
	textLabel.TextScaled = false
	textLabel.TextSize = textLabel.AbsoluteSize.Y / 2
end

local function updateOptionTextSizes()
	updateOptionTextSize(OptionAText)
	updateOptionTextSize(OptionBText)
end

local function playContainerTween(tweenInfo: TweenInfo, goalPosition: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(Container, tweenInfo, { Position = goalPosition })
	activeTween:Play()
end

local BUTTON_HOVER_SCALE = 1.05
local BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setupButtonHover(button: GuiButton)
	local defaultSize = button.Size
	local hoverSize = UDim2.new(
		defaultSize.X.Scale * BUTTON_HOVER_SCALE,
		defaultSize.X.Offset * BUTTON_HOVER_SCALE,
		defaultSize.Y.Scale * BUTTON_HOVER_SCALE,
		defaultSize.Y.Offset * BUTTON_HOVER_SCALE
	)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, BUTTON_HOVER_TWEEN_INFO, { Size = hoverSize }):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, BUTTON_HOVER_TWEEN_INFO, { Size = defaultSize }):Play()
	end)
end

local function refreshUi(snapshot)
	local intermissionData = snapshot.IntermissionData
	local isVoting = snapshot.GameplayPhase == GameplayPhases.LobbyVoting
	local options = intermissionData and intermissionData.VoteOptions
	local voteCount = intermissionData and intermissionData.VoteCount

	if not isVoting or not options or not voteCount or #options < 2 then
		VotingGui.close()
		return
	end

	OptionAText.Text = getGamemodeDisplayName(options[1])
	OptionBText.Text = getGamemodeDisplayName(options[2])
	OptionACount.Text = tostring(voteCount[1] or 0)
	OptionBCount.Text = tostring(voteCount[2] or 0)
	VotingGui.open()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function VotingGui.open()
	if VotingGui.Open then
		updateOptionTextSizes()
		return
	end

	VotingGui.Open = true
	instanceKey = math.random(10000)
	Gui.Enabled = true
	updateOptionTextSizes()

	Container.Position = containerOffscreenPosition
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
end

function VotingGui.close(instant: boolean?)
	if not VotingGui.Open and not Gui.Enabled then
		return
	end

	VotingGui.Open = false
	local thisInstance = math.random(10000)
	instanceKey = thisInstance
	if instant then
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end
		Container.Position = containerOffscreenPosition
		Gui.Enabled = false
		return
	end

	playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
	task.spawn(function()
		task.wait(.6)
		if instanceKey == thisInstance then
			Gui.Enabled = false
		end
	end)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	Gui.Parent = Player.PlayerGui
	Gui.Enabled = false
	OptionAText.TextScaled = false
	OptionBText.TextScaled = false

	setupButtonHover(OptionAButton)
	setupButtonHover(OptionBButton)
	setupButtonHover(ExitButton)

	OptionAButton.Activated:Connect(function()
		SimpleRemotes.getEvent("VoteUpdated"):FireServer(1)
	end)

	OptionBButton.Activated:Connect(function()
		SimpleRemotes.getEvent("VoteUpdated"):FireServer(2)
	end)

	ExitButton.Activated:Connect(function()
		VotingGui.close()
	end)
end
_init()

function VotingGui.start()
	GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(snapshot, _reason)
      refreshUi(snapshot)
   end)
   refreshUi(GameStateLibrary.getSnapshot())
end

return VotingGui

