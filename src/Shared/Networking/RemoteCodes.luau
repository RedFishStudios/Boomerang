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

	Item = {
		Events = {
			Granted = 0,
			Consumed = 1,
			Acquired = 2,
		},

		Functions = {
			Get = 0,
			Purchase = 1,
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
	},

	-- Services
})

return RemoteCodes
