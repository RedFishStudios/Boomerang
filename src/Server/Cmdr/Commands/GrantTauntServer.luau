local ServerStorage = game:GetService("ServerStorage")

local TauntService = require(ServerStorage.Server.Core.TauntService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, tauntId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		else
			-- // Granted (or already owned), then equipped straight away (Sol, 2026-11-13)
			local alreadyOwned = TauntService.ownsTaunt(player, tauntId)
			if not alreadyOwned and not TauntService.grantTaunt(player, tauntId) then
				table.insert(results, `{player.Name}: failed`)
			elseif not TauntService.equipTaunt(player, tauntId) then
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, but equipping failed`)
			else
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, equipped`)
			end
		end
	end

	return `granttaunt {tauntId}. {table.concat(results, ", ")}`
end
