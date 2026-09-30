export type ProductLogic = {
   Id: number,
   Grant: (Player: Player)->(boolean)
}

local ServerMods = game.ServerStorage.Server
local SharedMods = game.ReplicatedStorage.Shared

local MarketplaceLibrary = require(SharedMods.Library.MarketplaceLibrary)

local ProductLogicTemplate = {}
ProductLogicTemplate.Id = MarketplaceLibrary.getItemId("Placeholder")

function ProductLogicTemplate.Grant(Player: Player): boolean
   warn(`placeholder product purchased by ${Player.Name}`)
   return true
end

return ProductLogicTemplate :: ProductLogic