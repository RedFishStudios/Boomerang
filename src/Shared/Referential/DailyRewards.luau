export type ItemReward = {
   Type: "Item",
   Value: string
}

export type CurrencyReward = {
   Type: "Currency",
   Value: number
}

-- // A boomerang skin (Shared/Referential/Skins). If the player already owns it, they get FallbackCurrency instead.
export type SkinReward = {
   Type: "Skin",
   Value: string,
   FallbackCurrency: number
}

export type DailyReward = ItemReward | CurrencyReward | SkinReward

return {
   MaxStreakDays = 7,
   Rewards = {
      [1] = {
         Type = "Currency",
         Value = 50 -- TODO:RELEASE placeholder
      },
      [2] = {
         Type = "Currency",
         Value = 100 -- TODO:RELEASE placeholder
      },
      [3] = {
         Type = "Skin",
         Value = "Shuriken",
         FallbackCurrency = 250 -- TODO:RELEASE placeholder
      },
      [4] = {
         Type = "Currency",
         Value = 200 -- TODO:RELEASE placeholder
      },
      [5] = {
         Type = "Currency",
         Value = 250 -- TODO:RELEASE placeholder
      },
      [6] = {
         Type = "Currency",
         Value = 300 -- TODO:RELEASE placeholder
      },
      [7] = {
         Type = "Skin",
         Value = "Fan",
         FallbackCurrency = 500 -- TODO:RELEASE placeholder
      },
   }
}
