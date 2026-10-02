-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ZapChainServer.
return {
	Name = "zapchain",
	Aliases = {},
	Description = "Eliminates a player as if by an Electric boomerang and starts a chain from them (you, if no player is given).",
	Group = "DevTesting",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "The player to zap. Defaults to you. If it's someone else, you count as the thrower.",
			Optional = true,
		},
	},
}
