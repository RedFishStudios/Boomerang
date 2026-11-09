-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetNextGamemodeServer.
return {
	Name = "setnextgamemode",
	Aliases = { "nextgamemode" },
	Description = "Forces the gamemode of the next round (skips the rest of the current vote).",
	Group = "DevTesting",
	Args = {
		{
			Type = "gamemode",
			Name = "gamemode",
			Description = "The gamemode to play next.",
		},
	},
}
