-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ViewHitboxServer.
return {
	Name = "viewhitbox",
	Aliases = { "viewhitboxes" },
	Description = "Shows or hides every hit-detection visualizer at once: player Hitboxes, decoy/bot Hitboxes, each slash's hit wedge (drawn for a moment per swing) and each boomerang's hit sweep as it flies. This server only (not saved).",
	Group = "DevTesting",
	Args = {
		{
			Type = "boolean",
			Name = "visible",
			Description = "true shows all hit-detection visualizers, false hides them.",
		},
	},
}
