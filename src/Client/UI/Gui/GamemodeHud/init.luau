local GamemodeHudGui = {}
GamemodeHudGui.Type = "HUD"
GamemodeHudGui.Open = false
GamemodeHudGui.SupercededBy = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = game:GetService("Players").LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedMods = ReplicatedStorage.Shared

local Gamemodes = require(SharedMods.Constants.Gamemodes)
local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
local PlayersUtil = require(SharedMods.Utils.PlayersUtil)

-- // Gui Values // --

local Gui = script:WaitForChild("Gamemode")
local Header = Gui:WaitForChild("Header") :: Frame
local countdownConnection: RBXScriptConnection?
local TimerLabel: TextLabel?
local shownWholeSeconds: number?

local GuiHeader: Frame?
local GamemodeLabel: TextLabel?
--local SubheaderLabel: TextLabel?

local ColoredImage: ImageLabel?
local GrayscaleImage: ImageLabel?
local GamemodeLabelGradient: UIGradient?
local TimerLabelGradient: UIGradient?

-- // Animation Values // --

local headerGoalPosition = Header.Position
local headerOffscreenPosition = headerGoalPosition - UDim2.fromScale(0, 1)
local HEADER_TWEEN_INFO_IN = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HEADER_TWEEN_INFO_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local instanceKey = nil
local activeTween = nil
local isSuperceded = false

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

local function playHeaderTween(tweenInfo: TweenInfo, goalPosition: UDim2)
   if activeTween then
      activeTween:Cancel()
   end
   activeTween = TweenService:Create(Header, tweenInfo, { Position = goalPosition })
   activeTween:Play()
end

local function animateAway(instant: boolean?)
   local thisInstance = math.random(10000)
   instanceKey = thisInstance
   if instant then
      if activeTween then
         activeTween:Cancel()
         activeTween = nil
      end
      Header.Position = headerOffscreenPosition
      Gui.Enabled = false
      return
   end

   playHeaderTween(HEADER_TWEEN_INFO_OUT, headerOffscreenPosition)
   task.spawn(function()
      task.wait(0.6)
      if instanceKey == thisInstance then
         Gui.Enabled = false
      end
   end)
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
   if not TimerLabel or not currentTimerEndsAt then
      return
   end

   local secondsLeft = math.max(0, currentTimerEndsAt - workspace:GetServerTimeNow())
   local wholeSeconds = math.ceil(secondsLeft)
   if shownWholeSeconds ~= wholeSeconds then
      shownWholeSeconds = wholeSeconds
      TimerLabel.Text = string.format("%d:%02d", wholeSeconds // 60, wholeSeconds % 60)
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
   if not GamemodeLabel then
      return
   end

   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   local newGamemode = if currentRoundData then currentRoundData.Gamemode else nil
   local gamemodeData = newGamemode and Gamemodes[newGamemode] or nil
   if gamemodeData and newGamemode then
      GamemodeLabel.Text = string.gsub(gamemodeData.Display or newGamemode, "\n", "  ")
      --SubheaderLabel.Text = gamemodeData.Subheader or ""
      startCountdown(gamemodeData.Timer or "")
      return
   end

   GamemodeLabel.Text = ""
   --SubheaderLabel.Text = ""
   startCountdown("")
end

-- // Refresh hud display using current game state data
local function refreshUiFromGameState()
   local gameStateData = GameStateLibrary.getGameStateData()
   if gameStateData.CurrentRoundData:Get() == nil then
      GamemodeHudGui.close()
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
   if GamemodeHudGui.Open and not isSuperceded then
      return
   end

   GamemodeHudGui.Open = true
   if #GamemodeHudGui.SupercededBy > 0 then
      isSuperceded = true
      return
   end

   instanceKey = math.random(10000)
   isSuperceded = false
   Gui.Enabled = true

   Header.Position = headerOffscreenPosition
   playHeaderTween(HEADER_TWEEN_INFO_IN, headerGoalPosition)
end

function GamemodeHudGui.close(Instant: boolean?)
   if not GamemodeHudGui.Open and not Gui.Enabled then
      return
   end

   GamemodeHudGui.Open = false
   isSuperceded = false
   animateAway(Instant)
end

function GamemodeHudGui.supercede()
   if not GamemodeHudGui.Open then
      return
   end

   isSuperceded = true
   animateAway()
end

function GamemodeHudGui.getCameraPadding(): number
   if not GuiHeader then
      return 0
   end
   return GuiHeader.AbsoluteSize.Y * .75
end

-- // Switch the hud between its colored and grayscale presentation
local function setDead(isDead: boolean)
   if ColoredImage then
      ColoredImage.Visible = not isDead
   end
   if GrayscaleImage then
      GrayscaleImage.Visible = isDead
   end
   if GamemodeLabelGradient then
      GamemodeLabelGradient.Enabled = not isDead
   end
   if TimerLabelGradient then
      TimerLabelGradient.Enabled = not isDead
   end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Parent = Player.PlayerGui
   Gui.Enabled = false
   Header.Position = headerOffscreenPosition

   GuiHeader = Header
   GamemodeLabel = Header.GamemodeLabel
   --SubheaderLabel = Header.SubheaderLabel
   TimerLabel = Header.TimerLabel

   ColoredImage = Header:WaitForChild("Colored") :: ImageLabel
   GrayscaleImage = Header:WaitForChild("Grayscale") :: ImageLabel
   GamemodeLabelGradient = GamemodeLabel:WaitForChild("UIGradient") :: UIGradient
   TimerLabelGradient = TimerLabel:WaitForChild("UIGradient") :: UIGradient

   PlayersUtil.CharacterDied:Add(function(_player, _character)
      if _player == Player then
         setDead(true)
      end
   end)

   PlayersUtil.CharacterAdded:Add(function(_player, _character)
      if _player == Player then
         setDead(false)
      end
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