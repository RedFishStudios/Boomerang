-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in TuneBoomerangServer.
-- // Changes the weapon the caller is holding, for every player, until the server shuts down (T-054).
return {
	Name = "tuneboomerang",
	Aliases = { "tune" },
	Description = "Shows or changes a boomerang value for the weapon you're holding (this server only). No setting: show all. No value: show one.",
	Group = "DevTesting",
	Args = {
		{
			Type = "boomerangsetting",
			Name = "setting",
			Description = "ThrowSpeed (studs/s), ThrowDistance (studs), RecallSpeed (studs/s, manual recall), RecallAcceleration (turn rate toward the player, 1 = normal recall), RecallRampTime (seconds for a manual recall to reach max speed), RecallRampPower (speed-up curve; higher = slower start, sharper surge), ChargeTime (seconds to max power), AimWalkSpeed (studs/s while aiming).",
			Optional = true,
		},
		{
			Type = "number",
			Name = "value",
			Description = "The new value (leave empty to show the current one).",
			Optional = true,
		},
	},
}
