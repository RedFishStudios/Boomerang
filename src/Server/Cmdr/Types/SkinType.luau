-- // Cmdr type "skin": a skin id from Shared/Referential/Skins, tab-completable.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage.Shared.Referential.Skins)

return function(registry)
	local skinIds = {}
	for skinId in Skins do
		table.insert(skinIds, skinId)
	end
	table.sort(skinIds)

	registry:RegisterType("skin", registry.Cmdr.Util.MakeEnumType("skin", skinIds))
end
