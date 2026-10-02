local ServerStorage = game:GetService("ServerStorage")

local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)

return function(_context)
	if not RoundCyclingService.forceEndRound() then
		return "No round is currently active."
	end
	return "Round ended."
end
