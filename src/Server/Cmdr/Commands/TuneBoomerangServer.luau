local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponService = require(ServerStorage.Server.Core.WeaponService)
local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

local function describe(toolId: string, setting): string
	local value = BoomerangTuningLibrary.get(toolId, setting)
	local default = BoomerangTuningLibrary.getDefault(toolId, setting)
	local suffix = if BoomerangTuningLibrary.isOverridden(toolId, setting) then ` (default {default})` else " (default)"
	return `{setting} = {value}{suffix}`
end

return function(context, setting: string?, value: number?)
	local toolId = WeaponService.getEquippedToolId(context.Executor)
	if not toolId or not Tools[toolId] or not Tools[toolId].Boomerang then
		return "You aren't holding a boomerang weapon."
	end

	if setting == nil then
		local lines = {}
		for _, eachSetting in BoomerangTuningLibrary.SETTING_ORDER do
			table.insert(lines, describe(toolId, eachSetting))
		end
		return `{toolId}:\n{table.concat(lines, "\n")}`
	end

	if value == nil then
		return `{toolId}: {describe(toolId, setting)}`
	end

	if value <= 0 then
		return "The value must be greater than 0."
	end

	BoomerangTuningLibrary.set(toolId, setting :: any, value)
	return `{toolId}: {describe(toolId, setting)}. Applies from the next throw/recall.`
end
