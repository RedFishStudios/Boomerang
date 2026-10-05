-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in GrantSkinServer.
return {
	Name = "grantskin",
	Aliases = { "giveskin" },
	Description = "Gives a boomerang skin to one or more players (it doesn't equip it).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to give the skin to.",
		},
		{
			Type = "skin",
			Name = "skin",
			Description = "The skin id (Shared/Referential/Skins).",
		},
	},
}
