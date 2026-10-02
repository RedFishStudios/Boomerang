-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetNextMapServer.
-- // Replaces the old /setnextmap chat command (T-016).
return {
	Name = "setnextmap",
	Aliases = { "nextmap" },
	Description = "Forces the map of the next round.",
	Group = "DevTesting",
	Args = {
		{
			Type = "map",
			Name = "map",
			Description = "The map to play next.",
		},
	},
}
