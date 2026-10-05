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
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local ItemService = require(ServerStorage.Server.Core.ItemService)
local SkinService = require(ServerStorage.Server.Core.SkinService)

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

-- // Testing helper (Cmdr `resetdaily`): makes the next daily reward claimable now, as if a day had passed.
-- // With resetStreak, the streak goes back to 0 so the next claim is day 1.
function DailyRewardsService.makeClaimable(player: Player, resetStreak: boolean?): boolean
	local profileData = PlayerDataService.get(player)
	if not profileData then
		return false
	end

	if resetStreak then
		profileData.DailyRewards.Streak = 0
		profileData.DailyRewards.LastClaim = 0
	else
		profileData.DailyRewards.LastClaim = os.time() - SECONDS_IN_DAY
	end

	return true
end

-- // The day (1 to MaxStreakDays) the player's next claim will grant.
function DailyRewardsService.getNextDay(player: Player): number?
	local profileData = PlayerDataService.get(player)
	return if profileData then (profileData.DailyRewards.Streak % DailyRewards.MaxStreakDays) + 1 else nil
end

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
      local reward = DailyRewards.Rewards[newStreak]

      -- // Grant first, so a misconfigured reward doesn't use up the player's claim
      -- // The client is notified through data replication: ItemAcquired for items (ShopController's Inventory listener),
      -- // and DailyClaims shows the currency popup using the day returned below.
      -- // A skin the player already owns becomes FallbackCurrency (convertedToCurrency tells DailyClaims to show it)
      local granted = false
      local convertedToCurrency = false
      if reward and reward.Type == "Currency" then
         granted = EconomyService.addCurrency(player, reward.Value)
      elseif reward and reward.Type == "Item" then
         granted = ItemService.grantItem(player, reward.Value, 1)
      elseif reward and reward.Type == "Skin" then
         if SkinService.ownsSkin(player, reward.Value) then
            granted = EconomyService.addCurrency(player, reward.FallbackCurrency)
            convertedToCurrency = true
         else
            granted = SkinService.grantSkin(player, reward.Value)
         end
      end

      if not granted then
         warn(`DailyRewardsService: failed to grant day {newStreak} reward to {player.Name}`, reward)
         return false
      end

      profileData.DailyRewards.Streak = newStreak
      profileData.DailyRewards.LastClaim = os.time()

      return true, newStreak, convertedToCurrency
	end
end

return DailyRewardsService
