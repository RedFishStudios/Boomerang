--[[
	Per-session player data, server only. Lives for as long as the player is in this server and is never
	saved or replicated to clients. For saved data, use PlayerDataService; for live replicated stats, use
	PlayerStatsLibrary.

	- OptOut: the player doesn't take part in rounds. They aren't added to a round when it starts and
	  can't (re)spawn into one. Cmdr: `optout`.
]]

local PlayerSessionService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type SessionData = {
	OptOut: boolean,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local sessions: { [Player]: SessionData } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PlayerSessionService.OptOutChangedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, optOut: boolean) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function newSessionData(): SessionData
	return {
		OptOut = false,
	}
end

-- // Returns the player's session data, creating it if needed. nil if the player has left.
local function getSession(player: Player): SessionData?
	local session = sessions[player]
	if session then
		return session
	end
	if not player.Parent then
		return nil
	end
	session = newSessionData()
	sessions[player] = session
	return session
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // True if the player has opted out of rounds
function PlayerSessionService.isOptedOut(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.OptOut
end

function PlayerSessionService.setOptOut(player: Player, optOut: boolean)
	local session = getSession(player)
	if not session or session.OptOut == optOut then
		return
	end
	session.OptOut = optOut
	PlayerSessionService.OptOutChangedTasks:Execute("parallel", player, optOut)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PlayerSessionService.init()
	PlayersUtil.PlayerAdded:Add(function(player: Player)
		getSession(player)
	end)

	PlayersUtil.PlayerRemoving:Add(function(player: Player)
		sessions[player] = nil
	end)
end

return PlayerSessionService
