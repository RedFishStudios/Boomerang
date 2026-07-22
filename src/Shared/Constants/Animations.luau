local Animations: {
   [string]: {
      Id: number,
      Layer: string,
      FadeIn: number?,
      FadeOut: number?,
      Looping: boolean
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
      Looping = false
   }
}

return Animations