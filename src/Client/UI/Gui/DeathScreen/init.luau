local DeathScreen = {}
DeathScreen.Type = "HUD"
DeathScreen.Open = false

local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer
local Players = game:GetService("Players")

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientMods = ReplicatedStorage.Client
local SharedMods = ReplicatedStorage.Shared

local UIController = require(ClientMods.UI.UIController)
local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
local AbilityController = require(ClientMods.Core.AbilityController)
local WeaponController = require(ClientMods.Core.WeaponController)
local PlayersUtil = require(SharedMods.Utils.PlayersUtil)
local SimpleRemotes = require(SharedMods.Networking.SimpleRemotes)

-- // Gui Values // --

local Gui = script.DeathScreen
Gui.IgnoreGuiInset = true

local imageContainer = Gui:WaitForChild("ImageLabel")
local downedLabel = imageContainer:WaitForChild("Downed") :: TextLabel
local eliminatedLabel = imageContainer:WaitForChild("Eliminated") :: TextLabel
local byDisplayNameLabel = imageContainer:WaitForChild("ByDisplayName") :: TextLabel
local byUsernameLabel = imageContainer:WaitForChild("ByUsername") :: TextLabel
local byNonPlayerLabel = imageContainer:WaitForChild("ByNonPlayer") :: TextLabel

local deathScreenGrayscale = Instance.new("ColorCorrectionEffect")
deathScreenGrayscale.Name = "DeathScreenGrayscale"
deathScreenGrayscale.Enabled = false
deathScreenGrayscale.Saturation = -1

-- // Animation Values // --

local imageContainerGoalPosition = imageContainer.Position
local imageContainerOffscreenPosition = imageContainerGoalPosition - UDim2.fromScale(0, 1)
local IMAGE_CONTAINER_TWEEN_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local IMAGE_CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function DeathScreen.display(killerUserId: number?, causeLabel: string?)
   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   local canRespawn = currentRoundData ~= nil and currentRoundData.CanRespawn
   downedLabel.Visible = canRespawn
   eliminatedLabel.Visible = not canRespawn

   local killerPlayer = killerUserId and Players:GetPlayerByUserId(killerUserId)
   byDisplayNameLabel.Visible = killerPlayer ~= nil
   byUsernameLabel.Visible = killerPlayer ~= nil
   byNonPlayerLabel.Visible = killerPlayer == nil
   if killerPlayer then
      byDisplayNameLabel.Text = "By " .. killerPlayer.DisplayName
      byUsernameLabel.Text = "@" .. killerPlayer.Name
   else
      byNonPlayerLabel.Text = causeLabel or "Unknown"
   end

   DeathScreen.open()
end

local instanceKey = nil

function DeathScreen.open()
   -- // Failsafe: never show the death screen over PreIntermission (e.g. a final elimination death that also ends the round)
   if UIController.get("PreIntermission").Open then
      return
   end
   instanceKey = math.random(10000)
   Gui.Enabled = true

   imageContainer.Position = imageContainerOffscreenPosition
   TweenService:Create(imageContainer, IMAGE_CONTAINER_TWEEN_INFO, { Position = imageContainerGoalPosition }):Play()
end

function DeathScreen.close(Instant: boolean?)
   local thisInstance = math.random(10000)
   instanceKey = thisInstance
   TweenService:Create(imageContainer, IMAGE_CONTAINER_TWEEN_INFO_OUT, { Position = imageContainerOffscreenPosition }):Play()
   task.spawn(function()
      task.wait(.6)
      if instanceKey == thisInstance then
         Gui.Enabled = false
         downedLabel.Visible = false
         eliminatedLabel.Visible = false
         byDisplayNameLabel.Visible = false
         byUsernameLabel.Visible = false
         byNonPlayerLabel.Visible = false
      end
   end)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Parent = Player.PlayerGui
   Gui.Enabled = true

   deathScreenGrayscale.Parent = game:GetService("Lighting")

   UIController.GuiToggledTasks:Add(function(guiName: string, isOpen: boolean)
      if guiName == "PreIntermission" and isOpen then
         DeathScreen.close()
      end
   end)

   SimpleRemotes.getEvent("PlayerDeathReason").OnClientEvent:Connect(function(killerUserId: number?, causeLabel: string?)
      local character = Player.Character
      if character then
         local humanoid = character:FindFirstChildOfClass("Humanoid")
         if humanoid then
            if humanoid.Health > 0 then
               return
            end
         end
      end
      DeathScreen.display(killerUserId, causeLabel)
   end)

   PlayersUtil.CharacterDied:Add(function(_player, character)
      if _player == Player then
         deathScreenGrayscale.Enabled = true
         DeathScreen.open()
      end
   end)

   PlayersUtil.CharacterAdded:Add(function(_player, character)
      if _player == Player then
         deathScreenGrayscale.Enabled = false
         DeathScreen.close()
      end
   end)
end
_init()

function DeathScreen.start()
end

return DeathScreen