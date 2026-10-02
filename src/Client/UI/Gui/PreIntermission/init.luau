local PreIntermissionGui = {}
PreIntermissionGui.Type = "HUD"
PreIntermissionGui.Open = false

local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer
local Players = game:GetService("Players")

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientMods = ReplicatedStorage.Client
local SharedMods = ReplicatedStorage.Shared

local UIController = require(ClientMods.UI.UIController)
local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
local _AbilityController = require(ClientMods.Core.AbilityController)
local _WeaponController = require(ClientMods.Core.WeaponController)
local GameplayPhases = require(SharedMods.Constants.Enums.GameplayPhases)

-- // Gui Values // --

local Gui = script.PreIntermission
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local imageContainer = Gui:WaitForChild("ImageLabel") :: ImageLabel
local winningPlayerLabel = imageContainer:WaitForChild("WinningPlayer") :: TextLabel
local playerUsernameLabel = imageContainer:WaitForChild("Username") :: TextLabel
local winningTeamLabel = imageContainer:WaitForChild("WinningTeam") :: TextLabel

-- // Animation Values // --

local imageContainerGoalPosition = imageContainer.Position
local imageContainerOffscreenPosition = imageContainerGoalPosition - UDim2.fromScale(0, 1)
local IMAGE_CONTAINER_TWEEN_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local IMAGE_CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local lastRegisteredGameplayPhase = nil
local instanceKey = nil
local activeTween = nil

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

type WinnerInfo = {
	Type: "Player" | "Team" | "Tie",
	UserId: number?,
	TeamName: string?,
}

local function getPlayerNames(userId: number): (string, string)
	local winningPlayer = Players:GetPlayerByUserId(userId)
	if winningPlayer then
		return winningPlayer.DisplayName, winningPlayer.Name
	end

	local success, userInfos = pcall(function()
		return Players:GetUserInfosByUserIdsAsync({ userId })
	end)
	local userInfo = success and userInfos[1]
	if userInfo then
		return userInfo.DisplayName, userInfo.Username
	end

	return "Player", "Unknown"
end

local function playImageContainerTween(tweenInfo: TweenInfo, goalPosition: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(imageContainer, tweenInfo, { Position = goalPosition })
	activeTween:Play()
end

local function displayWinnerInfo(winnerInfo: WinnerInfo?)
	if winnerInfo and winnerInfo.Type == "Player" and winnerInfo.UserId then
		local displayName, username = getPlayerNames(winnerInfo.UserId)
		winningPlayerLabel.Text = displayName .. " won!"
		playerUsernameLabel.Text = "@" .. username
		winningPlayerLabel.Visible = true
		playerUsernameLabel.Visible = true
		winningTeamLabel.Visible = false
	elseif winnerInfo and winnerInfo.Type == "Team" and winnerInfo.TeamName then
		winningTeamLabel.Text = winnerInfo.TeamName .. " won!"
		winningTeamLabel.Visible = true
		winningPlayerLabel.Visible = false
		playerUsernameLabel.Visible = false
	elseif winnerInfo and winnerInfo.Type == "Tie" then
		winningTeamLabel.Text = "Game tied!"
		winningTeamLabel.Visible = true
		winningPlayerLabel.Visible = false
		playerUsernameLabel.Visible = false
	else
		-- // No winning player/team: fall back to the team container with a generic message
		winningTeamLabel.Text = "No winner"
		winningTeamLabel.Visible = true
		winningPlayerLabel.Visible = false
		playerUsernameLabel.Visible = false
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function PreIntermissionGui.open()
	instanceKey = math.random(10000)
	PreIntermissionGui.Open = true	
	Gui.Enabled = true

	imageContainer.Position = imageContainerOffscreenPosition
	playImageContainerTween(IMAGE_CONTAINER_TWEEN_INFO, imageContainerGoalPosition)

	UIController.GuiToggledTasks:Execute("parallel", "PreIntermission", true)
end

function PreIntermissionGui.close(Instant: boolean?)
	local thisInstance = math.random(10000)
	instanceKey = thisInstance
	PreIntermissionGui.Open = false
	if Instant then
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end
		imageContainer.Position = imageContainerOffscreenPosition
		Gui.Enabled = false
	else
		playImageContainerTween(IMAGE_CONTAINER_TWEEN_INFO_OUT, imageContainerOffscreenPosition)
		task.spawn(function()
			task.wait(0.6)
			if instanceKey == thisInstance then
				Gui.Enabled = false
			end
		end)
	end

	UIController.GuiToggledTasks:Execute("parallel", "PreIntermission", false)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Enabled = false
	imageContainer.Position = imageContainerOffscreenPosition
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