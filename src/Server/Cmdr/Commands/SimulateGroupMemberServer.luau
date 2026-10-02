local ServerStorage = game:GetService("ServerStorage")

local GroupMembershipService = require(ServerStorage.Server.Core.GroupMembershipService)

local VALUES: { [string]: boolean | "real" } = {
	member = true,
	nonmember = false,
	real = "real",
}

return function(_context, players: { Player }, membership: string)
	local value = VALUES[membership:lower()]
	if value == nil then
		return `Unknown membership "{membership}". Use member, nonmember or real.`
	end

	for _, player in players do
		GroupMembershipService.setSimulatedMembership(player, if value == "real" then nil else value :: boolean)
	end

	return `Group membership for {#players} player(s): {membership:lower()} (group {GroupMembershipService.getGroupId()}).`
end
