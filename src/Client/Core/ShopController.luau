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

local acquiredTitleByType: {[Items.ItemType]: string} = {
   Weapon = "New weapon acquired!",
   Skin = "New skin acquired!",
}

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
   local success = requestPurchaseRemoteFunction:InvokeServer(itemId)
   if success then
      local itemData = Items[itemId]
      local title = acquiredTitleByType[itemData.Type] or "New item acquired!"
      ItemAcquiredGui.acquiredCustomItem(nil, title, itemData.Name)
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