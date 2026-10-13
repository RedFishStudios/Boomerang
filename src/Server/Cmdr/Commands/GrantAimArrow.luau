-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in GrantAimArrowServer.
return {
	Name = "grantaimarrow",
	Aliases = { "givearrow" },
	Description = "Gives an aim arrow to one or more players (it doesn't equip it).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to give the aim arrow to.",
		},
		{
			Type = "aimarrow",
			Name = "aimarrow",
			Description = "The aim arrow id (Shared/Referential/AimArrows).",
		},
	},
}
