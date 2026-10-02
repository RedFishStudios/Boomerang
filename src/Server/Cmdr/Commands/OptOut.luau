-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in OptOutServer.
return {
	Name = "optout",
	Aliases = {},
	Description = "Sets whether you sit out of rounds (not added when a round starts). With no value, sets it to true.",
	Group = "DevTesting",
	Args = {
		{
			Type = "boolean",
			Name = "optOut",
			Description = "true to sit out of rounds, false to take part again. Defaults to true.",
			Optional = true,
		},
	},
}
