--[[
	BoomerangDebugLibrary

	Dev testing switches for boomerang replication, set with Cmdr `boomerangdebug <setting> <value>` and read by every
	client (BoomerangDebugController). Stored as attributes on ReplicatedStorage; this server only, not saved.
	  - Log: 1 = each client prints how far its boomerangs drift from the server's snapshots (per flight, plus every hard snap)
	  - Walk: makes your own character walk by itself, a moving target: 0 off, 1 circle, 2 strafe left-right,
	    3 away from your boomerang, 4 toward your boomerang
	  - WalkRadius: studs, the size of the circle / strafe
	  - NoReturn: 1 = boomerangs never see their player at 0 energy, so they always die (manual recalls on open ground)
	Actions (one-off, for the player who ran the command): "throw" (a full-charge throw at an angle in degrees) and "recall"
	(hold manual recall for some seconds); the client runs them through the same input functions a touch player uses.
]]

local BoomerangDebugLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ATTRIBUTES = {
	Log = "BoomerangDebugLog",
	Walk = "BoomerangDebugWalk",
	WalkRadius = "BoomerangDebugWalkRadius",
	NoReturn = "BoomerangDebugNoReturn",
}

BoomerangDebugLibrary.DEFAULTS = {
	Log = 0,
	Walk = 0,
	WalkRadius = 20,
	NoReturn = 0,
}

export type Setting = "Log" | "Walk" | "WalkRadius" | "NoReturn"

function BoomerangDebugLibrary.get(setting: Setting): number
	local value = ReplicatedStorage:GetAttribute(ATTRIBUTES[setting])
	return if type(value) == "number" then value else BoomerangDebugLibrary.DEFAULTS[setting]
end

-- // SERVER: set (or reset with nil) a setting for everyone in this server
function BoomerangDebugLibrary.set(setting: Setting, value: number?)
	assert(RunService:IsServer(), "BoomerangDebugLibrary.set is server only")
	ReplicatedStorage:SetAttribute(ATTRIBUTES[setting], value)
end

local ACTION_ATTRIBUTE = "BoomerangDebugAction" -- // On the player: "<action>:<value>:<unique number>"

-- // SERVER: ask `player`'s client to run a test action
function BoomerangDebugLibrary.requestAction(player: Player, action: string, value: number)
	assert(RunService:IsServer(), "BoomerangDebugLibrary.requestAction is server only")
	player:SetAttribute(ACTION_ATTRIBUTE, `{action}:{value}:{os.clock()}`)
end

-- // CLIENT: the latest requested action, or nil
function BoomerangDebugLibrary.getAction(player: Player): (string?, number?)
	local raw = player:GetAttribute(ACTION_ATTRIBUTE)
	if type(raw) ~= "string" then
		return nil, nil
	end
	local action, value = raw:match("^(%a+):([%-%d%.]+):")
	return action, tonumber(value)
end

function BoomerangDebugLibrary.getActionChangedSignal(player: Player): RBXScriptSignal
	return player:GetAttributeChangedSignal(ACTION_ATTRIBUTE)
end

function BoomerangDebugLibrary.getChangedSignal(setting: Setting): RBXScriptSignal
	return ReplicatedStorage:GetAttributeChangedSignal(ATTRIBUTES[setting])
end

return BoomerangDebugLibrary
