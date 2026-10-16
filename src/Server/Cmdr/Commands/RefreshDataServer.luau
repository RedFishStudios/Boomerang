local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-- // Yields until every player's save and reload has finished
return function(context, players: { Player }?)
	local targets = players
	if not targets or #targets == 0 then
		targets = { context.Executor }
	end

	local results = {}
	for _, player in targets :: { Player } do
		local ok, message = PlayerDataService.refresh(player)
		local outcome = if ok then message else "FAILED: " .. message
		table.insert(results, `{player.Name}: {outcome}`)
	end

	return table.concat(results, "\n")
end
