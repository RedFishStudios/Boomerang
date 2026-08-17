local HudButtonsGui = {}
HudButtonsGui.Type = "HUD"
HudButtonsGui.Open = false

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

-- // Gui Values // --

local Gui = script.Hud
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
local BoomerangThrowButton = Gui.Frame.Throw :: TextButton

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

local function weaponStateToDisplayString(weaponState: number): string
   if weaponState == WeaponController.CurrentWeaponState.Aiming then
      return "Throw"
   elseif weaponState == WeaponController.CurrentWeaponState.InHand then
      return "Aim"
   elseif weaponState == WeaponController.CurrentWeaponState.OnField then
      return "Recall"
   end

   return "Aim"
end

local function setupGuiForNewRound()
   BoomerangThrowButton.Text = weaponStateToDisplayString(WeaponController.getWeaponState())
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

function HudButtonsGui.getCameraPadding()
   return BoomerangThrowButton.AbsoluteSize.Y * 1.1
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function HudButtonsGui.open()
   HudButtonsGui.Open = true	
	Gui.Enabled = true
end

function HudButtonsGui.close(Instant: boolean?)
   HudButtonsGui.Open = false
	Gui.Enabled = false
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Parent = Player.PlayerGui
   Gui.Enabled = true

   setupGuiForNewRound()

   local function syncBoomerangThrowButton()
      task.spawn(function()
         BoomerangThrowButton.Text = weaponStateToDisplayString(WeaponController.getWeaponState())
      end)
   end

   Gui.Frame.Dash.Activated:Connect(function()
      AbilityController.activate("Dash")
   end)
   Gui.Frame.Stab.Activated:Connect(function()
      AbilityController.activate("Stab")
   end)

   BoomerangThrowButton.Activated:Connect(function()
      WeaponController.handleEquippedToolButton()
   end)

   syncBoomerangThrowButton()
   WeaponController.WeaponStateChanged:Add(syncBoomerangThrowButton)
end
_init()

function HudButtonsGui.start()
   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.CurrentRoundData:Subscribe(function()
      setupGuiForNewRound()
   end)
end

return HudButtonsGui