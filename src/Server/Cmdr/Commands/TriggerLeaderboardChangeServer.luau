local ServerStorage = game:GetService("ServerStorage")

local LeaderboardService = require(ServerStorage.Server.Core.LeaderboardService)

return function(_context)
	LeaderboardService.swapPeriodsNow()
	return "Leaderboards switching period for every player."
end
