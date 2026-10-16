-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetRoundTimeServer.
return {
	Name = "setroundtime",
	Aliases = { "roundtime" },
	Description = "Sets the time remaining in the current round, in seconds. 0 ends the round.",
	Group = "DevTesting",
	Args = {
		{
			Type = "number",
			Name = "seconds",
			Description = "Seconds left in the round from now (not negative).",
		},
	},
}
