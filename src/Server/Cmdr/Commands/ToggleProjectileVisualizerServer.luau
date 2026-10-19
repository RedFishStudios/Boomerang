local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boomerang = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Boomerang)

return function(_context, enabled: boolean)
	Boomerang.setProjectileVisualizerEnabled(enabled)
	return if enabled
		then "Projectile visualizer ON: boomerangs thrown from now on show a red part at the server's position."
		else "Projectile visualizer OFF: boomerangs thrown from now on have no server part."
end
