local ServerStorage = game:GetService("ServerStorage")

local GroupMembershipService = require(ServerStorage.Server.Core.GroupMembershipService)

return function(_context, groupId: number?)
	GroupMembershipService.setGroupId(groupId)
	return `Group membership now uses group {GroupMembershipService.getGroupId()} in this server.`
end
