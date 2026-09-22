export type ItemReward = {
   Type: "Item",
   Value: string
}

export type CurrencyReward = {
   Type: "Currency",
   Value: number
}

export type DailyReward = ItemReward | CurrencyReward

return {
   MaxStreakDays = 7,
   Rewards = {
      [1] = {
         Type = "Item",
         Value = "ExampleItem1"
      },
      [2] = {
         Type = "Currency",
         Value = 100
      },
      [3] = {
         Type = "Item",
         Value = "ExampleItem2"
      },
      [4] = {
         Type = "Currency",
         Value = 200
      },
      [5] = {
         Type = "Item",
         Value = "ExampleWeapon1"
      },
      [6] = {
         Type = "Currency",
         Value = 300
      },
      [7] = {
         Type = "Item",
         Value = "ExampleWeapon2"
      },
   }
}