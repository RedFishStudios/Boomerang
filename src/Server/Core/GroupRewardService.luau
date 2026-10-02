--[[
	Group Rewards chest in the lobby (T-045). A lobby station (docs/LOBBY_STATIONS.md) with StationId "GroupRewards".

	- Members of GlobalConfig.GroupId can claim GlobalConfig.GroupRewardCurrency once every 24 h
	  (same rolling 24 h window as DailyRewardsService).
	- Non-members who trigger the chest get Roblox's join prompt (GroupRewardController). If they join,
	  the client asks again and the server re-checks membership with the uncached GroupService:GetGroupsAsync
	  (Player:IsInGroup is cached on the server for about a minute) before granting.

	Author:
	@Soulsplosion
]]

local GroupRewardService = {}

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local LobbyStationService = require(ServerStorage.Server.Core.LobbyStationService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local STATION_ID = "GroupRewards"
local SECONDS_IN_DAY = 86400 -- // Same as DailyRewardsService
local JOINED_RETRY_COOLDOWN = 3 -- // Seconds between two "I joined" checks from the same player (each one is a web call)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local promptJoinEvent = SimpleRemotes.getEvent("GroupRewardPromptJoin")
local joinedEvent = SimpleRemotes.getEvent("GroupRewardJoined")
local claimedEvent = SimpleRemotes.getEvent("GroupRewardClaimed")

-- // Membership confirmed this session (a player who joins mid-session stays confirmed)
local confirmedMembers: { [Player]: boolean } = {}
local refreshThreads: { [Player]: thread } = {}
local lastJoinedChecks: { [Player]: number } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isClaimable(data: PlayerDataService.Data): boolean
	local lastClaim = data.GroupRewardLastClaim
	return lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)
end

-- // Cached by Roblox on the server (about a minute): fine for the first check
local function isMemberCached(player: Player): boolean
	local ok, isMember = pcall(player.IsInGroup, player, GlobalConfig.GroupId)
	return ok and isMember
end

-- // Uncached web call: used after the player says they joined
local function isMemberFresh(player: Player): boolean
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok then
		warn(`GroupRewardService: GetGroupsAsync failed for {player.Name}: {groups}`)
		return false
	end
	for _, group in groups do
		if group.Id == GlobalConfig.GroupId then
			return true
		end
	end
	return false
end

local function refreshState(player: Player)
	local data = PlayerDataService.get(player)
	if not data or not player.Parent then
		return
	end

	local thread = refreshThreads[player]
	if thread and coroutine.running() ~= thread then
		task.cancel(thread)
	end
	refreshThreads[player] = nil

	if not isClaimable(data) then
		LobbyStationService.setPlayerState(player, STATION_ID, { State = "Claimed", PromptEnabled = false })
		-- // Unlock again when the 24 h are up, if the player is still here
		local remaining = SECONDS_IN_DAY - (os.time() - data.GroupRewardLastClaim)
		refreshThreads[player] = task.delay(remaining + 1, refreshState, player)
	elseif confirmedMembers[player] then
		LobbyStationService.setPlayerState(player, STATION_ID, { State = "Active", ActionText = "Claim" })
	else
		LobbyStationService.setPlayerState(player, STATION_ID, { State = "Locked", ActionText = "Join group" })
	end
end

local function claim(player: Player)
	local data = PlayerDataService.get(player)
	if not data or not isClaimable(data) then
		return
	end

	local amount = GlobalConfig.GroupRewardCurrency
	if not EconomyService.addCurrency(player, amount) then
		warn(`GroupRewardService: failed to grant the group reward to {player.Name}`)
		return
	end
	data.GroupRewardLastClaim = os.time()

	claimedEvent:FireClient(player, amount)
	refreshState(player)
end

local function onTriggered(player: Player)
	local data = PlayerDataService.get(player)
	if not data or not isClaimable(data) then
		return
	end

	if confirmedMembers[player] or isMemberCached(player) then
		confirmedMembers[player] = true
		claim(player)
	else
		promptJoinEvent:FireClient(player)
	end
end

local function onJoined(player: Player)
	local now = os.clock()
	if now - (lastJoinedChecks[player] or 0) < JOINED_RETRY_COOLDOWN then
		return
	end
	lastJoinedChecks[player] = now

	local data = PlayerDataService.get(player)
	if not data or not isClaimable(data) then
		return
	end

	if confirmedMembers[player] or isMemberFresh(player) then
		confirmedMembers[player] = true
		claim(player)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Testing helper (Cmdr `resetgroupreward`): makes the chest claimable now
function GroupRewardService.resetClaim(player: Player): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	data.GroupRewardLastClaim = 0
	refreshState(player)
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GroupRewardService.init()
	PlayerDataService.ProfileAddedTasks:Add(function(player: Player)
		task.spawn(function()
			confirmedMembers[player] = isMemberCached(player) or nil
			refreshState(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local thread = refreshThreads[player]
		if thread then
			task.cancel(thread)
		end
		refreshThreads[player] = nil
		confirmedMembers[player] = nil
		lastJoinedChecks[player] = nil
	end)

	joinedEvent.OnServerEvent:Connect(onJoined)
end

function GroupRewardService.start()
	LobbyStationService.registerHandler(STATION_ID, onTriggered)
end

-- function GroupRewardService.test() end

return GroupRewardService
