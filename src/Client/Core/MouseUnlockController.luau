--[[
	MouseUnlockController

	Description:
	Frees the mouse while any gui with `RequiresMouse = true` is open (see UIController.isMouseRequired).
	The in-game over-the-shoulder ("Regular") camera locks and hides the mouse, so without this a menu that opens
	during a round can't be clicked or closed. A visible Modal button is Roblox's standard way to free a locked mouse.
]]

local MouseUnlockController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local CustomCameraController = require(ReplicatedStorage.Client.Core.CustomCameraController)
local LobbyController = require(ReplicatedStorage.Client.Core.LobbyController)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local modalButton: TextButton? = nil
local isUnlocked = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getModalButton(): TextButton
	if modalButton and modalButton.Parent then
		return modalButton
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MouseUnlock"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = -1000

	local button = Instance.new("TextButton")
	button.Name = "Modal"
	button.Size = UDim2.fromScale(0, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Selectable = false
	button.Visible = false
	button.Modal = true
	button.Parent = screenGui

	screenGui.Parent = player:WaitForChild("PlayerGui")
	modalButton = button
	return button
end

-- // The camera hides the cursor only in the arena's Regular (over-the-shoulder) mode
local function shouldCursorBeHidden(): boolean
	return CustomCameraController.getMode() == "Regular" and not LobbyController.isInLobby()
end

local function update()
	local isRequired = UIController.isMouseRequired()

	if isRequired then
		getModalButton().Visible = true
		-- // Enforced every frame: the camera can re-hide the cursor (e.g. switching camera mode while a menu is open)
		UserInputService.MouseIconEnabled = true
		isUnlocked = true
	elseif isUnlocked then
		isUnlocked = false
		getModalButton().Visible = false
		if shouldCursorBeHidden() then
			UserInputService.MouseIconEnabled = false
		end
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function MouseUnlockController.start()
	RunService.RenderStepped:Connect(update)
end

return MouseUnlockController
