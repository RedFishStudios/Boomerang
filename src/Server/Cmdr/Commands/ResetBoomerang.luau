-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ResetBoomerangServer.
-- // Undoes tuneboomerang for the weapon the caller is holding (T-054).
return {
	Name = "resetboomerang",
	Aliases = {},
	Description = "Resets boomerang values changed with tuneboomerang back to their defaults, for the weapon you're holding. No setting: reset all.",
	Group = "DevTesting",
	Args = {
		{
			Type = "boomerangsetting",
			Name = "setting",
			Description = "The value to reset (leave empty to reset all of them).",
			Optional = true,
		},
	},
}
