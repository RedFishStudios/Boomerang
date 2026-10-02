local ServerStorage = game:GetService("ServerStorage")

local LeaderboardService = require(ServerStorage.Server.Core.LeaderboardService)

return function(_context)
	LeaderboardService.refreshNow()
	return "Leaderboards saved and reloaded."
end
