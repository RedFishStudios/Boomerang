-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in GiveCurrencyServer.
return {
	Name = "givecurrency",
	Aliases = { "addcurrency" },
	Description = "Adds Currency to one or more players (use a negative amount to remove it). Players start with 0 Currency, so use this to get some for testing, e.g. `givecurrency me 1000`.",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to give Currency to.",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "How much Currency to add.",
		},
	},
}
