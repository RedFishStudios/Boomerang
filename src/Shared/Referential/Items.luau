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

-- // No items yet: boomerang skins live in Shared/Referential/Skins (the Example placeholders were removed for skins)
return {
} :: {
   [ItemClassId]: ItemClass
}