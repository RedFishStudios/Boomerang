local ServerStorage = game:GetService("ServerStorage")

local PickupService = require(ServerStorage.Server.Core.PickupService)

return function(context)
	local success, result = PickupService.forceGrantPickup(context.Executor, "Decoy")
	if not success then
		return result or "Could not arm Decoy."
	end
	return "Armed Decoy -- throw your boomerang to spawn it."
end
