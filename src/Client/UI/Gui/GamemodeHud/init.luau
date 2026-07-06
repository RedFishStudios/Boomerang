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

-- // Gui Values // --

local Gui = script:WaitForChild("Gamemode")
local countdownConnection: RBXScriptConnection?

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

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
   local TimerLabel = Gui.Header.TimerLabel

   SimpleRemotes.getEvent("NewRoundStarted").OnClientEvent:Connect(function(newGamemode: string, totalRoundTime: number?, serverNotificationTime: number?)
      local gamemodeData = Gamemodes[newGamemode]
      if gamemodeData then
         GamemodeLabel.Text = gamemodeData.Name or newGamemode
         SubheaderLabel.Text = gamemodeData.Subheader or ""

         if countdownConnection then
            countdownConnection:Disconnect()
            countdownConnection = nil
         end

         if typeof(totalRoundTime) ~= "number" or typeof(serverNotificationTime) ~= "number" then
            TimerLabel.Text = gamemodeData.Timer or ""
            return
         end

         -- Compensate for network delay between server send and client receipt.
         local estimatedRemaining = math.max(0, totalRoundTime - (workspace:GetServerTimeNow() - serverNotificationTime))
         local roundEndsAt = workspace:GetServerTimeNow() + estimatedRemaining
         local shownWholeSeconds: number? = nil

         local function updateTimer()
            local secondsLeft = math.max(0, roundEndsAt - workspace:GetServerTimeNow())
            local wholeSeconds = math.ceil(secondsLeft)
            if shownWholeSeconds ~= wholeSeconds then
               shownWholeSeconds = wholeSeconds
               TimerLabel.Text = tostring(wholeSeconds)
            end

            if secondsLeft <= 0 and countdownConnection then
               countdownConnection:Disconnect()
               countdownConnection = nil
            end
         end

         updateTimer()
         countdownConnection = RunService.Heartbeat:Connect(updateTimer)
      end
   end)
end
_init()

function GamemodeHudGui.start()
end

return GamemodeHudGui