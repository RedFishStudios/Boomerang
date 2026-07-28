type SoundProperties = {
   Volume: number?,
   Pitch: number?,
   Speed: number?,
   NoDuplicates: boolean?, -- true = cannot play multiple times at once
   Throttle: number?, -- minimum seconds between plays
   Looping: boolean?, -- true = sound will loop

   DoNotPreload: boolean?, -- true = sound will not be preloaded. Only use for sounds that play very infrequently for the purpose of saving user memory space. This indicates that the sound is not 'remembered' by the client and is re-loaded every time it is played.
   -- etc
}

type SoundData = {
   Id: number,
} & SoundProperties

local sounds: {
   [string]: SoundData
} = {
   Kill = {
      Name = "Kill",
      Id = 135176783308337,
   },
   Stab = {
      Name = "Stab",
      Id = 135595810064855
   }
}

return sounds