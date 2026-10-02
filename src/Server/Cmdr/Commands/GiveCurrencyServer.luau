local ServerStorage = game:GetService("ServerStorage")

local EconomyService = require(ServerStorage.Server.Core.EconomyService)

return function(_context, players: { Player }, amount: number)
	local results = {}

	for _, player in players do
		if not EconomyService.addCurrency(player, amount) then
			table.insert(results, `{player.Name}: data not loaded`)
			continue
		end

		table.insert(results, `{player.Name}: {EconomyService.getBalance(player)}`)
	end

	return `Currency updated. {table.concat(results, ", ")}`
end
