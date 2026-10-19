local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LagCompensationLibrary = require(ReplicatedStorage.Shared.Library.LagCompensationLibrary)

local function describe(): string
	local milliseconds = LagCompensationLibrary.getRewindMilliseconds()
	local default = LagCompensationLibrary.getDefaultMilliseconds()
	local suffix = if milliseconds == default then " (default)" else ` (default {default} ms)`
	if milliseconds <= 0 then
		return `Lag compensation OFF{suffix}`
	end
	return `Lag compensation ON, rewinds at most {milliseconds} ms{suffix}`
end

return function(_context, milliseconds: number?)
	if milliseconds == nil then
		return describe()
	end
	local maximum = LagCompensationLibrary.getMaxMilliseconds()
	if milliseconds < 0 or milliseconds > maximum then
		return `The value must be between 0 and {maximum} ms.`
	end
	LagCompensationLibrary.setRewindMilliseconds(milliseconds)
	return describe()
end
