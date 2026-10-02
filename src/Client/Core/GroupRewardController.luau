--[[
	Group Rewards chest, client side (T-045). The server (GroupRewardService) asks for the join prompt when a
	non-member uses the chest; if the player joins, this tells the server so it can re-check and grant.

	Author:
	@Soulsplosion
]]

local GroupRewardController = {}

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local promptJoinEvent = SimpleRemotes.getEvent("GroupRewardPromptJoin")
local joinedEvent = SimpleRemotes.getEvent("GroupRewardJoined")
local claimedEvent = SimpleRemotes.getEvent("GroupRewardClaimed")

local isPrompting = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function promptJoin()
	if isPrompting then
		return
	end
	isPrompting = true
	local ok, status = pcall(GroupService.PromptJoinAsync, GroupService, GlobalConfig.GroupId)
	isPrompting = false

	if not ok then
		warn(`GroupRewardController: join prompt failed: {status}`)
		return
	end
	-- // JoinRequestPending (manual-approval group) and None (cancelled) grant nothing
	if status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember then
		joinedEvent:FireServer()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GroupRewardController.init()
	promptJoinEvent.OnClientEvent:Connect(promptJoin)
	claimedEvent.OnClientEvent:Connect(function(amount: number)
		ItemAcquiredGui.acquiredCustomItem(nil, "Group reward claimed!", `+{amount} Currency`)
	end)
end

-- function GroupRewardController.start() end

return GroupRewardController
