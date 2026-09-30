local ProductService = {}

local MarketplaceService = game:GetService("MarketplaceService")

local ServerMods = game.ServerStorage.Server
local SharedMods = game.ReplicatedStorage.Shared

local MarketplaceLibrary = require(SharedMods.Library.MarketplaceLibrary)

local ProductLogics = ServerMods.Logics.ProductLogics
local ProductLogicTemplate = require(ProductLogics:WaitForChild("Template"))
type ProductLogic = ProductLogicTemplate.ProductLogic
local RegisteredProductLogics: {
   [number]: ProductLogic
} = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ReceiptInfo = {
   PurchaseId: string, -- Unique identifier for this purchase
   PlayerId: number, -- Player id
   ProductId: number, -- Product id
   PlaceIdWherePurchased: number, -- Place id where the purchase was made
   ProductPurchaseChannel: Enum.ProductPurchaseChannel
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(productId: number): ProductLogic?
   if RegisteredProductLogics[productId] then
      return RegisteredProductLogics[productId]
   end
   warn(`No logic found for productId: ${productId}`)
   return nil
end

-- // Process receipt
local function processReceipt(receiptInfo: ReceiptInfo)
	local logic = getLogic(receiptInfo.ProductId)

	if not logic then
		warn("No logic for developer product:", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

   local userId = receiptInfo.PlayerId
   local player = game:GetService("Players"):GetPlayerByUserId(userId)
   if not player then
      warn(`Player with userId ${userId} not found`)
      return Enum.ProductPurchaseDecision.NotProcessedYet
   end

	local success, result = pcall(function()
		return logic.grant(player)
	end)

	if not success then
		warn("Failed to grant product:", receiptInfo.ProductId, result)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if result and result == true then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
      warn(`Failed to grant product: ${receiptInfo.ProductId}, result: ${tostring(result)}`)
   end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE
-------------------------------------------------------------------------------

function ProductService.init()
   MarketplaceService.ProcessReceipt = processReceipt

   for _, logicModule in ipairs(ProductLogics:GetChildren()) do
      if logicModule.Name == "ProductLogicsUtil" then
         continue
      end
      local logic = require(logicModule)
      print("~~~~~")
      print("~~~~~")
      print("~~~~~")
      print("~~~~~")
      print(logicModule.Name)
      print(logic.ProductId)
      if not logic.NotActive and logic.ProductId then
         RegisteredProductLogics[logic.ProductId] = logic
      else
         warn(`Logic module ${logicModule.Name} does not have a productId`)
      end
   end
end

return ProductService