local ServerStorage = game:GetService("ServerStorage")

local EmoteService = require(ServerStorage.Server.Core.EmoteService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, emoteId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		else
			-- // Granted (or already owned), then equipped straight away (Sol, 2026-11-13)
			local alreadyOwned = EmoteService.ownsEmote(player, emoteId)
			if not alreadyOwned and not EmoteService.grantEmote(player, emoteId) then
				table.insert(results, `{player.Name}: failed`)
			elseif not EmoteService.equipEmote(player, emoteId) then
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, but equipping failed`)
			else
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, equipped`)
			end
		end
	end

	return `grantemote {emoteId}. {table.concat(results, ", ")}`
end
