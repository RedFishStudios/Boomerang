local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GlobalInstanceService = require(ServerStorage.Server.Services.GlobalInstanceService)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)

local animationReplicationEvent = SimpleRemotes.getEvent("AnimateReplication")

animationReplicationEvent.OnServerEvent:Connect(function(player: Player, animationId: number, startedAt: number, speed: number?, isLooped: boolean?, transitionTime: number?)
	local character = player.Character
	if not character then
		return
	end

	if typeof(animationId) ~= "number" or typeof(startedAt) ~= "number" then
		return
	end

	SimpleRemotesUtil.fireAllClientsExcept(
		animationReplicationEvent,
		player,
		GlobalInstanceService.getId(character),
		animationId,
		startedAt,
		speed or 1,
		isLooped == true,
		transitionTime or 0
	)
end)
