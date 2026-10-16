local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObstructionCastLibrary = require(ReplicatedStorage.Shared.Library.ObstructionCastLibrary)

return function(_context, enabled: boolean)
	ObstructionCastLibrary.setLosVisualizerEnabled(enabled)
	return if enabled
		then "Line-of-sight visualizer ON: a boomerang that runs out of energy now draws its LOS cast (green = clear, red = blocked) for a few seconds."
		else "Line-of-sight visualizer OFF."
end
