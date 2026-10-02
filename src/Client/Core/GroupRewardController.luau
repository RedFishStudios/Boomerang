--[[
	Group Rewards chest, client side (T-045): shows the claim popup. The join prompt is GroupMembershipController's.

	Author:
	@Soulsplosion
]]

local GroupRewardController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local claimedEvent = SimpleRemotes.getEvent("GroupRewardClaimed")

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GroupRewardController.init()
	claimedEvent.OnClientEvent:Connect(function(amount: number)
		ItemAcquiredGui.acquiredCustomItem(nil, "Group reward claimed!", `+{amount} Currency`)
	end)
end

-- function GroupRewardController.start() end

return GroupRewardController
