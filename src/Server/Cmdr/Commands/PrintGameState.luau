-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in PrintGameStateServer.
return {
	Name = "printgamestate",
	Aliases = { "gamestate" },
	Description = "Shows the server's current game state (phase, round data, timer, vote data...).",
	Group = "DevTesting",
	Args = {},
}
