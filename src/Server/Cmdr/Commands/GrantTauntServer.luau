local ServerStorage = game:GetService("ServerStorage")

local TauntService = require(ServerStorage.Server.Core.TauntService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, tauntId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		elseif TauntService.ownsTaunt(player, tauntId) then
			table.insert(results, `{player.Name}: already owned`)
		elseif TauntService.grantTaunt(player, tauntId) then
			table.insert(results, `{player.Name}: granted`)
		else
			table.insert(results, `{player.Name}: failed`)
		end
	end

	return `granttaunt {tauntId}. {table.concat(results, ", ")}`
end
