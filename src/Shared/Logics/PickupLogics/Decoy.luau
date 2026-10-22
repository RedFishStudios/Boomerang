--[[
	Decoy pickup (T-080)

	T-108: the player spawns the decoy with the on-screen button (UsePickupButtons GUI), at any time; that uses up the
	effect (one pickup = one decoy). It no longer spawns by itself on the next throw. The decoy entity + movement live in
	the bot layer (BotService + the Decoy BotBehavior). Enabled (T-083): spawns from the normal pickup pool like other pickups.
]]

local Decoy = {}

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local isServer = RunService:IsServer()

local BotService, DecoyBehavior
if isServer then
	BotService = require(ServerStorage.Server.Core.BotService)
	DecoyBehavior = require(ServerStorage.Server.Logics.BotBehaviors.Decoy)
end

Decoy.UseButton = true
Decoy.ConsumedOnUse = true

-- // T-108: usable at any time while the effect is held
function Decoy.canUse(_player: Player): boolean
	return true
end

-- // T-108: the button was pressed: spawn the decoy, then the effect is used up
function Decoy.onUse(player: Player)
	if not isServer then
		return
	end
	BotService.spawn(player, DecoyBehavior)
	-- // Required lazily to avoid a load-time cycle (PickupService requires this module)
	local PickupService = require(ServerStorage.Server.Core.PickupService)
	PickupService.triggerEnd(player, "Decoy")
end

function Decoy.onPickup(_player: Player, _startedAt: number?): number?
	return nil -- // no auto-timeout: the effect lasts until the player uses it (or loses it: death, round end)
end

function Decoy.onEnd(_player: Player) end

return Decoy
