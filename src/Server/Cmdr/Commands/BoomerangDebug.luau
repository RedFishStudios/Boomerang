-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in BoomerangDebugServer.
return {
	Name = "boomerangdebug",
	Aliases = {},
	Description = "Boomerang replication testing for everyone in this server (not saved). log 1 = each client prints how far boomerangs drift from the server (per flight, and every hard snap) in its output; walk = your character walks by itself (0 off, 1 circle, 2 strafe, 3 away from your boomerang, 4 toward it); walkradius = studs for circle/strafe; noreturn 1 = boomerangs always die at 0 energy (to test manual recalls on open ground); throw <degrees> = your client throws at full charge in that direction; recall <seconds> = your client holds manual recall that long. No setting: show all.",
	Group = "DevTesting",
	Args = {
		{
			Type = "boomerangdebugsetting",
			Name = "setting",
			Description = "log (0/1), walk (0-4), walkradius (studs), noreturn (0/1), or the actions throw / recall. Leave empty to show all.",
			Optional = true,
		},
		{
			Type = "number",
			Name = "value",
			Description = "The new value. Leave empty to show the current one; -1 resets it.",
			Optional = true,
		},
	},
}
