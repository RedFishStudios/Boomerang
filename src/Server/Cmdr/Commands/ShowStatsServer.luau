local ServerStorage = game:GetService("ServerStorage")

local LifetimeStatsService = require(ServerStorage.Server.Core.LifetimeStatsService)

local function formatCounts(counts: { [string]: number }): string
	local parts = {}
	for id, count in counts do
		table.insert(parts, `{id} {count}`)
	end
	table.sort(parts)
	return if #parts > 0 then table.concat(parts, ", ") else "none"
end

return function(_context, player: Player)
	local stats = LifetimeStatsService.getStats(player)
	if not stats then
		return `{player.Name}: data not loaded`
	end

	return table.concat({
		`{player.Name}'s stats:`,
		`Eliminations: {stats.Elims}, Defeats: {stats.Defeats}`,
		`Wins: {stats.Wins}, Rounds played: {stats.RoundsPlayed}`,
		`Time played: {math.floor(stats.TimePlayed / 60)} min ({stats.TimePlayed} s)`,
		`Abilities used: {formatCounts(stats.AbilityUses)}`,
		`Pickups acquired: {formatCounts(stats.PickupsAcquired)}`,
	}, "\n")
end
