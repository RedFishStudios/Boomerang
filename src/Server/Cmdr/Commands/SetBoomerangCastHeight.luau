-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetBoomerangCastHeightServer.
return {
	Name = "setboomerangcastheight",
	Aliases = { "castheight" },
	Description = "Shows or sets the height (studs) of the flat block a boomerang casts to detect obstructions. The same value is used for bouncing off walls in flight and for the line-of-sight check to the player at 0 energy. This server only (not saved).",
	Group = "DevTesting",
	Args = {
		{
			Type = "number",
			Name = "height",
			Description = "The new cast height in studs (leave empty to show the current one). GlobalConfig.BoomerangRaycastHeight is the default.",
			Optional = true,
		},
	},
}
