-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetStationStateServer.
return {
	Name = "setstationstate",
	Aliases = { "stationstate" },
	Description = "Sets players' state for a lobby station (T-047). State \"clear\" resets it; \"Locked\"/\"Claimed\" dim the pad.",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players whose station state changes.",
		},
		{
			Type = "string",
			Name = "stationId",
			Description = "The station's StationId attribute.",
		},
		{
			Type = "string",
			Name = "state",
			Description = "e.g. Active, Locked, Claimed, or clear.",
		},
		{
			Type = "boolean",
			Name = "promptEnabled",
			Description = "Show the prompt (default true).",
			Optional = true,
		},
	},
}
