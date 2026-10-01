local ServerStorage = game:GetService("ServerStorage")

local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)

return function(_context, gamemodeId: string)
	local matchedId = RoundCyclingService.setNextGamemode(gamemodeId)
	if not matchedId then
		return `{gamemodeId} is not a recognized gamemode.`
	end
	return `Next round will be {matchedId}.`
end
