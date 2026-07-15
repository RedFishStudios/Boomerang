-- // Defines the types of rounds and their functionality
-- DOCU: https://docs.google.com/document/d/15GWFwrjrhytRjPqBhBg-Zhc5YLX9CeWJlt8Q_rMttss/edit?tab=t.d4ujxm3y7eay

export type RoundType = {
   Id: string,
   Display: string?, -- if different from id
   Subheader: string, -- for client display
   CanRespawn: boolean,
   TimeLasts: number,
   DashDisabled: boolean?
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
      TimeLasts = 60
   },
   Elimination = {
      Id = "Elimination",
      Subheader = "Eliminate all opponents to win!",
      CanRespawn = false,
      TimeLasts = 60
   },
   ThrowBoomerang = {
      Id = "ThrowBoomerang",
      Display = "Throw Boomerang",
      Subheader = "Throw the boomerang 5 times (test)",
      CanRespawn = true,
      TimeLasts = 60,
      DashDisabled = true
   },
}

return Gamemodes