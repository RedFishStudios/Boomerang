local ServerStorage = game:GetService("ServerStorage")

local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)

return function(_context, seconds: number)
	if seconds < 0 then
		return "The time must be 0 or more seconds."
	end
	if not RoundCyclingService.setRoundTimeRemaining(seconds) then
		return "No round is currently active."
	end
	return `Round time remaining set to {seconds} seconds.`
end
