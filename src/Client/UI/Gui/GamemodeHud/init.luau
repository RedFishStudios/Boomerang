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
local Gamemodes = require(SharedMods.Constants.Gamemodes)

-- // Gui Values // --

local Gui = script:WaitForChild("Gamemode")
local countdownConnection: RBXScriptConnection?
local TimerLabel: TextLabel?
local timerEndsAt: number?
local shownWholeSeconds: number?

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

local function stopCountdown()
   if countdownConnection then
      countdownConnection:Disconnect()
      countdownConnection = nil
   end
   timerEndsAt = nil
   shownWholeSeconds = nil
end

local function updateTimer()
   if not TimerLabel or not timerEndsAt then
      return
   end

   local secondsLeft = math.max(0, timerEndsAt - workspace:GetServerTimeNow())
   local wholeSeconds = math.ceil(secondsLeft)
   if shownWholeSeconds ~= wholeSeconds then
      shownWholeSeconds = wholeSeconds
      TimerLabel.Text = tostring(wholeSeconds)
   end

   if secondsLeft <= 0 then
      stopCountdown()
   end
end

local function startCountdown(totalDuration: number?, serverNotificationTime: number?, fallbackText: string)
   stopCountdown()
   if not TimerLabel then
      return
   end

   if typeof(totalDuration) ~= "number" or typeof(serverNotificationTime) ~= "number" then
      TimerLabel.Text = fallbackText
      return
   end

   -- Compensate for network delay between server send and client receipt.
   local estimatedRemaining = math.max(0, totalDuration - (workspace:GetServerTimeNow() - serverNotificationTime))
   timerEndsAt = workspace:GetServerTimeNow() + estimatedRemaining
   shownWholeSeconds = nil
   updateTimer()
   countdownConnection = RunService.Heartbeat:Connect(updateTimer)
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

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Parent = Player.PlayerGui
   Gui.Enabled = true

   local GamemodeLabel = Gui.Header.GamemodeLabel
   local SubheaderLabel = Gui.Header.SubheaderLabel
   TimerLabel = Gui.Header.TimerLabel

   local VoteContainer = Gui.VoteContainer
   local OptionAButton = VoteContainer.OptionA
   local OptionBButton = VoteContainer.OptionB
   local OptionACount = VoteContainer.OptionA.VoteCount
   local OptionBCount = VoteContainer.OptionB.VoteCount

   VoteContainer.Visible = false

   SimpleRemotes.getEvent("VoteUpdated").OnClientEvent:Connect(function(optionA: number, optionB: number, chosenGamemode: string?, intermissionDuration: number?, serverNotificationTime: number?)
      if chosenGamemode and intermissionDuration and serverNotificationTime then
         VoteContainer.Visible = false
         startCountdown(intermissionDuration, serverNotificationTime, "")
      else
         OptionACount.Text = optionA
         OptionBCount.Text = optionB
      end
   end)

   OptionAButton.Activated:Connect(function()
      SimpleRemotes.getEvent("VoteUpdated"):FireServer(1)
   end)

   OptionBButton.Activated:Connect(function()
      SimpleRemotes.getEvent("VoteUpdated"):FireServer(2)
   end)

   SimpleRemotes.getEvent("IntermissionStarted").OnClientEvent:Connect(function(winner: Player?, winMessage: string, options: {string}, intermissionDuration: number?, serverNotificationTime: number?)
      VoteContainer.Visible = true
      GamemodeLabel.Text = "Intermission"
      SubheaderLabel.Text = winMessage
      OptionACount.Text = ""
      OptionBCount.Text = ""

      OptionAButton.TextLabel.Text = Gamemodes[options[1]].Display or options[1]
      OptionBButton.TextLabel.Text = Gamemodes[options[2]].Display or options[2] or ""
      startCountdown(intermissionDuration, serverNotificationTime, "")
   end)

   SimpleRemotes.getEvent("NewRoundStarted").OnClientEvent:Connect(function(newGamemode: string, totalRoundTime: number?, serverNotificationTime: number?)
      VoteContainer.Visible = false
      local gamemodeData = Gamemodes[newGamemode]
      if gamemodeData then
         GamemodeLabel.Text = gamemodeData.Name or newGamemode
         SubheaderLabel.Text = gamemodeData.Subheader or ""

         startCountdown(totalRoundTime, serverNotificationTime, gamemodeData.Timer or "")
      end
   end)
end
_init()

function GamemodeHudGui.start()
end

return GamemodeHudGui