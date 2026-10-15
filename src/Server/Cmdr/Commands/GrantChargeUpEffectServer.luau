local ServerStorage = game:GetService("ServerStorage")

local ChargeUpEffectService = require(ServerStorage.Server.Core.ChargeUpEffectService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, chargeUpEffectId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		elseif ChargeUpEffectService.ownsChargeUpEffect(player, chargeUpEffectId) then
			table.insert(results, `{player.Name}: already owned`)
		elseif ChargeUpEffectService.grantChargeUpEffect(player, chargeUpEffectId) then
			table.insert(results, `{player.Name}: granted`)
		else
			table.insert(results, `{player.Name}: failed`)
		end
	end

	return `grantchargeupeffect {chargeUpEffectId}. {table.concat(results, ", ")}`
end
