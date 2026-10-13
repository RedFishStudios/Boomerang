local ServerStorage = game:GetService("ServerStorage")

local AimArrowService = require(ServerStorage.Server.Core.AimArrowService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, aimArrowId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		elseif AimArrowService.ownsAimArrow(player, aimArrowId) then
			table.insert(results, `{player.Name}: already owned`)
		elseif AimArrowService.grantAimArrow(player, aimArrowId) then
			table.insert(results, `{player.Name}: granted`)
		else
			table.insert(results, `{player.Name}: failed`)
		end
	end

	return `grantaimarrow {aimArrowId}. {table.concat(results, ", ")}`
end
