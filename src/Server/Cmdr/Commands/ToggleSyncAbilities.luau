-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ToggleSyncAbilitiesServer.
return {
	Name = "togglesyncabilities",
	Aliases = { "syncabilities" },
	Description = "Turns on or off syncing ability use between players (testing): when on, any player's ability or throw is done by every player in the server at once. This server only (not saved).",
	Group = "DevTesting",
	Args = {
		{
			Type = "boolean",
			Name = "enabled",
			Description = "true syncs every player's abilities and throws, false turns it off (GlobalConfig.SyncAbilitiesToEveryPlayer is the default).",
		},
	},
}
