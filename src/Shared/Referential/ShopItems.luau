local Items = require(script.Parent.Items)
local Skins = require(script.Parent.Skins)
local ChargeUpEffects = require(script.Parent.ChargeUpEffects)
local Emotes = require(script.Parent.Emotes)
local ElimEffects = require(script.Parent.ElimEffects)

-- // A shop listing points at an item (Shared/Referential/Items), a skin (Shared/Referential/Skins), a charge up effect
-- // (Shared/Referential/ChargeUpEffects), an emote (Shared/Referential/Emotes) or an elimination effect
-- // (Shared/Referential/ElimEffects)
export type ShopListing = {
   Type: "Item" | "Skin" | "ChargeUpEffect" | "Emote" | "ElimEffect" | "Crate", -- // Crate: Shared/Referential/Crates
   Id: Items.ItemClassId | Skins.SkinId | ChargeUpEffects.ChargeUpEffectId | Emotes.EmoteId | ElimEffects.ElimEffectId
}

-- // The shops and their tabs are defined by the Gui modules WeaponsShop and CosmeticsShop (Client/UI/Gui),
-- // built by Client/UI/ShopCommon/ShopBuilder.
local ShopItems: {
   CurrentDeal: Items.ItemClassId?
} = {
   CurrentDeal = nil
}

return ShopItems
