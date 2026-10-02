--[[
	Group Rewards chest in the lobby (T-045). A lobby station (docs/LOBBY_STATIONS.md) with StationId "GroupRewards".

	- Group members (GroupMembershipService) can claim GlobalConfig.GroupRewardCurrency once every 24 h
	  (same rolling 24 h window as DailyRewardsService).
	- Non-members who trigger the chest get the join prompt; if their join is verified, the claim goes through.

	Author:
	@Soulsplosion
]]

local GroupRewardService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local GroupMembershipService = require(ServerStorage.Server.Core.GroupMembershipService)
local LobbyStationService = require(ServerStorage.Server.Core.LobbyStationService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local STATION_ID = "GroupRewards"
local SECONDS_IN_DAY = 86400 -- // Same as DailyRewardsService

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local claimedEvent = SimpleRemotes.getEvent("GroupRewardClaimed")

local refreshThreads: { [Player]: thread } = {}
-- // Players who used the chest as non-members and were shown the join prompt: claim as soon as they're members
local pendingClaims: { [Player]: boolean } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isClaimable(data: PlayerDataService.Data): boolean
	local lastClaim = data.GroupRewardLastClaim
	return lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)
end

-- // May yield (membership check)
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
	elseif GroupMembershipService.isMember(player) then
		LobbyStationService.setPlayerState(player, STATION_ID, { State = "Active", ActionText = "Claim" })
	else
		LobbyStationService.setPlayerState(player, STATION_ID, { State = "Locked", ActionText = "Join group" })
	end
end

local function claim(player: Player)
	pendingClaims[player] = nil
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

	if GroupMembershipService.isMember(player) then
		claim(player)
	else
		pendingClaims[player] = true
		GroupMembershipService.promptJoin(player)
	end
end

local function onMembershipChanged(player: Player, isMember: boolean)
	if isMember and pendingClaims[player] then
		claim(player)
	else
		refreshState(player)
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
	task.spawn(refreshState, player)
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GroupRewardService.init()
	PlayerDataService.ProfileAddedTasks:Add(function(player: Player)
		task.spawn(refreshState, player)
	end)

	GroupMembershipService.MembershipChangedTasks:Add(onMembershipChanged)

	Players.PlayerRemoving:Connect(function(player)
		local thread = refreshThreads[player]
		if thread then
			task.cancel(thread)
		end
		refreshThreads[player] = nil
		pendingClaims[player] = nil
	end)
end

function GroupRewardService.start()
	LobbyStationService.registerHandler(STATION_ID, onTriggered)
end

-- function GroupRewardService.test() end

return GroupRewardService
