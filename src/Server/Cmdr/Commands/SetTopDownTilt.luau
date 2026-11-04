-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetTopDownTiltServer.
return {
	Name = "settopdowntilt",
	Aliases = { "camtilt" },
	Description = "Shows or sets how far the top-down camera leans back from straight down, in degrees (0 = straight down). Everyone in this server, not saved.",
	Group = "DevTesting",
	Args = {
		{
			Type = "number",
			Name = "value",
			Description = "Degrees from straight down (0-80). Leave empty to show the current value, -1 to go back to the default.",
			Optional = true,
		},
	},
}
