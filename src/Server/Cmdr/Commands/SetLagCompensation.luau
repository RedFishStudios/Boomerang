-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetLagCompensationServer.
return {
	Name = "setlagcompensation",
	Aliases = { "lagcompensation" },
	Description = "Shows or sets the most (milliseconds) the server rewinds players when a boomerang checks for hits, so a hit that looked like a hit on the thrower's screen counts. 0 turns lag compensation off. This server only (not saved).",
	Group = "DevTesting",
	Args = {
		{
			Type = "number",
			Name = "milliseconds",
			Description = "The most to rewind, 0 to 1000 (0 = off). Leave empty to show the current value. GlobalConfig.LagCompensationMilliseconds is the default.",
			Optional = true,
		},
	},
}
