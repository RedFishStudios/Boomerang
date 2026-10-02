-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ResetDailyServer.
return {
	Name = "resetdaily",
	Aliases = { "resetdailyclaim" },
	Description = "Makes the next daily reward claimable now, as if a day had passed. Pass true to also reset the streak to day 1.",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players whose daily claim to reset.",
		},
		{
			Type = "boolean",
			Name = "resetStreak",
			Description = "Also reset the streak, so the next claim is day 1 (default: false).",
			Optional = true,
		},
	},
}
