local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TopDownCameraLibrary = require(ReplicatedStorage.Shared.Library.TopDownCameraLibrary)

local SETTING = "FieldOfView"
local RESET_VALUE = -1

local function describe(): string
	local value = TopDownCameraLibrary.get(SETTING)
	if value == nil then
		return `Top-down camera FieldOfView = 20 (default)`
	end
	return `Top-down camera FieldOfView = {value} degrees (default 20)`
end

return function(_context, value: number?)
	if value == nil then
		return describe()
	end
	if value == RESET_VALUE then
		TopDownCameraLibrary.set(SETTING, nil)
		return describe()
	end
	local range = TopDownCameraLibrary.FIELD_OF_VIEW_RANGE
	if value < range[1] or value > range[2] then
		return `The value must be between {range[1]} and {range[2]} degrees (-1 = the default).`
	end
	TopDownCameraLibrary.set(SETTING, value)
	return describe()
end
