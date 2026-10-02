--[[
	Roblox group (community) membership, server side. The one place that decides whether a player is in
	the game's group. Features that care (e.g. the Group Rewards chest, T-045) call isMember / promptJoin
	and listen to MembershipChangedTasks; they never call IsInGroup / GetGroupsAsync themselves.

	- The group is GlobalConfig.GroupId, unless overridden for this server with setGroupId (Cmdr `setgroupid`).
	- isMember: first answer comes from Player:IsInGroup (cached by Roblox for about a minute), then from this
	  service's own cache. refreshMembership re-checks with the uncached GroupService:GetGroupsAsync.
	- promptJoin: shows Roblox's join prompt on the client (GroupMembershipController). If the player joins,
	  the client reports it and the server verifies with refreshMembership (never trusts the client alone).
	- Developers can simulate membership per player (Cmdr `simulategroupmember`); a simulation overrides the
	  real answer until cleared.

	Author:
	@Soulsplosion
]]

local GroupMembershipService = {}

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local JOIN_REPORT_COOLDOWN = 3 -- // Seconds between two "I joined" reports from the same player (each one is a web call)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local promptJoinEvent = SimpleRemotes.getEvent("GroupMembershipPromptJoin")
local joinReportEvent = SimpleRemotes.getEvent("GroupMembershipJoinReport")

local groupIdOverride: number? = nil
-- // Real membership, cached for the current group id
local realMemberships: { [Player]: boolean } = {}
-- // Developer simulation: true/false overrides the real answer
local simulatedMemberships: { [Player]: boolean } = {}
local lastJoinReports: { [Player]: number } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-- // Fired when a player's effective membership may have changed (join verified, simulation, group id change)
GroupMembershipService.MembershipChangedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, isMember: boolean) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function notifyChanged(player: Player)
	task.spawn(function()
		local isMember = GroupMembershipService.isMember(player)
		if player.Parent then
			GroupMembershipService.MembershipChangedTasks:Execute("parallel", player, isMember)
		end
	end)
end

local function onJoinReport(player: Player)
	local now = os.clock()
	if now - (lastJoinReports[player] or 0) < JOIN_REPORT_COOLDOWN then
		return
	end
	lastJoinReports[player] = now
	GroupMembershipService.refreshMembership(player)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GroupMembershipService.getGroupId(): number
	return groupIdOverride or GlobalConfig.GroupId
end

-- // Changes the group for this server only (not saved). nil goes back to GlobalConfig.GroupId.
function GroupMembershipService.setGroupId(groupId: number?)
	groupIdOverride = if groupId == GlobalConfig.GroupId then nil else groupId
	table.clear(realMemberships)
	for _, player in Players:GetPlayers() do
		notifyChanged(player)
	end
end

-- // May yield (web call) the first time for a player
function GroupMembershipService.isMember(player: Player): boolean
	local simulated = simulatedMemberships[player]
	if simulated ~= nil then
		return simulated
	end

	local cached = realMemberships[player]
	if cached ~= nil then
		return cached
	end

	local groupId = GroupMembershipService.getGroupId()
	local ok, isMember = pcall(player.IsInGroup, player, groupId)
	if not ok then
		warn(`GroupMembershipService: IsInGroup failed for {player.Name}: {isMember}`)
		return false -- // Not cached, so the next call tries again
	end
	if player.Parent and GroupMembershipService.getGroupId() == groupId then
		realMemberships[player] = isMember
	end
	return isMember
end

-- // Re-checks with the uncached GetGroupsAsync. Yields. Returns the effective membership.
function GroupMembershipService.refreshMembership(player: Player): boolean
	local groupId = GroupMembershipService.getGroupId()
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok then
		warn(`GroupMembershipService: GetGroupsAsync failed for {player.Name}: {groups}`)
		return GroupMembershipService.isMember(player)
	end

	local isMember = false
	for _, group in groups do
		if group.Id == groupId then
			isMember = true
			break
		end
	end

	if player.Parent and GroupMembershipService.getGroupId() == groupId then
		local changed = realMemberships[player] ~= isMember
		realMemberships[player] = isMember
		if changed then
			notifyChanged(player)
		end
	end
	return GroupMembershipService.isMember(player)
end

-- // Shows Roblox's join prompt to the player. If they join, MembershipChangedTasks fires once verified.
function GroupMembershipService.promptJoin(player: Player)
	promptJoinEvent:FireClient(player, GroupMembershipService.getGroupId())
end

-- // Developer testing (Cmdr `simulategroupmember`): true/false forces the answer for this player, nil uses the real one
function GroupMembershipService.setSimulatedMembership(player: Player, isMember: boolean?)
	simulatedMemberships[player] = isMember
	notifyChanged(player)
end

function GroupMembershipService.getSimulatedMembership(player: Player): boolean?
	return simulatedMemberships[player]
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GroupMembershipService.init()
	joinReportEvent.OnServerEvent:Connect(onJoinReport)

	Players.PlayerRemoving:Connect(function(player)
		realMemberships[player] = nil
		simulatedMemberships[player] = nil
		lastJoinReports[player] = nil
	end)
end

-- function GroupMembershipService.start() end

-- function GroupMembershipService.test() end

return GroupMembershipService
