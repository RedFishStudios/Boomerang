local ServerStorage = game:GetService("ServerStorage")

local ChargeUpEffectService = require(ServerStorage.Server.Core.ChargeUpEffectService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, chargeUpEffectId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		else
			-- // Granted (or already owned), then equipped straight away (Sol, 2026-11-13)
			local alreadyOwned = ChargeUpEffectService.ownsChargeUpEffect(player, chargeUpEffectId)
			if not alreadyOwned and not ChargeUpEffectService.grantChargeUpEffect(player, chargeUpEffectId) then
				table.insert(results, `{player.Name}: failed`)
			elseif not ChargeUpEffectService.equipChargeUpEffect(player, chargeUpEffectId) then
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, but equipping failed`)
			else
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, equipped`)
			end
		end
	end

	return `grantchargeupeffect {chargeUpEffectId}. {table.concat(results, ", ")}`
end
