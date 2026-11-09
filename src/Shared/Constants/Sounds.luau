type SoundProperties = {
   Volume: number?,
   Pitch: number?,
   Speed: number?,
   NoDuplicates: boolean?, -- true = cannot play multiple times at once
   Throttle: number?, -- minimum seconds between plays
   Looping: boolean?, -- true = sound will loop
   IsMusic: boolean?, -- true = music: plays through the Music sound group (Music setting) instead of Sound Effects

   DoNotPreload: boolean?, -- true = not preloaded; re-loaded on every play. Only for rarely played sounds (saves client memory).
}

type SoundData = {
   Name: string,
   Id: number,
} & SoundProperties

local sounds: {
   Data: {
      [string]: SoundData
   },
   Defaults: {
      Looping: boolean,
      Volume: number,
      RollOffMode: Enum.RollOffMode,
      RollOffMinDistance: number,
      RollOffMaxDistance: number
   }
} = {
   Data = {
      Kill = {
         Name = "Kill",
         Id = 135176783308337,
      },
      Stab = {
         Name = "Stab",
         Id = 135595810064855
      },
      Throw = {
         Name = "Throw",
         Id = 87839434436077,
         Volume = .5
      },
      BoomerangLoop = {
         Name = "BoomerangLoop",
         Id = 6957736499,
         Looping = true,
         Volume = .5
      },
      BoomerangClunk = { -- // A dead boomerang hitting the ground (Dead.luau)
         Name = "BoomerangClunk",
         Id = 0, -- TODO:RELEASE placeholder (set the real sound id, then remove DoNotPreload)
         DoNotPreload = true,
      },
      BoomerangThud = {
         Name = "BoomerangThud",
         Id = 9120916632
      },
      BoomerangCatch = {
         Name = "BoomerangCatch",
         Id = 4458219865
      },
      BoomerangClash = {
         Name = "BoomerangClash",
         Id = 9117451558
      },
      PickupGeneric = {
         Name = "PickupGeneric",
         Id = 123582256549202
      },
      Explosion = {
         Name = "Explosion",
         Id = 117211977307268
      },
      Zapped = {
         Name = "Zapped",
         Id = 130444530731279
      },
   },
   Defaults = {
      Looping = false,
      Volume = 1,
      RollOffMode = Enum.RollOffMode.Linear,
      RollOffMinDistance = 1,
      RollOffMaxDistance = 200
   }
}

return sounds