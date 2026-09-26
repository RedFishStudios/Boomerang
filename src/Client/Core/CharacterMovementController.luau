local CharacterMovementController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

CharacterMovementController.PlayerStartedMoving = TasksList.new() :: TasksList.TasksList<(player: Player) -> ()>
CharacterMovementController.PlayerStoppedMoving = TasksList.new() :: TasksList.TasksList<(player: Player) -> ()>

local movingPlayers: {[Player]: boolean} = {}

local function isMoving(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.01
end

function CharacterMovementController.isMoving(player: Player): boolean
	return isMoving(player)
end

function CharacterMovementController.init()
	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local moving = isMoving(player)
			if moving == movingPlayers[player] then
				continue
			end

			movingPlayers[player] = moving
			if moving then
				CharacterMovementController.PlayerStartedMoving:Execute("parallel", player)
			else
				CharacterMovementController.PlayerStoppedMoving:Execute("parallel", player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		movingPlayers[player] = nil
	end)
end

return CharacterMovementController