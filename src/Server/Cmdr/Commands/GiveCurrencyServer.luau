local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, amount: number)
	local results = {}

	for _, player in players do
		local data = PlayerDataService.get(player)
		if not data then
			table.insert(results, `{player.Name}: data not loaded`)
			continue
		end

		-- // Writes go through the data proxy, which replicates them to the client
		data.Currency = math.max(0, (data.Currency or 0) + amount)
		table.insert(results, `{player.Name}: {data.Currency}`)
	end

	return `Currency updated. {table.concat(results, ", ")}`
end
