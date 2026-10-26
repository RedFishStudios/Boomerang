local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local HitboxService = require(ServerStorage.Server.Core.HitboxService)
local BotService = require(ServerStorage.Server.Core.BotService)
local Boomerang = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Boomerang)
local Stab = require(ReplicatedStorage.Shared.Logics.AbilityLogics.Stab)

-- // One switch for every hit-detection visualizer (the server draws them, so everyone sees them)
return function(_context, visible: boolean)
	HitboxService.setVisible(visible)
	BotService.setHitboxesVisible(visible)
	Stab.setSwingVisualizerEnabled(visible)
	Boomerang.setRaycastVisualizersEnabled(visible)
	return if visible
		then "Hit visualizers ON: player and bot Hitboxes, slash wedges and boomerang hit sweeps are now shown."
		else "Hit visualizers OFF."
end
