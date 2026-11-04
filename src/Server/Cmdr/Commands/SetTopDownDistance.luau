-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetTopDownDistanceServer.
return {
	Name = "settopdowndistance",
	Aliases = { "camdistance" },
	Description = "Shows or sets a fixed distance (studs) for the top-down camera, instead of fitting the view to the action. It never goes further than 300 studs from your character. Everyone in this server, not saved.",
	Group = "DevTesting",
	Args = {
		{
			Type = "number",
			Name = "value",
			Description = "Distance in studs (10-300). Leave empty to show the current value, 0 to go back to automatic.",
			Optional = true,
		},
	},
}
