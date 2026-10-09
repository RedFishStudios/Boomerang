--[[
	Decoy pickup (T-080)

	On the owner's FIRST throw after pickup, spawns one decoy bot and consumes the effect
	(one pickup = one decoy). The decoy entity + movement live in the bot layer (BotService +
	the Decoy BotBehavior). Disabled until the epic's enable task (T-083).
]]

local Decoy = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

Decoy.Disabled = true -- // T-083 removes this once the decoy passes Studio testing

local isServer = RunService:IsServer()

local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)

local BotService, DecoyBehavior
if isServer then
	BotService = require(ServerStorage.Server.Core.BotService)
	DecoyBehavior = require(ServerStorage.Server.Logics.BotBehaviors.Decoy)
end

-- // Per-player remover for the one-shot "spawn on next throw" subscription
local pendingThrow: { [Player]: () -> () } = {}

local function clearPending(player: Player)
	local remove = pendingThrow[player]
	if remove then
		remove()
		pendingThrow[player] = nil
	end
end

function Decoy.onPickup(player: Player, _startedAt: number?): number?
	if not isServer then
		return nil
	end

	clearPending(player)
	pendingThrow[player] = SharedTasks.WeaponThrownTasks:Add(function(thrownPlayer: Player)
		if thrownPlayer ~= player then
			return
		end
		BotService.spawn(player, DecoyBehavior)
		-- // Consume the effect so one pickup makes exactly one decoy (triggerEnd -> Decoy.onEnd clears us).
		-- // Required lazily to avoid a load-time cycle (PickupService requires this module).
		local PickupService = require(ServerStorage.Server.Core.PickupService)
		PickupService.triggerEnd(player, "Decoy")
	end)

	return nil -- // no auto-timeout: the effect lasts until the player throws
end

function Decoy.onEnd(player: Player)
	if isServer then
		clearPending(player)
	end
end

return Decoy
