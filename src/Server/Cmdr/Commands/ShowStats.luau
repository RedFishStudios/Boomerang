-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ShowStatsServer.
return {
	Name = "showstats",
	Aliases = { "stats" },
	Description = "Shows a player's saved lifetime stats (eliminations, defeats, wins, rounds, time played, abilities, pickups).",
	Group = "DevTesting",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "The player whose stats to show.",
		},
	},
}
