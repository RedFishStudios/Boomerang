--[[
	These I use in remotes so they're easily bufferized
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

export type Code = number

local RemoteCodes = GeneralUtil.deepFreeze({
	-- Core
	Character = {
		Unreliable = {
			SetTargetsBulk = 0,
		},
	},

	Instances = {
		Events = {
			SendAll = 0,
			Update = 1,
		},
	},

	Weapon = {
		Events = {
			Throw = 0,
		},

		Unreliable = {
			BoomerangSnapshot = 0,
		},
	},

	-- Services
})

return RemoteCodes
