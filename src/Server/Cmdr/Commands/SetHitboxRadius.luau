-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetHitboxRadiusServer.
return {
	Name = "sethitboxradius",
	Aliases = { "hitboxradius" },
	Description = "Shows or sets the radius (studs) of every player's Hitbox, the vertical cylinder boomerangs hit. Resizes the hitboxes that exist now and applies to new spawns. This server only (not saved). See it with `viewhitbox true`.",
	Group = "DevTesting",
	Args = {
		{
			Type = "number",
			Name = "radius",
			Description = "The new radius in studs (leave empty to show the current one). GlobalConfig.PlayerHitboxRadius is the default.",
			Optional = true,
		},
	},
}
