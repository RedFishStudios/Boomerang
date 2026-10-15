-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in GrantEmoteServer.
return {
	Name = "grantemote",
	Aliases = { "giveemote" },
	Description = "Gives an emote to one or more players (it doesn't equip it).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to give the emote to.",
		},
		{
			Type = "emote",
			Name = "emote",
			Description = "The emote id (Shared/Referential/Emotes).",
		},
	},
}
