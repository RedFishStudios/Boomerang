local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TopDownCameraLibrary = require(ReplicatedStorage.Shared.Library.TopDownCameraLibrary)

local SETTING = "Distance"
local RESET_VALUE = 0

local function describe(): string
	local value = TopDownCameraLibrary.get(SETTING)
	if value == nil then
		return `Top-down camera Distance = automatic (default)`
	end
	return `Top-down camera Distance = {value} studs (default automatic)`
end

return function(_context, value: number?)
	if value == nil then
		return describe()
	end
	if value == RESET_VALUE then
		TopDownCameraLibrary.set(SETTING, nil)
		return describe()
	end
	local range = TopDownCameraLibrary.DISTANCE_RANGE
	if value < range[1] or value > range[2] then
		return `The value must be between {range[1]} and {range[2]} studs (0 = automatic).`
	end
	TopDownCameraLibrary.set(SETTING, value)
	return describe()
end
