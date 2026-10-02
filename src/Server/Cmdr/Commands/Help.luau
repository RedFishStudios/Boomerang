-- // Replaces Cmdr's built-in help: every other command first, then the Boomerang commands (group DevTesting) and a short
-- // usage tip at the very bottom, so the most useful part is visible without scrolling up.
-- // Runs on the client (ClientRun), using the replicated command registry.

local GROUP_ORDER = { Help = 1, DevTesting = 1000 } -- // Lower = printed earlier; DevTesting last (bottom of the console)

local HEADER_COLOR = Color3.fromRGB(230, 126, 34)
local TEXT_COLOR = Color3.fromRGB(230, 230, 230)

return {
	Name = "help",
	Aliases = { "commands", "cmds" },
	Description = "Lists every available command with a short summary, or explains one command.",
	Group = "Help",
	Args = {
		{
			Type = "command",
			Name = "command",
			Description = "A command to explain in detail",
			Optional = true,
		},
	},

	ClientRun = function(context, commandName)
		local registry = context.Cmdr.Registry

		if commandName then
			local command = registry:GetCommand(commandName)
			context:Reply(`{command.Name}: {command.Description or ""}`, HEADER_COLOR)
			if command.Aliases and #command.Aliases > 0 then
				context:Reply(`Aliases: {table.concat(command.Aliases, ", ")}`, TEXT_COLOR)
			end
			for i, arg in ipairs(command.Args or {}) do
				if type(arg) == "table" then
					context:Reply(`  #{i} {arg.Name}{if arg.Optional then "?" else ""} ({arg.Type}): {arg.Description or ""}`, TEXT_COLOR)
				end
			end
			return ""
		end


		local commands = table.clone(registry:GetCommands())
		table.sort(commands, function(a, b)
			local groupA, groupB = a.Group or "Other", b.Group or "Other"
			if groupA ~= groupB then
				local orderA, orderB = GROUP_ORDER[groupA] or 99, GROUP_ORDER[groupB] or 99
				if orderA ~= orderB then
					return orderA < orderB
				end
				return groupA < groupB
			end
			return a.Name < b.Name
		end)

		local lastGroup = nil
		for _, command in ipairs(commands) do
			local group = command.Group or "Other"
			if group ~= lastGroup then
				local title = if group == "DevTesting" then "Boomerang commands" else group
				context:Reply(`\n{title}`, HEADER_COLOR)
				lastGroup = group
			end
			context:Reply(`  {command.Name} - {command.Description or ""}`, TEXT_COLOR)
		end

		context:Reply("\nPress F2 to open/close. Tab autocompletes. Type: help <command> for details.", HEADER_COLOR)
		context:Reply("Player shortcuts: . = me, * = everyone, ** = everyone else, ? = random", TEXT_COLOR)
		return ""
	end,
}
