type SoundProperties = {
   Volume: number?,
   Pitch: number?,
   Speed: number?,
   NoDuplicates: boolean?, -- true = cannot play multiple times at once
   Throttle: number?, -- minimum seconds between plays
   Looping: boolean?, -- true = sound will loop
   -- etc
}

type SoundData = {
   Id: number,
} & SoundProperties

local sounds: {
   [string]: SoundData
} = {
   Stab = {
      Name = "Stab",
      Id = 135176783308337,
   }
}

return sounds