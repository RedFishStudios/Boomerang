local Animations: {
   [string]: {
      Id: number,
      Layer: string,
      FadeIn: number?,
      FadeOut: number?,
      Looping: boolean,
      Priority: Enum.AnimationPriority?,
   }
} = {
   Test = {
      Id = 137190745181140,
      Layer = "Test",
      Looping = true
   },

   Charging = {
      Id = 130007850779400,
      Layer = "WeaponAction",
      FadeIn = .8,
      FadeOut = .8,
      Looping = true
   },

   Throw = {
      Id = 83626657502858,
      Layer = "WeaponAction",
      FadeIn = .2,
      FadeOut = .8,
      Looping = false
   },

   Catch = {
      Id = 111625966555407,
      Layer = "WeaponAction",
      FadeIn = .2,
      FadeOut = .2,
      Looping = false,
      Priority = Enum.AnimationPriority.Action,
   },

   Stab = {
      Id = 137065689006321,
      Layer = "WeaponAction",
      FadeIn = .1,
      FadeOut = .2,
      Looping = false
   },

   Dash = {
      Id = 126005747148454,
      Layer = "Ability",
      FadeIn = .05,
      FadeOut = .1,
      Looping = false
   },

   Zapped = {
      Id = 111468555566905,
      Layer = "Ability",
      FadeIn = .05,
      FadeOut = .05,
      Looping = true,
      Priority = Enum.AnimationPriority.Action4,
   }
}

return Animations