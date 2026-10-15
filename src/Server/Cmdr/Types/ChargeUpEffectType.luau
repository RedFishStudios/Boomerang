-- // Cmdr type "chargeupeffect": a charge up effect id from Shared/Referential/ChargeUpEffects, tab-completable.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChargeUpEffects = require(ReplicatedStorage.Shared.Referential.ChargeUpEffects)

return function(registry)
	local chargeUpEffectIds = {}
	for chargeUpEffectId in ChargeUpEffects do
		table.insert(chargeUpEffectIds, chargeUpEffectId)
	end
	table.sort(chargeUpEffectIds)

	registry:RegisterType("chargeupeffect", registry.Cmdr.Util.MakeEnumType("chargeupeffect", chargeUpEffectIds))
end
