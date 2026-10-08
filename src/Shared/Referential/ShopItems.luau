local Items = require(script.Parent.Items)
local Skins = require(script.Parent.Skins)

-- // A shop listing points at an item (Shared/Referential/Items) or a skin (Shared/Referential/Skins)
export type ShopListing = {
   Type: "Item" | "Skin",
   Id: Items.ItemClassId | Skins.SkinId
}

-- // Tabs are listed here in display order; a tab's content comes from the module with the same name in
-- // Client/UI/Gui/Shop/Tabs (a tab without a module opens blank: placeholder until the feature exists).
export type ShopTab = {
   Name: string,
   Order: number,
   Icon: string, -- // Emoji placeholder shown beside the name; replace with an image when icon art exists
   AutoSelect: boolean?, -- Whether this tab is the one selected when the gui is opened
   Listings: { ShopListing }? -- // Hand-picked listings (Featured). Tabs that build their listings from another system leave this out.
}

local ShopItems: {
   Tabs: {
      [string]: ShopTab
   },
   CurrentDeal: Items.ItemClassId?
} = {
   Tabs = {
      -- // Hand-picked, shown without scrolling: the Featured tab shows at most 6 listings (3x2)
      Featured = {
         Order = 1,
         AutoSelect = true,
         Name = "Featured",
         Icon = "⭐", -- // PLACEHOLDER emoji, replace with an image later
         Listings = {
            { Type = "Skin", Id = "Shuriken" },
            { Type = "Skin", Id = "Fan" },
         }
      },
      -- // Every skin on sale (Shared/Referential/Skins, same system as the Inventory's Skins tab)
      Skins = {
         Order = 2,
         Name = "Skins",
         Icon = "🎨", -- // PLACEHOLDER emoji, replace with an image later (the boomerang emoji isn't in Roblox's font)
      },
      -- // TODO: not set up yet: these tabs open blank until a module with the same name is added to Shop/Tabs
      Emotes = {
         Order = 3,
         Name = "Emotes",
         Icon = "🎵", -- // PLACEHOLDER emoji, replace with an image later
      },
      Arrows = {
         Order = 4,
         Name = "Arrows",
         Icon = "⬆️", -- // PLACEHOLDER emoji, replace with an image later
      },
      Effects = {
         Order = 5,
         Name = "Effects",
         Icon = "✨", -- // PLACEHOLDER emoji, replace with an image later
      },
   },
   CurrentDeal = nil
}

return ShopItems
