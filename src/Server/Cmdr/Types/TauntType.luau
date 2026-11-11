-- // Cmdr type "taunt": a taunt id from Shared/Referential/Taunts, tab-completable.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Taunts = require(ReplicatedStorage.Shared.Referential.Taunts)

return function(registry)
	local tauntIds = {}
	for tauntId in Taunts do
		table.insert(tauntIds, tauntId)
	end
	table.sort(tauntIds)

	registry:RegisterType("taunt", registry.Cmdr.Util.MakeEnumType("taunt", tauntIds))
end
