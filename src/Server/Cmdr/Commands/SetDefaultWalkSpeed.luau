-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in SetDefaultWalkSpeedServer.
return {
	Name = "setdefaultwalkspeed",
	Aliases = { "walkspeed" },
	Description = "Shows or changes the default player walk speed for this server only (not saved) and applies it to every player now. No value: show it.",
	Group = "DevTesting",
	Args = {
		{
			Type = "number",
			Name = "speed",
			Description = "The new default walk speed in studs/s (GlobalConfig.DefaultWalkSpeed is the normal value). Leave empty to show the current one.",
			Optional = true,
		},
	},
}
