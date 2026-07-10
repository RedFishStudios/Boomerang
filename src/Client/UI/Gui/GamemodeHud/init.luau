local GamemodeHudGui = {}
GamemodeHudGui.Type = "HUD"

local _TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = game:GetService("Players").LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientMods = ReplicatedStorage.Client
local SharedMods = ReplicatedStorage.Shared

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local Gamemodes = require(SharedMods.Constants.Gamemodes)
local _UIController = require(ClientMods.UI.UIController)
local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)

-- // Gui Values // --

local Gui = script:WaitForChild("Gamemode")
local countdownConnection: RBXScriptConnection?
local TimerLabel: TextLabel?
local shownWholeSeconds: number?

local GuiHeader: Frame?
local GamemodeLabel: TextLabel?
local SubheaderLabel: TextLabel?
local VoteContainer: Frame?
local OptionAButton: TextButton?
local OptionBButton: TextButton?
local OptionACount: TextLabel?
local OptionBCount: TextLabel?

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

local function stopCountdown()
   if countdownConnection then
      countdownConnection:Disconnect()
      countdownConnection = nil
   end
   shownWholeSeconds = nil
end

local function updateTimer()
   local currentTimerEndsAt = GameStateLibrary.getGameStateData().CurrentTimerEndsAt:Get()
   if not TimerLabel or not currentTimerEndsAt then
      return
   end

   local secondsLeft = math.max(0, currentTimerEndsAt - workspace:GetServerTimeNow())
   local wholeSeconds = math.ceil(secondsLeft)
   if shownWholeSeconds ~= wholeSeconds then
      shownWholeSeconds = wholeSeconds
      TimerLabel.Text = tostring(wholeSeconds)
   end

   if secondsLeft <= 0 then
      stopCountdown()
   end
end

local function startCountdown(fallbackText: string)
   stopCountdown()
   if not TimerLabel then
      return
   end

   if typeof(GameStateLibrary.getGameStateData().CurrentTimerEndsAt:Get()) ~= "number" then
      TimerLabel.Text = fallbackText
      return
   end

   shownWholeSeconds = nil
   updateTimer()
   countdownConnection = RunService.Heartbeat:Connect(updateTimer)
end

local function updateVoteCounts(optionA: number, optionB: number)
   if not OptionACount or not OptionBCount then
      return
   end

   OptionACount.Text = tostring(optionA)
   OptionBCount.Text = tostring(optionB)
end

-- // Apply in-intermission display
local function applyIntermissionUi()
   if not VoteContainer or not GamemodeLabel or not SubheaderLabel or not OptionAButton or not OptionBButton then
      return
   end

   local gameStateData = GameStateLibrary.getGameStateData()
   local options = gameStateData.IntermissionOptions:Get()
   local optionA = options[1]
   local optionB = options[2]
   local votes = gameStateData.IntermissionVotes:Get()
   local voteA = votes[1]
   local voteB = votes[2]
   local chosenGamemode = gameStateData.IntermissionChosenGamemode:Get()

   VoteContainer.Visible = chosenGamemode == nil
   GamemodeLabel.Text = "Intermission"
   SubheaderLabel.Text = gameStateData.IntermissionWinMessage:Get() or ""
   updateVoteCounts(voteA, voteB)

   OptionAButton.TextLabel.Text = if optionA and Gamemodes[optionA] then (Gamemodes[optionA].Display or optionA) else (optionA or "")
   OptionBButton.TextLabel.Text = if optionB and Gamemodes[optionB] then (Gamemodes[optionB].Display or optionB) else (optionB or "")

   startCountdown("")
end

-- // Apply in-round display
local function applyRoundUi()
   if not VoteContainer or not GamemodeLabel or not SubheaderLabel then
      return
   end

   VoteContainer.Visible = false
   local newGamemode = GameStateLibrary.getGameStateData().Gamemode:Get()
   local gamemodeData = newGamemode and Gamemodes[newGamemode] or nil
   if gamemodeData and newGamemode then
      GamemodeLabel.Text = gamemodeData.Name or newGamemode
      SubheaderLabel.Text = gamemodeData.Subheader or ""
      startCountdown(gamemodeData.Timer or "")
      return
   end

   GamemodeLabel.Text = ""
   SubheaderLabel.Text = ""
   startCountdown("")
end

-- // Refresh hud display using current game state data
local function refreshUiFromGameState()
   local gameStateData = GameStateLibrary.getGameStateData()
   if gameStateData.IsInRound:Get() and gameStateData.Gamemode:Get() then
      applyRoundUi()
      return
   end

   local options = gameStateData.IntermissionOptions:Get()
   if #options > 0 then
      applyIntermissionUi()
      return
   end

   if VoteContainer then
      VoteContainer.Visible = false
   end
   stopCountdown()
   if TimerLabel then
      TimerLabel.Text = ""
   end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function GamemodeHudGui.open()
	GamemodeHudGui.Open = true	
	Gui.Enabled = true
end

function GamemodeHudGui.close(Instant: boolean?)
	GamemodeHudGui.Open = false
	Gui.Enabled = false
end

function GamemodeHudGui.getHeaderPaddingSizeOffset(): number
   if not GuiHeader then
      return 0
   end
   return GuiHeader.AbsoluteSize.Y * .75
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Parent = Player.PlayerGui
   Gui.Enabled = true

   GuiHeader = Gui.Header
   GamemodeLabel = Gui.Header.GamemodeLabel
   SubheaderLabel = Gui.Header.SubheaderLabel
   TimerLabel = Gui.Header.TimerLabel

   VoteContainer = Gui.VoteContainer
   OptionAButton = VoteContainer.OptionA
   OptionBButton = VoteContainer.OptionB
   OptionACount = VoteContainer.OptionA.VoteCount
   OptionBCount = VoteContainer.OptionB.VoteCount

   VoteContainer.Visible = false

   OptionAButton.Activated:Connect(function()
      SimpleRemotes.getEvent("VoteUpdated"):FireServer(1)
   end)

   OptionBButton.Activated:Connect(function()
      SimpleRemotes.getEvent("VoteUpdated"):FireServer(2)
   end)
end
_init()

function GamemodeHudGui.start()
   GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(_snapshot, _reason)
      refreshUiFromGameState()
   end)
   refreshUiFromGameState()
end

return GamemodeHudGui