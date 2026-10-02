local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

-- // One-level table formatting so round/vote data is readable in the Cmdr console
local function formatValue(value: any): string
	if typeof(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	for k, v in value do
		table.insert(parts, `{tostring(k)} = {tostring(v)}`)
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

return function(_context)
	local lines = {}
	for k, v in GameStateLibrary.getSnapshot() do
		local value = if typeof(v) == "table" and v.Get then v:Get() else v
		table.insert(lines, `| {k}: {formatValue(value)}`)
	end
	table.sort(lines)
	return `Game state:\n{table.concat(lines, "\n")}`
end
