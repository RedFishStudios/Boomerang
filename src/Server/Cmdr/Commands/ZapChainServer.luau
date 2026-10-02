local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElectricBoomerang = require(ReplicatedStorage.Shared.Logics.PickupLogics.ElectricBoomerang)

return function(context, target: Player?)
	local executor = context.Executor
	local victim = target or executor
	-- // Zapping someone else: the executor is the thrower (credited, never hit, teammates skipped)
	local thrower = if victim ~= executor then executor else nil
	local _success, message = ElectricBoomerang.triggerChain(victim, thrower)
	return message
end
