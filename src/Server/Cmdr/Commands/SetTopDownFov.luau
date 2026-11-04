-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetTopDownFovServer.
return {
	Name = "settopdownfov",
	Aliases = { "camfov" },
	Description = "Shows or sets the top-down camera's field of view, in degrees (lower = flatter but further away; it still widens if needed to stay within 300 studs of your character). Everyone in this server, not saved.",
	Group = "DevTesting",
	Args = {
		{
			Type = "number",
			Name = "value",
			Description = "Vertical field of view in degrees (1-90). Leave empty to show the current value, -1 to go back to the default.",
			Optional = true,
		},
	},
}
