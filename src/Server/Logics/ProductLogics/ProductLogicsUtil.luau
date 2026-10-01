local ProductLogicsUtil = {}
ProductLogicsUtil.NotActive = true -- Prevent from registration as a product logic handler

local ServerStorage = game:GetService("ServerStorage")

local ItemService = require(ServerStorage.Server.Core.ItemService)

-- // ItemService's Inventory write replicates to the client through the data proxy;
-- // ShopController listens for Inventory increases and shows the ItemAcquired gui, so no extra remote is needed
function ProductLogicsUtil.grantGenericItemToPlayer(player: Player, itemId: string): boolean
   return ItemService.grantItem(player, itemId, 1)
end

return ProductLogicsUtil