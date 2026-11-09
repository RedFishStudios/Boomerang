local MarketplaceItems = require(script.Parent.MarketplaceItems)

export type ItemClassId = string

export type ItemType = "Skin" | "Weapon"

export type ItemClass = {
   Name: string,
   Price: number,
   OffSale: boolean?,
   ProductId: number?,
   IsPaidRandomItem: true?,
   Type: ItemType,
   Model: string?, -- // Model in Shared/Assets/Tools shown in GUI viewports (Shop, Daily Rewards)
}

-- // No items yet; boomerang skins are in Shared/Referential/Skins
return {
} :: {
   [ItemClassId]: ItemClass
}