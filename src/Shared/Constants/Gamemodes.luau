-- // Defines the types of rounds and their functionality
-- DOCU: https://docs.google.com/document/d/15GWFwrjrhytRjPqBhBg-Zhc5YLX9CeWJlt8Q_rMttss/edit?tab=t.d4ujxm3y7eay

export type RoundType = {
   Id: string,
   Display: string?, -- if different from id
   Subheader: string, -- for client display
   CanRespawn: boolean,
   TimeLasts: number
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

local Gamemodes: {
   [string]: RoundType
} = {
   Classic = {
      Id = "Classic",
      Subheader = "Have the highest score when the timer runs out!",
      CanRespawn = true,
      TimeLasts = 2
   },
   Elimination = {
      Id = "Elimination",
      Subheader = "Eliminate all opponents to win!",
      CanRespawn = false,
      TimeLasts = 3
   },
   ThrowBoomerang = {
      Id = "ThrowBoomerang",
      Subheader = "Throw the boomerang 12 times (test)",
      CanRespawn = true,
      TimeLasts = 2
   },
}

return Gamemodes