local DeathScreen = {}
DeathScreen.Type = "HUD"
DeathScreen.Open = false

local _TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientMods = ReplicatedStorage.Client
local SharedMods = ReplicatedStorage.Shared

local _UIController = require(ClientMods.UI.UIController)
local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
local AbilityController = require(ClientMods.Core.AbilityController)
local WeaponController = require(ClientMods.Core.WeaponController)
local PlayersUtil = require(SharedMods.Utils.PlayersUtil)
local SimpleRemotes = require(SharedMods.Networking.SimpleRemotes)

-- // Gui Values // --

local Gui = script.DeathScreen
Gui.IgnoreGuiInset = true

local centreTextLabel = Gui.TextLabel

local deathScreenGrayscale = Instance.new("ColorCorrectionEffect")
deathScreenGrayscale.Name = "DeathScreenGrayscale"
deathScreenGrayscale.Enabled = false
deathScreenGrayscale.Saturation = -1

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function DeathScreen.display(text: string)
   centreTextLabel.Text = text
   centreTextLabel.Visible = true
   DeathScreen.open()
end

function DeathScreen.open()
   Gui.Enabled = true
   deathScreenGrayscale.Enabled = true
end

function DeathScreen.close(Instant: boolean?)
   Gui.Enabled = false
   centreTextLabel.Visible = false
   deathScreenGrayscale.Enabled = false
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Parent = Player.PlayerGui
   Gui.Enabled = true

   deathScreenGrayscale.Parent = game:GetService("Lighting")

   SimpleRemotes.getEvent("PlayerDeathReason").OnClientEvent:Connect(function(reason)
      local character = Player.Character
      if character then
         local humanoid = character:FindFirstChildOfClass("Humanoid")
         if humanoid then
            if humanoid.Health > 0 then
               print(`declining death message notification received while alive...?`)
               return
            end
         end
      end
      DeathScreen.display(reason)
   end)

   PlayersUtil.CharacterDied:Add(function(_player, character)
      if _player == Player then
         DeathScreen.open()
      end
   end)

   PlayersUtil.CharacterAdded:Add(function(_player, character)
      if _player == Player then
         DeathScreen.close()
      end
   end)
end
_init()

function DeathScreen.start()
end

return DeathScreen