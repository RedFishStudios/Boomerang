-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ToggleProjectileVisualizerServer.
return {
	Name = "toggleprojectilevisualizer",
	Aliases = { "projectilevisualizer" },
	Description = "Shows or hides the red part marking where the server has each thrown boomerang. Applies to boomerangs thrown after the command (ones already in flight are unchanged). This server only (not saved).",
	Group = "DevTesting",
	Args = {
		{
			Type = "boolean",
			Name = "enabled",
			Description = "true shows the server's boomerang position part, false hides it (GlobalConfig.ProjectileHitboxVisualizerEnabled is the default).",
		},
	},
}
