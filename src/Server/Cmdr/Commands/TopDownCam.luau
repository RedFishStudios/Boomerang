-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in TopDownCamServer.
return {
	Name = "topdowncam",
	Aliases = {},
	Description = "Shows or changes the top-down camera for everyone in this server (not saved). tilt = degrees it leans back from straight down; fov = its field of view (lower = flatter but further away; it still widens if needed to stay within 300 studs of your character); distance = a fixed distance in studs instead of fitting the view to the action; weaponspeed = studs/s the view chases boomerangs on the field; weaponhold = seconds the view keeps a boomerang's spot after it's gone; weaponrange = studs from the nearest player beyond which boomerangs aren't framed (0 = none). No setting: show all.",
	Group = "DevTesting",
	Args = {
		{
			Type = "topdowncamsetting",
			Name = "setting",
			Description = "tilt (0-80 degrees), fov (1-90 degrees), distance (10-300 studs), weaponspeed (1-1000 studs/s), weaponhold (0-10 seconds) or weaponrange (0-500 studs). Leave empty to show all.",
			Optional = true,
		},
		{
			Type = "number",
			Name = "value",
			Description = "The new value. Leave empty to show the current one; -1 resets a setting to its default (0 sets distance back to automatic).",
			Optional = true,
		},
	},
}
