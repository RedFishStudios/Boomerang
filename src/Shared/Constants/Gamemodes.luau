-- // Defines the types of rounds and their functionality
-- DOCU: https://docs.google.com/document/d/15GWFwrjrhytRjPqBhBg-Zhc5YLX9CeWJlt8Q_rMttss/edit?tab=t.d4ujxm3y7eay

export type RoundType = {
   Id: string,
   Display: string?, -- if different from id
   Subheader: string, -- for client display
   CanRespawn: boolean,
   LateJoinEnabled: boolean, -- only meaningful when CanRespawn is true
   TimeLasts: number,
   StormClose: boolean?,
   DashDisabled: boolean?,
   PickupsDisabled: boolean?
}

local ROUND_LENGTH = 10 -- // Seconds every round lasts (RoundCyclingService adds TimeLasts to server time in seconds)

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
      LateJoinEnabled = true,
      StormClose = false,
      TimeLasts = ROUND_LENGTH
   },
   TeamClassic = {
      Id = "TeamClassic",
      Display = "Team\nClassic",
      Subheader = "Have the highest team score when the timer runs out!",
      CanRespawn = true,
      LateJoinEnabled = true,
      StormClose = false,
      TimeLasts = ROUND_LENGTH
   },
   Elimination = {
      Id = "Elimination",
      Subheader = "Eliminate all opponents to win!",
      CanRespawn = false,
      LateJoinEnabled = false,
      StormClose = true,
      TimeLasts = ROUND_LENGTH
   },
   TeamElimination = {
      Id = "TeamElimination",
      Display = "Team\nElimination",
      Subheader = "Eliminate all opponents to win!",
      CanRespawn = false,
      LateJoinEnabled = false,
      StormClose = false,
      TimeLasts = ROUND_LENGTH
   },
   HotPotato = {
      Id = "HotPotato",
      Display = "Hot\nPotato",
      Subheader = "Throw your boomerang to pass the bomb!",
      CanRespawn = false,
      LateJoinEnabled = false,
      StormClose = false,
      PickupsDisabled = true,
      TimeLasts = ROUND_LENGTH
   },
   Assassin = {
      Id = "Assassin",
      Subheader = "Eliminate your target! Attacking anyone else is fatal.",
      CanRespawn = true,
      LateJoinEnabled = true,
      StormClose = false,
      PickupsDisabled = true,
      TimeLasts = ROUND_LENGTH
   },
   --[[ThrowBoomerang = {
      Id = "ThrowBoomerang",
      Display = "Throw Boomerang",
      Subheader = "Throw the boomerang 5 times (test)",
      CanRespawn = true,
      TimeLasts = ROUND_LENGTH,
      --DashDisabled = true
   },]]
}

return Gamemodes