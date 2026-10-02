local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponService = require(ServerStorage.Server.Core.WeaponService)
local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

return function(context, setting: string?)
	local toolId = WeaponService.getEquippedToolId(context.Executor)
	if not toolId or not Tools[toolId] or not Tools[toolId].Boomerang then
		return "You aren't holding a boomerang weapon."
	end

	local settings = if setting then { setting } else BoomerangTuningLibrary.SETTING_ORDER
	for _, eachSetting in settings do
		BoomerangTuningLibrary.set(toolId, eachSetting :: any, nil)
	end

	return if setting then `{toolId}: {setting} reset to {BoomerangTuningLibrary.getDefault(toolId, setting :: any)}.` else `{toolId}: all values reset to their defaults.`
end
