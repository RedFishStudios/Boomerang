local ServerStorage = game:GetService("ServerStorage")

local RoundCyclingService = require(ServerStorage.Server.Core.RoundCyclingService)

return function(_context, mapName: string)
	local matchedName = RoundCyclingService.setNextMap(mapName)
	if not matchedName then
		return `{mapName} is not a recognized map.`
	end
	return `Next round will be on {matchedName}.`
end
