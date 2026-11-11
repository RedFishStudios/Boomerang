local ServerStorage = game:GetService("ServerStorage")

local ElimEffectService = require(ServerStorage.Server.Core.ElimEffectService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, elimEffectId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		elseif ElimEffectService.ownsElimEffect(player, elimEffectId) then
			table.insert(results, `{player.Name}: already owned`)
		elseif ElimEffectService.grantElimEffect(player, elimEffectId) then
			table.insert(results, `{player.Name}: granted`)
		else
			table.insert(results, `{player.Name}: failed`)
		end
	end

	return `grantelimeffect {elimEffectId}. {table.concat(results, ", ")}`
end
