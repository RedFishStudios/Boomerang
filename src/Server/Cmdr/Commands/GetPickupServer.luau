local ServerStorage = game:GetService("ServerStorage")

local PickupService = require(ServerStorage.Server.Core.PickupService)

return function(context, pickupClassId: string)
	local success, result = PickupService.grantPickupClassId(context.Executor, pickupClassId)
	if not success then
		return result or `Could not activate pickup {pickupClassId}.`
	end
	return `Activated pickup {result}.`
end
