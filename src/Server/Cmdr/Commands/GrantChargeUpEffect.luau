-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in GrantChargeUpEffectServer.
return {
	Name = "grantchargeupeffect",
	Aliases = { "givearrow" },
	Description = "Gives a charge up effect to one or more players (it doesn't equip it).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to give the charge up effect to.",
		},
		{
			Type = "chargeupeffect",
			Name = "chargeupeffect",
			Description = "The charge up effect id (Shared/Referential/ChargeUpEffects).",
		},
	},
}
