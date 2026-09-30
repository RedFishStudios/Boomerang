local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

local PolicyLibrary = require(script.Parent.PolicyLibrary)
local GamepassAccess = require(ReplicatedStorage.Shared.Constants.Enums.GamepassAccess)

local CACHE_TIMEOUT = 120
local NO_ACCESS_CACHE_TIMEOUT = 30

local isServer = RunService:IsServer()

local MarketplaceLibrary = {}
local MarketplaceItems = require(ReplicatedStorage.Shared.Referential.MarketplaceItems)

-- // https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#GetProductInfo
export type RobuxItemInfo = {
   Name: string,
   Description: string?,
   PriceInRobux: number,
   IconImageAssetId: number,
   UserBasePriceInRobux: number,
   PriceDiscountDetails: {
      Type: Enum.DiscountType,
      AmountInRobux: number,
      Percent: number
   },
   ProductId: number,
   ProductType: string,
   Created: string,
   Updated: string,
   ContentRatingType: number,
   MinimumMembershipLevel: number,
   IsPublicDomain: boolean,
   TargetId: number
}

local InfoCache: {
   [number]: {
      CachedAt: number,
      Info: RobuxItemInfo
   }
} = {}

local productPending: {
   [number]: boolean
} = {}

local gamepassPending: {
   [number]: boolean
} = {}

-- // Any access other than NoAccess is cached permanently
local GamepassAccessCache: {
   [number]: { -- UserId
      [number]: { -- GamepassId
         Access: number,
         CachedAt: number
      }
   }
} = {}

local gamepassOwnershipPending: {
   [string]: boolean
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VALUES
-------------------------------------------------------------------------------

MarketplaceLibrary.ProductPurchasePromptFinishedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, productId: number, wasPurchased: boolean) -> ()>
MarketplaceLibrary.GamepassPurchasePromptFinishedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, gamepassId: number, wasPurchased: boolean) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function resolveItemIdentifier(product: string | number): number?
	if typeof(product) == "number" then
		return product
	end

   local item = MarketplaceItems.ByName[product]
   if not item then
      return nil
   end

	return item.Id
end

-- // Returns the raw (non-proxied) profile data, or nil if unavailable in this context
local function getPlayerProfileData(player: Player)
   if isServer then
      local PlayerDataService = require(game:GetService("ServerStorage").Server.Core.PlayerDataService)
      local profile = PlayerDataService.getProfile(player)
      return profile and profile.Data
   end

   if player ~= Players.LocalPlayer then
      return nil
   end
   local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
   return PlayerDataController.get()
end

local function getCachedGamepassAccess(userId: number, gamepassId: number): number?
   local userCache = GamepassAccessCache[userId]
   local cached = userCache and userCache[gamepassId]
   if not cached then
      return nil
   end
   if cached.Access == GamepassAccess.NoAccess and (os.clock() - cached.CachedAt) > NO_ACCESS_CACHE_TIMEOUT then
      return nil
   end
   return cached.Access
end

local function setCachedGamepassAccess(userId: number, gamepassId: number, access: number)
   local userCache = GamepassAccessCache[userId]
   if not userCache then
      userCache = {}
      GamepassAccessCache[userId] = userCache
   end
   userCache[gamepassId] = {
      Access = access,
      CachedAt = os.clock(),
   }
end

local function getGamepassAccess(player: Player, gamepassId: number): number
   local userId = player.UserId
   local cached = getCachedGamepassAccess(userId, gamepassId)
   if cached then
      return cached
   end

   local pendingKey = `{userId}_{gamepassId}`

   -- If already pending, yield until done or timeout
   if gamepassOwnershipPending[pendingKey] then
      local timeout = 0
      while gamepassOwnershipPending[pendingKey] and timeout < 50 do
         task.wait(0.1)
         timeout += 1
      end
      return getCachedGamepassAccess(userId, gamepassId) or GamepassAccess.NoAccess
   end

   local profileData = getPlayerProfileData(player)
   if profileData and profileData.GiftedPasses and table.find(profileData.GiftedPasses, gamepassId) then
      setCachedGamepassAccess(userId, gamepassId, GamepassAccess.Gifted)
      return GamepassAccess.Gifted
   end

   gamepassOwnershipPending[pendingKey] = true

   local success, owns = pcall(function()
      return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
   end)

   gamepassOwnershipPending[pendingKey] = nil

   if not success then
      warn(`UserOwnsGamePassAsync failed for {userId}, {gamepassId}: {owns}`)
      return GamepassAccess.NoAccess
   end

   local access = if owns then GamepassAccess.Owns else GamepassAccess.NoAccess
   -- // Don't cache a negative result if gifts couldn't be checked yet
   if access ~= GamepassAccess.NoAccess or profileData then
      setCachedGamepassAccess(userId, gamepassId, access)
   end
   return access
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function MarketplaceLibrary.getItemId(item: string | number): number?
	local itemId = resolveItemIdentifier(item)
	return itemId
end

function MarketplaceLibrary.getItemDataById(id: number): MarketplaceItems.RobuxItem?
   return MarketplaceItems.ById[id]
end

function MarketplaceLibrary.getProductInfo(item: string | number): RobuxItemInfo?
	local itemId = resolveItemIdentifier(item)
	if not itemId then
		return nil
	end

	local now = os.clock()
	local cached = InfoCache[itemId]
	if cached and (now - cached.CachedAt) <= CACHE_TIMEOUT then
		return cached.Info
	end

	-- If already pending, yield until done or timeout
	if productPending[itemId] then
		local timeout = 0
		while productPending[itemId] and timeout < 50 do
			task.wait(0.1)
			timeout += 1
			local cached2 = InfoCache[itemId]
			if cached2 and (os.clock() - cached2.CachedAt) <= CACHE_TIMEOUT then
				return cached2.Info
			end
		end
		-- Return cached data if available after wait, otherwise nil
		local cached2 = InfoCache[itemId]
		if cached2 and (os.clock() - cached2.CachedAt) <= CACHE_TIMEOUT then
			return cached2.Info
		end
		return nil
	end

	-- Mark as pending
	productPending[itemId] = true

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(itemId, Enum.InfoType.Product)
	end)

	productPending[itemId] = nil

	if not success or typeof(info) ~= "table" then
		return nil
	end

	InfoCache[itemId] = {
		CachedAt = now,
		Info = info,
	}

	return info
end

function MarketplaceLibrary.getProductPrice(item: string | number): number?
	local info = MarketplaceLibrary.getProductInfo(item)
	if not info then
		return nil
	end

	local price = info.PriceInRobux
	if typeof(price) ~= "number" then
		return nil
	end

	return price
end


function MarketplaceLibrary.promptProductPurchase(player: Player, item: string | number, yieldForAnswer: boolean?): boolean?
	local itemId = resolveItemIdentifier(item)
	if not itemId then
      warn(`Invalid item: ${item}`)
		return nil
	end

	MarketplaceService:PromptProductPurchase(player, itemId)

	if yieldForAnswer then
      local answer = nil
      local elapsed = 0

      local destroyer
      destroyer = MarketplaceLibrary.ProductPurchasePromptFinishedTasks:Add(function(playerWhoPurchased, purchasedItemId, wasPurchased)
         if playerWhoPurchased == player and purchasedItemId == itemId then
            answer = wasPurchased
            destroyer()
         end
      end)
      
      repeat
         elapsed = elapsed + task.wait()
      until answer ~= nil or elapsed >= 60

      -- Cleanup task if it wasn't already cleaned up by the event
      destroyer()
      return answer
	end

	return nil
end

-- // Player is optional on the client (defaults to LocalPlayer) and required on the server
function MarketplaceLibrary.promptDeveloperProduct(item: string | number, player: Player?, yieldForAnswer: boolean?): boolean?
   local targetPlayer = player or (if isServer then nil else Players.LocalPlayer)
   if not targetPlayer then
      warn(`promptDeveloperProduct requires a player on the server`)
      return nil
   end
   return MarketplaceLibrary.promptProductPurchase(targetPlayer, item, yieldForAnswer)
end

function MarketplaceLibrary.getGamepassInfo(item: string | number): RobuxItemInfo?
	local itemId = resolveItemIdentifier(item)
	if not itemId then
		return nil
	end

	local now = os.clock()
	local cached = InfoCache[itemId]
	if cached and (now - cached.CachedAt) <= CACHE_TIMEOUT then
		return cached.Info
	end

	-- If already pending, yield until done or timeout
	if gamepassPending[itemId] then
		local timeout = 0
		while gamepassPending[itemId] and timeout < 50 do
			task.wait(0.1)
			timeout += 1
			local cached2 = InfoCache[itemId]
			if cached2 and (os.clock() - cached2.CachedAt) <= CACHE_TIMEOUT then
				return cached2.Info
			end
		end
		-- Return cached data if available after wait, otherwise nil
		local cached2 = InfoCache[itemId]
		if cached2 and (os.clock() - cached2.CachedAt) <= CACHE_TIMEOUT then
			return cached2.Info
		end
		return nil
	end

	-- Mark as pending
	gamepassPending[itemId] = true

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(itemId, Enum.InfoType.GamePass)
	end)

	gamepassPending[itemId] = nil

	if not success or typeof(info) ~= "table" then
		return nil
	end

	InfoCache[itemId] = {
		CachedAt = now,
		Info = info,
	}

	return info
end

function MarketplaceLibrary.getGamepassPrice(item: string | number): number?
	local info = MarketplaceLibrary.getGamepassInfo(item)
	if not info then
		return nil
	end

	local price = info.PriceInRobux
	if typeof(price) ~= "number" then
		return nil
	end

	return price
end

function MarketplaceLibrary.promptGamepassPurchase(player: Player, gamepassId: number, yieldForAnswer: boolean?): boolean?
	local itemId = gamepassId
	if not itemId then
      warn(`Invalid gamepassId: ${gamepassId}`)
		return nil
	end

	MarketplaceService:PromptGamePassPurchase(player, itemId)

	if yieldForAnswer then
      local answer = nil
      local elapsed = 0

      local destroyer
      destroyer = MarketplaceLibrary.GamepassPurchasePromptFinishedTasks:Add(function(playerWhoPurchased: Player, purchasedItemId: number, wasPurchased: boolean)
         if playerWhoPurchased == player and purchasedItemId == itemId then
            answer = wasPurchased
            destroyer()
         end
      end)
      
      repeat
         elapsed = elapsed + task.wait()
      until answer ~= nil or elapsed >= 60

      -- Cleanup task if it wasn't already cleaned up by the event
      destroyer()
      return answer
	end

	return nil
end

-- // Enforce regional laws
function MarketplaceLibrary.playerCanPurchaseItem(player: Player, item: string | number): boolean
	local itemId = resolveItemIdentifier(item)
	if not itemId then
		return false
	end

   local itemData = MarketplaceItems.ById[itemId]
   if not itemData then
      return false
   end

   if itemData.IsPaidRandomItem then
      local policyData = PolicyLibrary.getPlayerPolicyData(player.UserId)
      if policyData then
         if policyData.ArePaidRandomItemsRestricted then
            return false
         end
      else
         return false
      end
   end

	return true
end
   
function MarketplaceLibrary.playerOwnsGamepass(player: Player, gamepass: string | number): boolean
	local gamepassId = resolveItemIdentifier(gamepass)
	if not gamepassId then
		return false
	end

   return getGamepassAccess(player, gamepassId) ~= GamepassAccess.NoAccess
end

function MarketplaceLibrary.init()
   Players.PlayerRemoving:Connect(function(player: Player)
      GamepassAccessCache[player.UserId] = nil
   end)
   MarketplaceService.PromptProductPurchaseFinished:Connect(function(player: Player, productId: number, wasPurchased: boolean)
      MarketplaceLibrary.ProductPurchasePromptFinishedTasks:Execute("parallel", player, productId, wasPurchased)
   end)
   MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamepassId: number, wasPurchased: boolean)
      if wasPurchased then
         setCachedGamepassAccess(player.UserId, gamepassId, GamepassAccess.Owns)
      end
      MarketplaceLibrary.GamepassPurchasePromptFinishedTasks:Execute("parallel", player, gamepassId, wasPurchased)
   end)
end

return MarketplaceLibrary