-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in GrantElimEffectServer.
return {
	Name = "grantelimeffect",
	Aliases = { "grantstrikeeffect" },
	Description = "Gives an elimination effect (Strike Effect) to one or more players and equips it (already owned: just equips it).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to give the effect to.",
		},
		{
			Type = "elimeffect",
			Name = "elimeffect",
			Description = "The effect id (Shared/Referential/ElimEffects).",
		},
	},
}
