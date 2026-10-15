local ServerStorage = game:GetService("ServerStorage")

local EmoteService = require(ServerStorage.Server.Core.EmoteService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, emoteId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		elseif EmoteService.ownsEmote(player, emoteId) then
			table.insert(results, `{player.Name}: already owned`)
		elseif EmoteService.grantEmote(player, emoteId) then
			table.insert(results, `{player.Name}: granted`)
		else
			table.insert(results, `{player.Name}: failed`)
		end
	end

	return `grantemote {emoteId}. {table.concat(results, ", ")}`
end
