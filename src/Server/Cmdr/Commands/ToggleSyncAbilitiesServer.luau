local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

-- // AbilityService and WeaponService read GlobalConfig.SyncAbilitiesToEveryPlayer each time, so this applies at once
-- // (server only; resets to the GlobalConfig default on restart)
return function(_context, enabled: boolean)
	GlobalConfig.SyncAbilitiesToEveryPlayer = enabled
	return if enabled
		then "Ability sync ON: every player's abilities and throws are now done by every player in the server."
		else "Ability sync OFF."
end
