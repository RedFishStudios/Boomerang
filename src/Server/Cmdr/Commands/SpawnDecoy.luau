-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SpawnDecoyServer.
-- // Testing entry point for the Decoy epic (T-082): getpickup can't grant Decoy while it's Disabled.
return {
	Name = "spawndecoy",
	Aliases = {},
	Description = "Arms a Decoy on yourself for testing: your next boomerang throw spawns one decoy.",
	Group = "DevTesting",
	Args = {},
}
