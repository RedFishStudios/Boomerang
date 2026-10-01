-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in GetPickupServer.
-- // Replaces the old /getpickup chat command (T-016).
return {
	Name = "getpickup",
	Aliases = { "grantpickup" },
	Description = "Gives you a pickup's effect right away.",
	Group = "DevTesting",
	Args = {
		{
			Type = "pickup",
			Name = "pickup",
			Description = "The pickup class to activate on yourself.",
		},
	},
}
