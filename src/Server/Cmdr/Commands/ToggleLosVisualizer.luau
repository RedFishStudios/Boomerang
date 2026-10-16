-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ToggleLosVisualizerServer.
return {
	Name = "togglelosvisualizer",
	Aliases = { "losvisualizer" },
	Description = "Shows or hides the line-of-sight cast a boomerang makes to its player when it runs out of energy: a block from the boomerang to the player's Hitbox, green if clear and red (with a hit marker) if blocked. This server only (not saved).",
	Group = "DevTesting",
	Args = {
		{
			Type = "boolean",
			Name = "enabled",
			Description = "true shows the line-of-sight cast, false hides it (GlobalConfig.LineOfSightVisualizerEnabled is the default).",
		},
	},
}
