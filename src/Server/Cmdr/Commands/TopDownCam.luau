-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in TopDownCamServer.
return {
	Name = "topdowncam",
	Aliases = {},
	Description = "Shows or changes the top-down camera for everyone in this server (not saved). tilt = degrees it leans back from straight down; fov = its field of view (lower = flatter but further away; it still widens if needed to stay within 300 studs of your character); distance = a fixed distance in studs instead of fitting the view to the action. No setting: show all.",
	Group = "DevTesting",
	Args = {
		{
			Type = "topdowncamsetting",
			Name = "setting",
			Description = "tilt (0-80 degrees), fov (1-90 degrees) or distance (10-300 studs). Leave empty to show all three.",
			Optional = true,
		},
		{
			Type = "number",
			Name = "value",
			Description = "The new value. Leave empty to show the current one; -1 resets tilt or fov to the default, 0 sets distance back to automatic.",
			Optional = true,
		},
	},
}
