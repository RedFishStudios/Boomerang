-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in TriggerLeaderboardChangeServer.
return {
	Name = "triggerleaderboardchange",
	Aliases = { "swaplb" },
	Description = "Makes the lobby leaderboards fade to their other period (Monthly / All-Time) now, for every player, instead of waiting for the 10-second swap.",
	Group = "DevTesting",
	Args = {},
}
