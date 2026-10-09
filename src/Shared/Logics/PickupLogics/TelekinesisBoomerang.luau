-- // T-077 Telekinesis pickup: while active, the owner can steer their thrown boomerang toward their aim (mouse on
-- // PC, the aim thumbstick on touch) — a gentle bias, not full control. The steering lives in the weapon systems:
-- //   - the owner's client (WeaponController) streams its aim direction and predicts locally,
-- //   - the server (WeaponService) validates it and sets ThrownWeapons.Data[player].TelekinesisBias,
-- //   - the flight loop (WeaponLogics/Boomerang) lerps the boomerang's direction toward that bias.
-- // This module only turns the effect on and off (for the local player on the client).

local TelekinesisBoomerang = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)

local isServer = RunService:IsServer()
local WeaponController
if not isServer then
	WeaponController = require(ReplicatedStorage.Client.Core.WeaponController)
end

function TelekinesisBoomerang.onPickup(player: Player, startedAt: number?): number
	if isServer then
		-- // The server picks up the owner's streamed steer direction in WeaponService while this effect is active.
	elseif player == Players.LocalPlayer then
		WeaponController.setTelekinesisActive(true)
	end

	return (startedAt or workspace:GetServerTimeNow()) + GlobalConfig.GenericEffectTimeout
end

function TelekinesisBoomerang.onEnd(player: Player)
	if isServer then
		local thrownWeaponData = ThrownWeapons.Data[player]
		if thrownWeaponData then
			thrownWeaponData.TelekinesisBias = nil
		end
	elseif player == Players.LocalPlayer then
		WeaponController.setTelekinesisActive(false)
	end
end

return TelekinesisBoomerang
