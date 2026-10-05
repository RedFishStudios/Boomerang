local ServerStorage = game:GetService("ServerStorage")

local SkinService = require(ServerStorage.Server.Core.SkinService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

return function(_context, players: { Player }, skinId: string)
	local results = {}

	for _, player in players do
		if not PlayerDataService.get(player) then
			table.insert(results, `{player.Name}: data not loaded`)
		elseif SkinService.ownsSkin(player, skinId) then
			table.insert(results, `{player.Name}: already owned`)
		elseif SkinService.grantSkin(player, skinId) then
			table.insert(results, `{player.Name}: granted`)
		else
			table.insert(results, `{player.Name}: failed`)
		end
	end

	return `grantskin {skinId}. {table.concat(results, ", ")}`
end
