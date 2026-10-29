-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ResetQuestsServer.
return {
	Name = "resetquests",
	Aliases = { "rerollquests" },
	Description = "T-143: gives the players new quests now, as if the pool had reset. Pass a pool name (Daily, Weekly) to reset only that one.",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players whose quests to reset.",
		},
		{
			Type = "string",
			Name = "pool",
			Description = "Only this quest pool (Daily, Weekly). Default: all of them.",
			Optional = true,
		},
	},
}
