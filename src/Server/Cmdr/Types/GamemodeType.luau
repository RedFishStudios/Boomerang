-- // Cmdr type "gamemode": a gamemode id from Shared/Constants/Gamemodes, tab-completable.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
-- // (Cmdr moves this module at runtime, so paths are absolute.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gamemodes = require(ReplicatedStorage.Shared.Constants.Gamemodes)

return function(registry)
	local gamemodeIds = {}
	for gamemodeId in Gamemodes do
		table.insert(gamemodeIds, gamemodeId)
	end
	table.sort(gamemodeIds)

	registry:RegisterType("gamemode", registry.Cmdr.Util.MakeEnumType("gamemode", gamemodeIds))
end
