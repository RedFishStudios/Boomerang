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
      FadeIn = .2,
      FadeOut = .2,
      Looping = true
   }
}

return Animations