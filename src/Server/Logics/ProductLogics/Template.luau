local ServerMods = game.ServerStorage.Server
local SharedMods = game.ReplicatedStorage.Shared

local MarketplaceLibrary = require(SharedMods.Library.MarketplaceLibrary)

local ProductLogicTemplate = {}
ProductLogicTemplate.ProductId = MarketplaceLibrary.getItemId("Placeholder")
ProductLogicTemplate.NotActive = true

function ProductLogicTemplate.grant(Player: Player): boolean
   warn(`placeholder product purchased by {Player.Name}`)
   return true
end

return ProductLogicTemplate