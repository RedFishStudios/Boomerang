local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

-- // AbilityService and WeaponService read GlobalConfig.SyncAbilitiesToEveryPlayer on the server each time, so setting it here takes
-- // effect straight away (server only; it goes back to the GlobalConfig default when the server restarts)
return function(_context, enabled: boolean)
	GlobalConfig.SyncAbilitiesToEveryPlayer = enabled
	return if enabled
		then "Ability sync ON: every player's abilities and throws are now done by every player in the server."
		else "Ability sync OFF."
end
