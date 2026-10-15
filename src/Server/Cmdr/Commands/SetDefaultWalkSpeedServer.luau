local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local PlayerStatsLibrary = require(ReplicatedStorage.Shared.Library.PlayerStatsLibrary)
local WalkSpeedLibrary = require(ReplicatedStorage.Shared.Library.WalkSpeedLibrary)

local function describe(): string
	local suffix = if WalkSpeedLibrary.isOverridden() then ` (GlobalConfig default {GlobalConfig.DefaultWalkSpeed})` else " (GlobalConfig default)"
	return `Default walk speed = {WalkSpeedLibrary.getDefault()}{suffix}`
end

return function(_context, speed: number?)
	if speed == nil then
		return describe()
	end
	if speed <= 0 then
		return "The walk speed must be greater than 0."
	end

	WalkSpeedLibrary.setDefault(speed)

	-- // Apply to everyone now. RunSpeed only takes effect on WalkSpeed while a player is in free motion (not aiming), and is
	-- // replicated to the client. A player with an active Speedup keeps their boosted speed until it ends, then returns
	-- // to the new default.
	for _, player in Players:GetPlayers() do
		if not PickupLibrary.hasPickupEffectActive(player.UserId, "Speedup") then
			PlayerStatsLibrary.setStat(player, "RunSpeed", speed)
		end
	end
	return `{describe()}. Applied to all players.`
end
