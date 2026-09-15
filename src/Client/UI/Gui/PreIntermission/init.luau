local PreIntermissionGui = {}
PreIntermissionGui.Type = "HUD"
PreIntermissionGui.Open = false

local _TweenService = game:GetService("TweenService")

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
local GameplayPhases = require(SharedMods.Constants.Enums.GameplayPhases)

-- // Gui Values // --

local Gui = script.PreIntermission
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local TeamResultContainer = Gui:WaitForChild("TeamResultContainer") :: Frame
local TeamSubtitle = TeamResultContainer:WaitForChild("Subtitle") :: TextLabel

local PlayerResultContainer = Gui:WaitForChild("PlayerResultContainer") :: Frame
local PlayerSubtitle = PlayerResultContainer:WaitForChild("Subtitle") :: TextLabel
local PlayerUsername = PlayerResultContainer:WaitForChild("Username") :: TextLabel

local lastRegisteredGameplayPhase = nil

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

type WinnerInfo = {
	Type: "Player" | "Team" | "Tie",
	UserId: number?,
	TeamName: string?,
}

local function displayWinnerInfo(winnerInfo: WinnerInfo?)
	if winnerInfo and winnerInfo.Type == "Player" and winnerInfo.UserId then
		local winningPlayer = Players:GetPlayerByUserId(winnerInfo.UserId)
		PlayerSubtitle.Text = (winningPlayer and winningPlayer.DisplayName or "Player") .. " won!"
		PlayerUsername.Text = "@" .. (winningPlayer and winningPlayer.Name or "Unknown")
		PlayerResultContainer.Visible = true
		TeamResultContainer.Visible = false
	elseif winnerInfo and winnerInfo.Type == "Team" and winnerInfo.TeamName then
		TeamSubtitle.Text = winnerInfo.TeamName .. " Wins!"
		TeamResultContainer.Visible = true
		PlayerResultContainer.Visible = false
	elseif winnerInfo and winnerInfo.Type == "Tie" then
		TeamSubtitle.Text = "Game tied!"
		TeamResultContainer.Visible = true
		PlayerResultContainer.Visible = false
	else
		-- // No winning player/team: fall back to the team container with a generic message
		TeamSubtitle.Text = "No Winner"
		TeamResultContainer.Visible = true
		PlayerResultContainer.Visible = false
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function PreIntermissionGui.open()
   PreIntermissionGui.Open = true	
	Gui.Enabled = true
	UIController.GuiToggledTasks:Execute("parallel", "PreIntermission", true)
end

function PreIntermissionGui.close(Instant: boolean?)
   PreIntermissionGui.Open = false
	Gui.Enabled = false
	UIController.GuiToggledTasks:Execute("parallel", "PreIntermission", false)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Enabled = false
   Gui.Parent = Player.PlayerGui
end
_init()

function PreIntermissionGui.start()
   GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(snapshot)
      local gameplayPhase = snapshot.GameplayPhase
      if gameplayPhase == lastRegisteredGameplayPhase then
         return
      end
      lastRegisteredGameplayPhase = gameplayPhase
      if gameplayPhase == GameplayPhases.PreIntermission then
         local intermissionData = snapshot.IntermissionData
         displayWinnerInfo(intermissionData and intermissionData.WinnerInfo)
         PreIntermissionGui.open()
      elseif PreIntermissionGui.Open then
         PreIntermissionGui.close()
      end
   end)
end

return PreIntermissionGui