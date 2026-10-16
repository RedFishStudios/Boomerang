-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in RefreshDataServer.
return {
	Name = "refreshdata",
	Description = "Saves a player's data to the datastore, waits for the save to finish, then loads it back from the datastore and replaces their live data with it. Simulates leaving and rejoining, without leaving. Defaults to you.",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players whose data to refresh (leave empty for yourself).",
			Optional = true,
		},
	},
}
