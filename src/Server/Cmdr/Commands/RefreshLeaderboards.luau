-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in RefreshLeaderboardsServer.
return {
	Name = "refreshleaderboards",
	Aliases = { "refreshlb" },
	Description = "Saves everyone's leaderboard scores and reloads the lobby leaderboards now (instead of waiting for the 10-minute refresh).",
	Group = "DevTesting",
	Args = {},
}
