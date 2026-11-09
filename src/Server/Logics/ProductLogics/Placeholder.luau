local ServerMods = game.ServerStorage.Server
local SharedMods = game.ReplicatedStorage.Shared

local MarketplaceLibrary = require(SharedMods.Library.MarketplaceLibrary)
local ProductLogicsUtil = require(script.Parent.ProductLogicsUtil)

local PlaceholderProduct = {}
PlaceholderProduct.ProductId = MarketplaceLibrary.getItemId("Placeholder")
PlaceholderProduct.NotActive = true -- // Not registered as a product logic handler

function PlaceholderProduct.grant(Player: Player): boolean
   return ProductLogicsUtil.grantGenericItemToPlayer(Player, "ExampleItem1")
end

return PlaceholderProduct