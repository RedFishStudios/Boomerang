--[[
	BoomerangColorUtil

	The color that identifies a player's boomerang to the viewer: the thrown-boomerang trail, the recall SelectionRing, and
	anything else that should match them (T-090). Moved here from Boomerang.luau so every feature uses the same rule:
	  - the local player's own: white (GlobalConfig.MyBoomerangTrailColor)
	  - a player in a free-for-all (no team, or a team with friendly fire): red (GlobalConfig.EnemyBoomerangTrailColor)
	  - a player on a team: the team's color
	Call it on the viewing client (it depends on who the local player is).
]]

local BoomerangColorUtil = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local GameTeamLibrary = require(ReplicatedStorage.Shared.Library.GameTeamLibrary)

function BoomerangColorUtil.getColor(ownerPlayer: Player?): Color3
	if not ownerPlayer then
		return GlobalConfig.EnemyBoomerangTrailColor
	end
	if ownerPlayer == Players.LocalPlayer then
		return GlobalConfig.MyBoomerangTrailColor
	end
	local team = ownerPlayer.Team
	if GameTeamLibrary.hasFriendlyFire(team) then
		return GlobalConfig.EnemyBoomerangTrailColor
	end
	return if team then team.TeamColor.Color else GlobalConfig.EnemyBoomerangTrailColor
end

return BoomerangColorUtil
