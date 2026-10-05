local Items = require(script.Parent.Items)
local Skins = require(script.Parent.Skins)

-- // A shop listing points at an item (Shared/Referential/Items) or a skin (Shared/Referential/Skins)
export type ShopListing = {
   Type: "Item" | "Skin",
   Id: Items.ItemClassId | Skins.SkinId
}

export type ShopTab = {
   Name: string,
   Order: number,
   AutoSelect: boolean?, -- Whether this tab is the first that is selected when the gui is opened
   Listings: { ShopListing }
}

local ShopItems: {
   Tabs: {
      [string]: ShopTab
   },
   CurrentDeal: Items.ItemClassId?
} = {
   Tabs = {
      Skins = {
         Order = 1,
         AutoSelect = true,
         Name = "Skins",
         Listings = {
            { Type = "Skin", Id = "Shuriken" },
            { Type = "Skin", Id = "Fan" },
         }
      },
   },
   CurrentDeal = nil
}

return ShopItems
