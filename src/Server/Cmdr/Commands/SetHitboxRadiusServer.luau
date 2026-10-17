local ServerStorage = game:GetService("ServerStorage")

local HitboxService = require(ServerStorage.Server.Core.HitboxService)

local MAX_RADIUS = 25

local function describe(): string
	local default = HitboxService.getDefaultRadius()
	local radius = HitboxService.getRadius()
	local suffix = if radius == default then " (default)" else ` (default {default})`
	return `Hitbox radius = {radius}{suffix}, {radius * 2} studs across`
end

return function(_context, radius: number?)
	if radius == nil then
		return describe()
	end
	if radius <= 0 or radius > MAX_RADIUS then
		return `The radius must be greater than 0 and at most {MAX_RADIUS}.`
	end
	HitboxService.setRadius(radius)
	return `{describe()}. Applied to all current hitboxes and new spawns.`
end
