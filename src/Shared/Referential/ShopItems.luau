local Items = require(script.Parent.Items)

export type ShopTab = {
   Name: string,
   Order: number,
   AutoSelect: boolean?, -- Whether this tab is the first that is selected when the gui is opened
   Items: { Items.ItemClassId }
}

local ShopItems: {
   Tabs: {
      [string]: ShopTab
   },
   CurrentDeal: Items.ItemClassId?
} = {
   Tabs = {
      ExampleTab1 = {
         Order = 1,
         AutoSelect = true,
         Name = "Example Tab 1",
         Items = {
            "ExampleItem1",
            "ExampleItem2"
         }
      },
      ExampleTab2 = {
         Order = 2,
         AutoSelect = nil,
         Name = "Example Tab 2",
         Items = {
            "ExampleWeapon1",
            "ExampleWeapon2",
            "ExampleWeapon3"
         }
      }
   },
   CurrentDeal = "ExampleItem1"
}

return ShopItems