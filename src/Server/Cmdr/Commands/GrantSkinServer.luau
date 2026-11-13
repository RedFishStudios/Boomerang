local ServerStorage = game:GetService("ServerStorage")

local SkinService = require(ServerStorage.Server.Core.SkinService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, skinId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		else
			-- // Granted (or already owned), then equipped straight away (Sol, 2026-11-13)
			local alreadyOwned = SkinService.ownsSkin(player, skinId)
			if not alreadyOwned and not SkinService.grantSkin(player, skinId) then
				table.insert(results, `{player.Name}: failed`)
			elseif not SkinService.equipSkin(player, skinId) then
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, but equipping failed`)
			else
				table.insert(results, `{player.Name}: {if alreadyOwned then "already owned" else "granted"}, equipped`)
			end
		end
	end

	return `grantskin {skinId}. {table.concat(results, ", ")}`
end
