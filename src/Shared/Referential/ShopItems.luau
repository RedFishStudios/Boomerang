local Items = require(script.Parent.Items)
local Skins = require(script.Parent.Skins)
local ChargeUpEffects = require(script.Parent.ChargeUpEffects)
local Emotes = require(script.Parent.Emotes)

-- // A shop listing points at an item (Shared/Referential/Items), a skin (Shared/Referential/Skins), a charge up effect
-- // (Shared/Referential/ChargeUpEffects) or an emote (Shared/Referential/Emotes)
export type ShopListing = {
   Type: "Item" | "Skin" | "ChargeUpEffect" | "Emote" | "Crate", -- // Crate: Shared/Referential/Crates (T-112)
   Id: Items.ItemClassId | Skins.SkinId | ChargeUpEffects.ChargeUpEffectId | Emotes.EmoteId
}

-- // The shops and their tabs are defined by the Gui modules WeaponsShop and CosmeticsShop (Client/UI/Gui),
-- // built by Client/UI/ShopCommon/ShopBuilder.
local ShopItems: {
   CurrentDeal: Items.ItemClassId?
} = {
   CurrentDeal = nil
}

return ShopItems
