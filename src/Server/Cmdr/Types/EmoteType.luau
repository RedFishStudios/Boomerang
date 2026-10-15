-- // Cmdr type "emote": an emote id from Shared/Referential/Emotes, tab-completable.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Emotes = require(ReplicatedStorage.Shared.Referential.Emotes)

return function(registry)
	local emoteIds = {}
	for emoteId in Emotes do
		table.insert(emoteIds, emoteId)
	end
	table.sort(emoteIds)

	registry:RegisterType("emote", registry.Cmdr.Util.MakeEnumType("emote", emoteIds))
end
