local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoomerangDebugLibrary = require(ReplicatedStorage.Shared.Library.BoomerangDebugLibrary)

local SETTINGS = {
	log = { Setting = "Log", Range = { 0, 1 } },
	walk = { Setting = "Walk", Range = { 0, 4 } },
	walkradius = { Setting = "WalkRadius", Range = { 2, 200 } },
	noreturn = { Setting = "NoReturn", Range = { 0, 1 } },
}
local ORDER = { "log", "walk", "walkradius", "noreturn" }

local function describe(name: string): string
	return `{name} = {BoomerangDebugLibrary.get(SETTINGS[name].Setting)}`
end

local ACTIONS = { throw = "degrees (0 = +X, 90 = +Z...)", recall = "seconds to hold" }

return function(context, name: string?, value: number?)
	if name and ACTIONS[name] then
		if value == nil then
			return `{name} needs a value: {ACTIONS[name]}.`
		end
		local character = context.Executor.Character
		if name == "throw" and character then
			-- // A lingering spawn ForceField blocks throwing (WeaponLibrary.canThrow); tests shouldn't wait on it
			for _, forceField in character:GetChildren() do
				if forceField:IsA("ForceField") then
					forceField:Destroy()
				end
			end
		end
		BoomerangDebugLibrary.requestAction(context.Executor, name, value)
		return `Asked your client to {name} ({value}).`
	end
	if name == nil then
		local lines = {}
		for _, settingName in ORDER do
			table.insert(lines, describe(settingName))
		end
		return `Boomerang debug: {table.concat(lines, ", ")}`
	end
	local info = SETTINGS[name]
	if not info then
		return `Unknown setting {name}: use {table.concat(ORDER, ", ")}, throw or recall.`
	end
	if value == nil then
		return describe(name)
	end
	if value == -1 then
		BoomerangDebugLibrary.set(info.Setting, nil)
		return describe(name)
	end
	if value < info.Range[1] or value > info.Range[2] then
		return `{name} must be between {info.Range[1]} and {info.Range[2]} (-1 = default).`
	end
	BoomerangDebugLibrary.set(info.Setting, value)
	return describe(name)
end
