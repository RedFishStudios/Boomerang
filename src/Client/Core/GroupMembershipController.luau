--[[
	Roblox group membership, client side. Shows Roblox's join prompt when GroupMembershipService asks for it,
	and reports a join back so the server can verify it.

	Author:
	@Soulsplosion
]]

local GroupMembershipController = {}

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local promptJoinEvent = SimpleRemotes.getEvent("GroupMembershipPromptJoin")
local joinReportEvent = SimpleRemotes.getEvent("GroupMembershipJoinReport")

local isPrompting = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function promptJoin(groupId: number)
	if isPrompting then
		return
	end
	isPrompting = true
	local ok, status = pcall(GroupService.PromptJoinAsync, GroupService, groupId)
	isPrompting = false

	if not ok then
		warn(`GroupMembershipController: join prompt failed: {status}`)
		return
	end
	-- // JoinRequestPending (manual-approval group) and None (cancelled) change nothing
	if status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember then
		joinReportEvent:FireServer()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GroupMembershipController.init()
	promptJoinEvent.OnClientEvent:Connect(promptJoin)
end

-- function GroupMembershipController.start() end

return GroupMembershipController
