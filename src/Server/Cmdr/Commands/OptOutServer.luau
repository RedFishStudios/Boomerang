local ServerStorage = game:GetService("ServerStorage")

local PlayerSessionService = require(ServerStorage.Server.Core.PlayerSessionService)

return function(context, optOut: boolean?)
	local player: Player = context.Executor
	local value = if optOut == nil then true else optOut

	PlayerSessionService.setOptOut(player, value)

	return `{player.Name}: OptOut = {PlayerSessionService.isOptedOut(player)}`
end
