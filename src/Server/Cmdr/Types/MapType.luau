-- // Cmdr type "map": a map name from Shared/Constants/MapData, tab-completable.
-- // The maps themselves are in ServerStorage (not visible to clients), so autocomplete uses MapData;
-- // the server still checks the name against the loaded maps (RoundCyclingService.setNextMap).
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapData = require(ReplicatedStorage.Shared.Constants.MapData)

return function(registry)
	local mapNames = {}
	for mapName in MapData do
		table.insert(mapNames, mapName)
	end
	table.sort(mapNames)

	registry:RegisterType("map", registry.Cmdr.Util.MakeEnumType("map", mapNames))
end
