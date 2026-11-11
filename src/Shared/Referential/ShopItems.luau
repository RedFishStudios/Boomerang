local Items = require(script.Parent.Items)
local Skins = require(script.Parent.Skins)
local ChargeUpEffects = require(script.Parent.ChargeUpEffects)
local Emotes = require(script.Parent.Emotes)
local ElimEffects = require(script.Parent.ElimEffects)
local Taunts = require(script.Parent.Taunts)

-- // A shop listing points at an item (Shared/Referential/Items), a skin (Shared/Referential/Skins), a charge up effect
-- // (Shared/Referential/ChargeUpEffects), an emote (Shared/Referential/Emotes), an elimination effect
-- // (Shared/Referential/ElimEffects) or a taunt (Shared/Referential/Taunts)
export type ShopListing = {
   Type: "Item" | "Skin" | "ChargeUpEffect" | "Emote" | "ElimEffect" | "Taunt" | "Crate", -- // Crate: Shared/Referential/Crates
   Id: Items.ItemClassId | Skins.SkinId | ChargeUpEffects.ChargeUpEffectId | Emotes.EmoteId | ElimEffects.ElimEffectId | Taunts.TauntId
}

-- // The shops and their tabs are defined by the Gui modules WeaponsShop and CosmeticsShop (Client/UI/Gui),
-- // built by Client/UI/ShopCommon/ShopBuilder.
local ShopItems: {
   CurrentDeal: Items.ItemClassId?
} = {
   CurrentDeal = nil
}

return ShopItems
