-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SimulateGroupMemberServer.
return {
	Name = "simulategroupmember",
	Aliases = { "simgroup" },
	Description = "Pretends players are (member) or aren't (nonmember) in the game's group for this server, or goes back to the real answer (real).",
	Group = "DevTesting",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "The players to simulate.",
		},
		{
			Type = "string",
			Name = "membership",
			Description = "member, nonmember or real.",
		},
	},
}
