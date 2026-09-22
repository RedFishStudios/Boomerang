--[[
  DailyRewardsService

  Description:
  Handles daily reward claims

  Author:
  @SixthAtom

  Date:
  20-02-2026
]]

local DailyRewardsService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DailyRewards = require(ReplicatedStorage.Shared.Referential.DailyRewards) 
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SECONDS_IN_DAY = 86400

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local claimRemoteFunction = SimpleRemotes.getFunction("ClaimDailyReward")

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isClaimable(player: Player, profileData)
	local lastClaim = profileData.DailyRewards.LastClaim
	return lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

function DailyRewardsService.init()
	PlayerDataService.ProfileAddedTasks:Add(function(player, data)
		if data.DailyRewards.LastClaim == 0 then
			return -- User has never claimed a daily reward
		end

      -- Test claim streak lost
		local timeSinceClaim = os.time() - data.DailyRewards.LastClaim
		if timeSinceClaim >= SECONDS_IN_DAY * 2 then
			data.DailyRewards.Streak = 0
			data.DailyRewards.LastClaim = 0
		end
	end)

	claimRemoteFunction.OnServerInvoke = function(player: Player)
		local profileData = PlayerDataService.get(player)
      if not profileData then
         return false
      end

      if not isClaimable(player, profileData) then
         return false
      end

      local newStreak = (profileData.DailyRewards.Streak % DailyRewards.MaxStreakDays) + 1
      profileData.DailyRewards.Streak = newStreak
      profileData.DailyRewards.LastClaim = os.time()

      local reward = DailyRewards.Rewards[newStreak]
      if reward.Type == "Currency" then
         -- TODO: notify player
         profileData.Currency = (profileData.Currency or 0) + reward.Value
      elseif reward.Type == "Item" then
         -- TODO: grant player the item
      end

      return true
	end
end

return DailyRewardsService
