local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AuthorityViewLibrary = require(ReplicatedStorage.Shared.Library.AuthorityViewLibrary)

return function(_context, enabled: boolean)
	AuthorityViewLibrary.setEnabled(enabled)
	return if enabled
		then "Authority view ON: a neon red ball now shows where the server thinks each thrown boomerang is."
		else "Authority view OFF."
end
