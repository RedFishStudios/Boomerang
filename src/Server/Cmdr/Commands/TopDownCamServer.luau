local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TopDownCameraLibrary = require(ReplicatedStorage.Shared.Library.TopDownCameraLibrary)

-- // Per command setting: the library setting it changes, its unit, range, the value that resets it, and the default shown
local SETTINGS = {
	tilt = { Setting = "Tilt", Unit = "degrees", Range = TopDownCameraLibrary.TILT_RANGE, ResetValue = -1, Default = "30 degrees" },
	fov = { Setting = "FieldOfView", Unit = "degrees", Range = TopDownCameraLibrary.FIELD_OF_VIEW_RANGE, ResetValue = -1, Default = "20 degrees" },
	distance = { Setting = "Distance", Unit = "studs", Range = TopDownCameraLibrary.DISTANCE_RANGE, ResetValue = 0, Default = "automatic" },
}
local ORDER = { "tilt", "fov", "distance" }

local function describe(name: string): string
	local info = SETTINGS[name]
	local value = TopDownCameraLibrary.get(info.Setting)
	if value == nil then
		return `{name} = {info.Default} (default)`
	end
	return `{name} = {value} {info.Unit} (default {info.Default})`
end

return function(_context, name: string?, value: number?)
	if name == nil then
		local lines = {}
		for _, settingName in ORDER do
			table.insert(lines, describe(settingName))
		end
		return `Top-down camera: {table.concat(lines, ", ")}`
	end
	local info = SETTINGS[name]
	if not info then
		return `Unknown setting {name}: use tilt, fov or distance.`
	end
	if value == nil then
		return describe(name)
	end
	if value == info.ResetValue then
		TopDownCameraLibrary.set(info.Setting, nil)
		return describe(name)
	end
	if value < info.Range[1] or value > info.Range[2] then
		return `{name} must be between {info.Range[1]} and {info.Range[2]} {info.Unit} ({info.ResetValue} = {if name == "distance" then "automatic" else "default"}).`
	end
	TopDownCameraLibrary.set(info.Setting, value)
	return describe(name)
end
