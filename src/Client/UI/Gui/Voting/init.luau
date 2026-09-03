local VotingGui = {}
VotingGui.Type = "HUD"
VotingGui.Open = false

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

local VoteContainer = Gui:WaitForChild("VoteContainer") :: Frame
local OptionAButton = VoteContainer:WaitForChild("OptionA") :: TextButton
local OptionBButton = VoteContainer:WaitForChild("OptionB") :: TextButton
local OptionACount = OptionAButton:WaitForChild("VoteCount") :: TextLabel
local OptionBCount = OptionBButton:WaitForChild("VoteCount") :: TextLabel

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getGamemodeDisplayName(gamemodeId: string?): string
	if gamemodeId and Gamemodes[gamemodeId] then
		return Gamemodes[gamemodeId].Display or gamemodeId
	end
	return gamemodeId or ""
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

	OptionAButton.TextLabel.Text = getGamemodeDisplayName(options[1])
	OptionBButton.TextLabel.Text = getGamemodeDisplayName(options[2])
	OptionACount.Text = tostring(voteCount[1] or 0)
	OptionBCount.Text = tostring(voteCount[2] or 0)
	VotingGui.open()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function VotingGui.open()
	VotingGui.Open = true
	Gui.Enabled = true
end

function VotingGui.close(_instant: boolean?)
	VotingGui.Open = false
	Gui.Enabled = false
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	Gui.Parent = Player.PlayerGui
	Gui.Enabled = false

	OptionAButton.Activated:Connect(function()
		SimpleRemotes.getEvent("VoteUpdated"):FireServer(1)
	end)

	OptionBButton.Activated:Connect(function()
		SimpleRemotes.getEvent("VoteUpdated"):FireServer(2)
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
