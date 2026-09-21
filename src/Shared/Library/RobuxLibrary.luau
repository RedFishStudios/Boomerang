local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PolicyLibrary = require(script.Parent.PolicyLibrary)

local CACHE_TIMEOUT = 120

local RobuxLibrary = {}

export type RobuxItem = {
	Id: number,
	Display: string,
	IconId: number?, -- Overrides product's real icon
	IsPaidRandomItem: boolean?, -- Item is disabled in a region where paid random items are restricted
}

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

local RobuxItems: {
   ByName: { [string]: RobuxItem },
   ById: { [number]: RobuxItem }
} = {
   ByName = {
      Placeholder = {
         Id = 3714074543,
         Display = "Placeholder",
	   }
   },
   ById = {}
}

local InfoCache: {
   [number]: {
      CachedAt: number,
      Info: RobuxItemInfo
   }
} = {}

-- // Initialize ById tables
for name, product in pairs(RobuxItems.ByName) do
	RobuxItems.ById[product.Id] = product
end

local yieldingConnections: {
   [number]: RBXScriptConnection
} = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function resolveItemIdentifier(product: string | number): number?
	if typeof(product) == "number" then
		return product
	end

   local item = RobuxItems.ByName[product]
   if not item then
      return nil
   end

	return item.Id
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function RobuxLibrary.getItemDataById(id: number): RobuxItem?
   return RobuxItems.ById[id]
end

function RobuxLibrary.getItemInfo(item: string | number): RobuxItemInfo?
	local itemId = resolveItemIdentifier(item)
	if not itemId then
		return nil
	end

	local now = os.clock()
	local cached = InfoCache[itemId]
	if cached and (now - cached.CachedAt) <= CACHE_TIMEOUT then
		return cached.Info
	end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(itemId, Enum.InfoType.Product)
	end)

	if not success or typeof(info) ~= "table" then
		return nil
	end

	InfoCache[itemId] = {
		CachedAt = now,
		Info = info,
	}

	return info
end

function RobuxLibrary.getItemPrice(item: string | number): number?
	local info = RobuxLibrary.getItemInfo(item)
	if not info then
		return nil
	end

	local price = info.PriceInRobux
	if typeof(price) ~= "number" then
		return nil
	end

	return price
end

function RobuxLibrary.promptProductPurchase(player: Player, item: string | number, yieldForAnswer: boolean?): boolean?
	local itemId = resolveItemIdentifier(item)
	if not itemId then
      warn(`Invalid item: ${item}`)
		return nil
	end

	MarketplaceService:PromptProductPurchase(player, itemId)

	if yieldForAnswer then
      local answer = nil
      local elapsed = 0

		if yieldingConnections[itemId] then
			yieldingConnections[itemId]:Disconnect()
			yieldingConnections[itemId] = nil
		end
      yieldingConnections[itemId] = MarketplaceService.PromptProductPurchaseFinished:Connect(function(playerWhoPurchased: Player, purchasedItemId: number, wasPurchased: boolean)
         if playerWhoPurchased == player and purchasedItemId == itemId then
            yieldingConnections[itemId]:Disconnect()
            yieldingConnections[itemId] = nil
         end
         answer = wasPurchased
      end)
      
      repeat
         elapsed = elapsed + task.wait()
      until answer ~= nil or elapsed >= 60

      return answer
	end

	return nil
end

function RobuxLibrary.promptGamepassPurchase(player: Player, gamepassId: number, yieldForAnswer: boolean?): boolean?
	local itemId = gamepassId
	if not itemId then
      warn(`Invalid gamepassId: ${gamepassId}`)
		return nil
	end

	MarketplaceService:PromptGamePassPurchase(player, itemId)

	if yieldForAnswer then
      local answer = nil
      local elapsed = 0

		if yieldingConnections[itemId] then
			yieldingConnections[itemId]:Disconnect()
			yieldingConnections[itemId] = nil
		end
      yieldingConnections[itemId] = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(playerWhoPurchased: Player, purchasedItemId: number, wasPurchased: boolean)
         if playerWhoPurchased == player and purchasedItemId == itemId then
            yieldingConnections[itemId]:Disconnect()
            yieldingConnections[itemId] = nil
         end
         answer = wasPurchased
      end)
      
      repeat
         elapsed = elapsed + task.wait()
      until answer ~= nil or elapsed >= 60

      return answer
	end

	return nil
end

-- // Enforce regional laws
function RobuxLibrary.playerCanPurchaseItem(player: Player, item: string | number): boolean
	local itemId = resolveItemIdentifier(item)
	if not itemId then
		return false
	end

   local itemData = RobuxItems.ById[itemId]
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
return RobuxLibrary