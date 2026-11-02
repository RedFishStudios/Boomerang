-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in EndRoundServer.
-- // Replaces the old /endround chat command.
return {
	Name = "endround",
	Aliases = {},
	Description = "Ends the active round right away, as if its timer ran out.",
	Group = "DevTesting",
	Args = {},
}
