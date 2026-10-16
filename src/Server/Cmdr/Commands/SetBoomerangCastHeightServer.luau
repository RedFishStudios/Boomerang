local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObstructionCastLibrary = require(ReplicatedStorage.Shared.Library.ObstructionCastLibrary)

local function describe(): string
	local default = ObstructionCastLibrary.getDefaultHeight()
	local suffix = if ObstructionCastLibrary.isHeightOverridden() then ` (default {default})` else " (default)"
	return `Boomerang cast height = {ObstructionCastLibrary.getHeight()}{suffix}`
end

return function(_context, height: number?)
	if height == nil then
		return describe()
	end
	if height <= 0 then
		return "The height must be greater than 0."
	end
	ObstructionCastLibrary.setHeight(height)
	return `{describe()}. Used for both bounce detection and line of sight; applies to the next cast.`
end
