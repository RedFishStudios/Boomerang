local PreIntermissionGui = {}
PreIntermissionGui.Type = "HUD"
PreIntermissionGui.Open = false

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
local IntermissionStagesEnum = require(SharedMods.Constants.Enums.IntermissionStages)

-- // Gui Values // --

local Gui = script.PreIntermission
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local lastRegisteredIntermissionStage = nil

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function PreIntermissionGui.open()
   PreIntermissionGui.Open = true	
	Gui.Enabled = true
end

function PreIntermissionGui.close(Instant: boolean?)
   PreIntermissionGui.Open = false
	Gui.Enabled = false
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Enabled = false
   Gui.Parent = Player.PlayerGui
end
_init()

function PreIntermissionGui.start()
   GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(snapshot)
      local newIntermissionStage = snapshot.IntermissionStage
      if newIntermissionStage == lastRegisteredIntermissionStage then
         return
      end
      lastRegisteredIntermissionStage = newIntermissionStage
      if newIntermissionStage == IntermissionStagesEnum.PreIntermission then
         PreIntermissionGui.open()
      elseif PreIntermissionGui.Open then
         PreIntermissionGui.close()
      end
   end)
end

return PreIntermissionGui