-- // Cmdr type "boomerangsetting": a tunable boomerang value from BoomerangTuningLibrary (T-054), tab-completable.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)

return function(registry)
	registry:RegisterType("boomerangsetting", registry.Cmdr.Util.MakeEnumType("boomerangsetting", table.clone(BoomerangTuningLibrary.SETTING_ORDER)))
end
