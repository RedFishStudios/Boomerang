-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ToggleAuthorityViewServer.
return {
	Name = "toggleauthorityview",
	Aliases = { "authorityview" },
	Description = "Shows or hides the server's view of each thrown boomerang: a neon red ball at the server-side position, sized to the weapon's hitbox. This server only (not saved).",
	Group = "DevTesting",
	Args = {
		{
			Type = "boolean",
			Name = "enabled",
			Description = "true shows the server's boomerang position, false hides it (GlobalConfig.ToggleAuthorityView is the default).",
		},
	},
}
