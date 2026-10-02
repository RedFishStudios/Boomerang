-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetGroupIdServer.
return {
	Name = "setgroupid",
	Aliases = {},
	Description = "Changes the Roblox group used for membership checks in this server only (not saved). No id goes back to GlobalConfig.GroupId.",
	Group = "DevTesting",
	Args = {
		{
			Type = "integer",
			Name = "groupId",
			Description = "The group id to use.",
			Optional = true,
		},
	},
}
