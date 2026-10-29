-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in QuestProgressServer.
return {
	Name = "questprogress",
	Aliases = { "completequests" },
	Description = "T-143: adds progress to all of the players' current quests (no amount = finish them all, ready to claim).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players whose quests to advance.",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "How much progress to add to each quest. Default: enough to finish them.",
			Optional = true,
		},
	},
}
