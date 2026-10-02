local PendingPlayersGui = {}
PendingPlayersGui.Type = "HUD"
PendingPlayersGui.Open = false

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
local GameplayPhases = require(SharedMods.Constants.Enums.GameplayPhases)

-- // Gui Values // --

local Gui = script.PendingPlayers
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local lastRegisteredGameplayPhase = nil

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

local function registerGameplayPhase(snapshot)
   local gameplayPhase = snapshot.GameplayPhase
   if gameplayPhase == lastRegisteredGameplayPhase then
      return
   end
   lastRegisteredGameplayPhase = gameplayPhase
   if gameplayPhase == GameplayPhases.PendingPlayers then
      PendingPlayersGui.open()
   elseif PendingPlayersGui.Open then
      PendingPlayersGui.close()
   end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function PendingPlayersGui.open()
   PendingPlayersGui.Open = true	
	Gui.Enabled = true
end

function PendingPlayersGui.close(Instant: boolean?)
   PendingPlayersGui.Open = false
	Gui.Enabled = false
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Enabled = false
   Gui.Parent = Player.PlayerGui
end
_init()

function PendingPlayersGui.start()
   warn(`starting PendingPlayersGui`)
   print(GameStateLibrary.getSnapshot())
   print(GameStateLibrary.getGameStateData())
   
   if GameStateLibrary.HasSyncedState then
      registerGameplayPhase(GameStateLibrary.getSnapshot())
   end
   GameStateLibrary.GameStateSnapshotLoadedTasks:Add(registerGameplayPhase)
end

return PendingPlayersGui