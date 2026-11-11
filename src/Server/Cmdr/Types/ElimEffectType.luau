-- // Cmdr type "elimeffect": an elimination effect id from Shared/Referential/ElimEffects, tab-completable.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElimEffects = require(ReplicatedStorage.Shared.Referential.ElimEffects)

return function(registry)
	local elimEffectIds = {}
	for elimEffectId in ElimEffects do
		table.insert(elimEffectIds, elimEffectId)
	end
	table.sort(elimEffectIds)

	registry:RegisterType("elimeffect", registry.Cmdr.Util.MakeEnumType("elimeffect", elimEffectIds))
end
