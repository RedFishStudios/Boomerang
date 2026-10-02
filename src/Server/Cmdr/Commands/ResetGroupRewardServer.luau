local ServerStorage = game:GetService("ServerStorage")

local GroupRewardService = require(ServerStorage.Server.Core.GroupRewardService)

return function(_context, players: { Player })
	local results = {}

	for _, player in players do
		local reset = GroupRewardService.resetClaim(player)
		table.insert(results, `{player.Name}: {if reset then "reset" else "data not loaded"}`)
	end

	return `Group reward: {table.concat(results, ", ")}`
end
