local ServerStorage = game:GetService("ServerStorage")

local ElimEffectService = require(ServerStorage.Server.Core.ElimEffectService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, elimEffectId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		else
			-- // Granted (or already owned), then equipped straight away (Sol, 2026-11-13)
			local alreadyOwned = ElimEffectService.ownsElimEffect(player, elimEffectId)
			if not alreadyOwned and not ElimEffectService.grantElimEffect(player, elimEffectId) then
				table.insert(results, `{player.Name}: failed`)
			elseif not ElimEffectService.equipElimEffect(player, elimEffectId) then
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, but equipping failed`)
			else
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, equipped`)
			end
		end
	end

	return `grantelimeffect {elimEffectId}. {table.concat(results, ", ")}`
end
