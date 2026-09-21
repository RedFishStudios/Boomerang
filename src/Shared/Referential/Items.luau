export type ItemClassId = string

export type ItemType = "Skin" | "Weapon"

export type ItemClass = {
   Name: string,
   Price: number,
   OffSale: boolean?,
   Type: ItemType
}

return {
   ExampleItem1 = {
      Name = "Example Item",
      Price = 10,
      OffSale = nil,
      Type = "Skin"
   },
   ExampleItem2 = {
      Name = "Example Item",
      Price = 10,
      OffSale = nil,
      Type = "Skin"
   },
   ExampleWeapon1 = {
      Name = "Example Weapon",
      Price = 20,
      OffSale = nil,
      Type = "Weapon"
   },
   ExampleWeapon2 = {
      Name = "Example Weapon",
      Price = 20,
      OffSale = nil,
      Type = "Weapon"
   },
   ExampleWeapon3 = {
      Name = "Example Weapon",
      Price = 20,
      OffSale = nil,
      Type = "Weapon"
   }
} :: {
   [ItemClassId]: ItemClass
}