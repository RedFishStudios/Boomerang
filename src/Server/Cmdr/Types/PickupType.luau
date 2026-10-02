-- // Cmdr type "pickup": a pickup class id (the name of a module in Shared/Logics/PickupLogics), tab-completable.
-- // Disabled (stub) pickups are listed too; the server refuses them (PickupService.grantPickupClassId).
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PickupLogics = ReplicatedStorage.Shared.Logics.PickupLogics

return function(registry)
	local pickupClassIds = {}
	for _, descendant in PickupLogics:GetDescendants() do
		if descendant:IsA("ModuleScript") then
			table.insert(pickupClassIds, descendant.Name)
		end
	end
	table.sort(pickupClassIds)

	registry:RegisterType("pickup", registry.Cmdr.Util.MakeEnumType("pickup", pickupClassIds))
end
