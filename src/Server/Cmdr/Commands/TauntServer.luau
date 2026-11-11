local ServerStorage = game:GetService("ServerStorage")

local TauntService = require(ServerStorage.Server.Core.TauntService)

return function(context, players: { Player }?)
	local results = {}

	for _, player in players or { context.Executor } do
		local played = TauntService.play(player, true)
		table.insert(results, `{player.Name}: {if played then "taunting" else "can't taunt now (dead, or already taunting)"}`)
	end

	return `taunt. {table.concat(results, ", ")}`
end
