-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in TauntServer.
return {
	Name = "taunt",
	Aliases = {},
	Description = "Plays the players' equipped taunt now, anywhere (normally only allowed right after a round).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players who taunt. Defaults to you.",
			Optional = true,
		},
	},
}
