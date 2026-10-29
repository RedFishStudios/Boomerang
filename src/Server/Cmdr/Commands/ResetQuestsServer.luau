local ServerStorage = game:GetService("ServerStorage")

local QuestService = require(ServerStorage.Server.Core.QuestService)

return function(_context, players: { Player }, pool: string?)
	local results = {}
	for _, player in players do
		table.insert(results, if QuestService.resetQuests(player, pool) then player.Name else `{player.Name}: data not loaded`)
	end
	return `New {pool or "Daily and Weekly"} quests: {table.concat(results, ", ")}`
end
