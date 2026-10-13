-- // Cmdr type "aimarrow": an aim arrow id from Shared/Referential/AimArrows, tab-completable.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimArrows = require(ReplicatedStorage.Shared.Referential.AimArrows)

return function(registry)
	local aimArrowIds = {}
	for aimArrowId in AimArrows do
		table.insert(aimArrowIds, aimArrowId)
	end
	table.sort(aimArrowIds)

	registry:RegisterType("aimarrow", registry.Cmdr.Util.MakeEnumType("aimarrow", aimArrowIds))
end
