-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in TuneBoomerangServer.
-- // Changes the weapon the caller is holding, for every player, until the server shuts down.
return {
	Name = "tuneboomerang",
	Aliases = { "tune" },
	Description = "Shows or changes a boomerang value for the weapon you're holding (this server only). No setting: show all. No value: show one.",
	Group = "DevTesting",
	Args = {
		{
			Type = "boomerangsetting",
			Name = "setting",
			Description = "ThrowSpeed (studs/s), MinEnergy (energy of an uncharged throw, next throw), MaxEnergy (energy of a fully charged throw, next throw), EnergyPerStud (energy lost per stud flown), RecallEnergy (energy a boomerang is refilled to when it starts returning because it ran out), BounceEnergyCost (energy lost bouncing off a wall), PlayerHitEnergyCost (energy lost striking a player), ClashEnergyCost (energy lost striking another boomerang), RecallSpeed (studs/s, manual recall), RecallCurveAcceleration (turn rate toward the player, 1 = normal recall), RecallStartSpeed (fraction of full speed a manual recall starts at, 0-1), RecallFullSpeedDistance (studs a manual recall flies before reaching full speed), RecallSpeedCurve (speed-up shape: 1 = steady, below 1 = picks up pace sooner), RecallBounceRecovery (seconds for a returning boomerang's bounce momentum to fade back into heading for the player), DeadWeaponDeceleration (how much faster a dying boomerang stops sliding and falls, 1 = original pace), ChargeTime (seconds to max power), AimWalkSpeed (studs/s while aiming), RecallChargeTime (seconds a manual recall charges before returning).",
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
