local ProductLogicsUtil = {}
ProductLogicsUtil.NotActive = true -- Prevent from registration as a product logic handler

local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-- // The data proxy replicates this Inventory write to the client automatically;
-- // ShopController listens for Inventory increases and shows the ItemAcquired gui, so no extra remote is needed
function ProductLogicsUtil.grantGenericItemToPlayer(player: Player, itemId: string): boolean
   local profileData = PlayerDataService.get(player)
   if not profileData then
      return false
   end

   profileData.Inventory[itemId] = (profileData.Inventory[itemId] or 0) + 1
   return true
end

return ProductLogicsUtil