-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in GrantTauntServer.
return {
	Name = "granttaunt",
	Aliases = {},
	Description = "Gives a taunt to one or more players and equips it (already owned: just equips it).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to give the taunt to.",
		},
		{
			Type = "taunt",
			Name = "taunt",
			Description = "The taunt id (Shared/Referential/Taunts).",
		},
	},
}
