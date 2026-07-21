-- // Manages replication states of player characters

local CharacterReplicationService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GlobalInstanceService = require(ServerStorage.Server.Services.GlobalInstanceService)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local animationReplicationEvent = SimpleRemotes.getEvent("CharacterAnimationReplication")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterReplicationService.init()
	animationReplicationEvent.OnServerEvent:Connect(function(player: Player, animationState: string, startedAt: number)
		if animationState ~= "Walk" and animationState ~= "Idle" then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		animationReplicationEvent:FireAllClients(GlobalInstanceService.getId(character), animationState, startedAt)
	end)
end

function CharacterReplicationService.start() end

function CharacterReplicationService.test() end

return CharacterReplicationService
