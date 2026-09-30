local ShopController = {}

local StarterGuiService = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Referential.Items)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local requestPurchaseRemoteFunction = SimpleRemotes.getFunction("RequestPurchase")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ShopController.requestPurchaseItem(itemId: string): boolean
   warn(`sending 1`)
   local success = requestPurchaseRemoteFunction:InvokeServer(itemId)
   warn(`received response: ${tostring(success)}`)
   if success then
      local itemData = Items[itemId]
      ItemAcquiredGui.acquiredCustomItem(nil, itemData.Name, "Purchased!")
   end
   return success
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ShopController.init()
end

function ShopController.start() end

return ShopController