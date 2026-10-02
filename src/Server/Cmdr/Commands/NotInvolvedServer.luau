local ServerStorage = game:GetService("ServerStorage")

local PlayerSessionService = require(ServerStorage.Server.Core.PlayerSessionService)

return function(context, notInvolved: boolean?)
	local player: Player = context.Executor
	local value = if notInvolved == nil then true else notInvolved

	PlayerSessionService.setNotInvolved(player, value)

	return `{player.Name}: NotInvolved = {PlayerSessionService.isNotInvolved(player)}`
end
