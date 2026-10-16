-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ViewHitboxServer.
return {
	Name = "viewhitbox",
	Description = "Shows or hides every player's Hitbox part (the one HitboxService adds to each character). This server only (not saved).",
	Group = "DevTesting",
	Args = {
		{
			Type = "boolean",
			Name = "visible",
			Description = "true makes the player hitboxes visible, false hides them.",
		},
	},
}
