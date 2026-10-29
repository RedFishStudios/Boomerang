local ServerStorage = game:GetService("ServerStorage")

local QuestService = require(ServerStorage.Server.Core.QuestService)

return function(_context, players: { Player }, amount: number?)
	local results = {}
	for _, player in players do
		local ok = if amount then QuestService.addProgressForTesting(player, amount) else QuestService.completeQuests(player)
		table.insert(results, if ok then player.Name else `{player.Name}: data not loaded`)
	end
	return `Quest progress {if amount then `+{amount}` else "completed"}: {table.concat(results, ", ")}`
end
