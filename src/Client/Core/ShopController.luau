local ShopController = {}

local StarterGuiService = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Referential.Items)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local MarketplaceLibrary = require(ReplicatedStorage.Shared.Library.MarketplaceLibrary)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local requestPurchaseRemoteFunction = SimpleRemotes.getFunction("RequestPurchase")

local acquiredTitleByType: {[Items.ItemType]: string} = {
   Weapon = "New weapon acquired!",
   Skin = "New skin acquired!",
}

-- // Last known inventory counts, since UpdatedTasks only provides the new value
local knownInventoryCounts: {[string]: number} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function showItemAcquired(itemId: string)
   local itemData = Items[itemId]
   if not itemData then
      return
   end
   local title = acquiredTitleByType[itemData.Type] or "New item acquired!"
   ItemAcquiredGui.acquiredCustomItem(nil, title, itemData.Name)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The ItemAcquired gui is shown by the Inventory replication listener in init()
-- // listingType is the ShopItems listing Type ("Item" by default, or "Skin")
function ShopController.requestPurchaseItem(itemId: string, listingType: string?): boolean
   return requestPurchaseRemoteFunction:InvokeServer(itemId, listingType or "Item")
end

function ShopController.requestRobuxPurchaseItem(itemId: string)
   local itemData = Items[itemId]
   if not itemData or not itemData.ProductId then
      return
   end
   MarketplaceLibrary.promptDeveloperProduct(itemData.ProductId)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ShopController.init()
   PlayerDataController.getAsync(function(data)
      for itemId, count in pairs(data.Inventory) do
         knownInventoryCounts[itemId] = count
      end
   end)

   PlayerDataController.UpdatedTasks:Add(function(index, value, path)
      if path[1] ~= "Inventory" or #path ~= 1 or type(index) ~= "string" then
         return
      end
      local previous = knownInventoryCounts[index] or 0
      local current = if type(value) == "number" then value else 0
      knownInventoryCounts[index] = current
      if current > previous then
         showItemAcquired(index)
      end
   end)
end

function ShopController.start() end

return ShopController