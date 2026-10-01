--[[
	CmdrService

	Description:
	Sets up Cmdr, the developer console used for testing (open it with F2).
	Registers Cmdr's built-in commands and the project's own commands in Server/Cmdr/Commands,
	and decides who is allowed to run commands.

	Who can use Cmdr:
	- In Studio: everyone (local testing).
	- In live servers: players in ADMIN_USER_IDS, or (for group-owned games) group members at or above MIN_ADMIN_GROUP_RANK.
	The server sets the "CmdrAdmin" attribute on allowed players; CmdrController only enables the console for them,
	and the BeforeRun hook blocks every command from anyone else.
]]

local CmdrService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Cmdr = require(ReplicatedStorage.Shared.Packages.Cmdr)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local IS_STUDIO = RunService:IsStudio()

-- // UserIds allowed to use Cmdr in live servers
local ADMIN_USER_IDS: { number } = {
	-- TODO:RELEASE placeholder (add the developers' Roblox UserIds)
}

-- // For group-owned games: minimum rank in the owning group to use Cmdr in live servers (255 = group owner)
local MIN_ADMIN_GROUP_RANK = 255 -- TODO:RELEASE placeholder

local ADMIN_ATTRIBUTE = "CmdrAdmin"

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function computeIsAdmin(player: Player): boolean
	if IS_STUDIO then
		return true
	end

	if table.find(ADMIN_USER_IDS, player.UserId) then
		return true
	end

	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end

	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= MIN_ADMIN_GROUP_RANK
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- Returns true if the player may run developer commands. Server-authoritative.
function CmdrService.isAdmin(player: Player): boolean
	return player:GetAttribute(ADMIN_ATTRIBUTE) == true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CmdrService.init()
	Cmdr:RegisterDefaultCommands()
	Cmdr:RegisterTypesIn(ServerStorage.Server.Cmdr.Types)
	Cmdr:RegisterCommandsIn(ServerStorage.Server.Cmdr.Commands)

	-- // Runs before every command, on the server. Returning a string blocks the command with that message.
	Cmdr:RegisterHook("BeforeRun", function(context)
		local executor = context.Executor
		if executor and not CmdrService.isAdmin(executor) then
			return "You don't have permission to run this command."
		end
		return nil
	end)

	local function onPlayerAdded(player: Player)
		player:SetAttribute(ADMIN_ATTRIBUTE, computeIsAdmin(player))
	end

	PlayersUtil.PlayerAdded:Add(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return CmdrService
