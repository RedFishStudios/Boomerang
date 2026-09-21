--[[
]]

local PolicyLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local PolicyService = game:GetService("PolicyService")
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

local isServer = game:GetService("RunService"):IsServer()

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // https://create.roblox.com/docs/reference/engine/classes/PolicyService#GetPolicyInfoForPlayerAsync
type PlayerPolicyData = {
   AreAdsAllowed: boolean,
   ArePaidRandomItemsRestricted: boolean,
   IsContentSharingAllowed: boolean,
   IsEligibleToPurchaseCommerceProduct: boolean,
   IsEligibleToPurchaseSubscription: boolean,
   IsPaidItemTradingAllowed: boolean,
   IsPhotoToAvatarAllowed: boolean,
   IsSubjectToChinaPolicies: boolean,
   IsEndlessContentLoadAllowed: boolean,
   IsEndlessContentAutoplayAllowed: boolean
}

export type PlayerPolicyCache = {
   Data: PlayerPolicyData,
   LastUpdated: number?
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local playerPolicyCache: {
   [number]: PlayerPolicyCache
} = {}

local playerPolicyPending: {
   [number]: boolean
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // MAY YIELD
function PolicyLibrary.getPlayerPolicyData(userId: number): PlayerPolicyData?
   if playerPolicyCache[userId] and playerPolicyCache[userId].Data then
       return playerPolicyCache[userId].Data
   end

   -- If already pending, yield until done or timeout
   if playerPolicyPending[userId] then
       local timeout = 0
       while playerPolicyPending[userId] and timeout < 50 do
           task.wait(0.1)
           timeout += 1
           if playerPolicyCache[userId] and playerPolicyCache[userId].Data then
               return playerPolicyCache[userId].Data
           end
       end
       -- Return cached data if available after wait, otherwise nil
       if playerPolicyCache[userId] and playerPolicyCache[userId].Data then
           return playerPolicyCache[userId].Data
       end
       return nil
   end

   -- Mark as pending
   playerPolicyPending[userId] = true

   local tries = 0
   while tries < 3 do
       tries += 1
       local success, data = pcall(function()
           return PolicyService:GetPolicyInfoForPlayerAsync(userId)
       end)

       if success then
           playerPolicyCache[userId] = {
               Data = data,
               LastUpdated = os.time()
           }
           playerPolicyPending[userId] = nil
           return data
       else
         task.wait(tries * 1.5)
       end
   end

   playerPolicyPending[userId] = nil
   return nil
end

function PolicyLibrary.arePaidRandomItemsRestricted(player: Player): boolean
	local policyData = PolicyLibrary.getPlayerPolicyData(player.UserId)
   if policyData then
      return policyData.ArePaidRandomItemsRestricted
   end

   return true
end

function PolicyLibrary.isPaidItemTradingAllowed(player: Player): boolean
	local policyData = PolicyLibrary.getPlayerPolicyData(player.UserId)
   if policyData then
      return policyData.IsPaidItemTradingAllowed
   end

   return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PolicyLibrary.init()
   if isServer then
      PlayersUtil.PlayerRemoving:Connect(function(player)
         playerPolicyCache[player.UserId] = nil
         playerPolicyPending[player.UserId] = nil
      end)
   else
   end
end

-- function PolicyLibrary.start() end

-- function PolicyLibrary.test() end

return PolicyLibrary