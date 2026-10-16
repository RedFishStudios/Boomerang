local ServerStorage = game:GetService("ServerStorage")

local HitboxService = require(ServerStorage.Server.Core.HitboxService)

return function(_context, visible: boolean)
	HitboxService.setVisible(visible)
	return if visible then "Player hitboxes are now visible." else "Player hitboxes are now hidden."
end
