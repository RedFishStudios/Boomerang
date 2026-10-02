local ServerStorage = game:GetService("ServerStorage")

local DailyRewardsService = require(ServerStorage.Server.Core.DailyRewardsService)

return function(_context, players: { Player }, resetStreak: boolean?)
	local results = {}

	for _, player in players do
		if not DailyRewardsService.makeClaimable(player, resetStreak) then
			table.insert(results, `{player.Name}: data not loaded`)
			continue
		end

		table.insert(results, `{player.Name}: next claim is day {DailyRewardsService.getNextDay(player)}`)
	end

	return `Daily reward claimable. {table.concat(results, ", ")}`
end
