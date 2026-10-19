-- // Cmdr command definition (replicated to clients for autocomplete). Server logic is in ViewPingServer.
return {
	Name = "viewping",
	Aliases = { "ping" },
	Description = "Prints your ping (milliseconds) as the server measures it (Player:GetNetworkPing).",
	Group = "DevTesting",
	Args = {},
}
