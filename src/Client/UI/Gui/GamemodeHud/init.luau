local GamemodeHudGui = {}
GamemodeHudGui.Type = "HUD"

local _TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = game:GetService("Players").LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientMods = ReplicatedStorage.Client
local SharedMods = ReplicatedStorage.Shared

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

-- // Apply in-round display
local function applyRoundUi()
   if not GamemodeLabel or not SubheaderLabel then
      return
   end

   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   local newGamemode = if currentRoundData then currentRoundData.Gamemode else nil
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
   if gameStateData.CurrentRoundData:Get() == nil then
      GamemodeHudGui.close(true)
   else
      GamemodeHudGui.open()
      applyRoundUi()
      return
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

function GamemodeHudGui.getCameraPadding(): number
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
end
_init()

function GamemodeHudGui.start()
   GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(_snapshot, _reason)
      refreshUiFromGameState()
   end)
   refreshUiFromGameState()
end

return GamemodeHudGui