-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ResetGroupRewardServer.
return {
	Name = "resetgroupreward",
	Aliases = {},
	Description = "Makes the lobby Group Rewards chest claimable again now, as if 24 h had passed (T-045).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players whose chest claim is reset.",
		},
	},
}
