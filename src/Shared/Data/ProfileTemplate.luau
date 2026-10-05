local ProfileTemplate = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CRC32C = require(ReplicatedStorage.Shared.Hashing.CRC32C)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Template = {
   -- // Lifetime stats: written only by LifetimeStatsService
   Elims: number, -- Lifetime eliminations of other players
   Defeats: number, -- Times eliminated by another player
   Wins: number, -- Rounds won (team wins count for every member; ties don't count)
   Losses: number, -- Unused: never tracked, kept because the field has shipped
   RoundsPlayed: number, -- Rounds the player was in from start to finish
   TimePlayed: number, -- Seconds spent in the game
   Throws: number, -- Times the player threw a weapon
   AbilityUses: {
      [string]: number -- Ability id : times used
   },
   PickupsAcquired: {
      [string]: number -- Pickup class id : times picked up
   },
   MonthlyStats: { -- // This month's Elims/Wins for the monthly leaderboards; reset when MonthKey changes
      MonthKey: string, -- UTC month, e.g. "2026-10" ("" = never set)
      Elims: number,
      Wins: number,
   },
   Currency: number,
   DailyRewards: {
      Streak: number, -- Current daily reward streak
      LastClaim: number, -- Timestamp of the last claimed daily reward
   },
   GroupRewardLastClaim: number, -- Timestamp of the last Group Rewards chest claim (T-045), 0 = never
   Inventory: {
      [string]: number -- Shop item id : amount owned
   },
   OwnedSkins: {
      [string]: boolean -- Skin id (Shared/Referential/Skins) : true. Default skins are owned without an entry
   },
   EquippedSkin: string, -- Skin id the player holds and throws
   GiftedPasses: {
      number -- Gamepass id
   }
}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ProfileTemplate.get()
	local baseProfile = {
      Elims = 0,
      Defeats = 0,
      Wins = 0,
      Losses = 0,
      RoundsPlayed = 0,
      TimePlayed = 0,
      Throws = 0,
      AbilityUses = {},
      PickupsAcquired = {},
      MonthlyStats = {
         MonthKey = "",
         Elims = 0,
         Wins = 0,
      },
      Currency = 0,
      DailyRewards = {
         Streak = 0,
         LastClaim = 0
      },
      GroupRewardLastClaim = 0,
      Inventory = {},
      OwnedSkins = {},
      EquippedSkin = "ClassicBoomerang",
      GiftedPasses = {},
   }

	return baseProfile
end

return ProfileTemplate
