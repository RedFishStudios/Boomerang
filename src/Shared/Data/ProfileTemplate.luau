local ProfileTemplate = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CRC32C = require(ReplicatedStorage.Shared.Hashing.CRC32C)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Template = {
   Elims: number, -- Lifetime elimination stat
   Wins: number, -- Lifetime wins stat
   Losses: number, -- Lifetime losses stat
   Currency: number,
   DailyRewards: {
      Streak: number, -- Current daily reward streak
      LastClaim: number, -- Timestamp of the last claimed daily reward
   },
   Inventory: {
      [string]: number -- Shop item id : amount owned
   },
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
      Wins = 0,
      Losses = 0,
      Currency = 0,
      DailyRewards = {
         Streak = 0,
         LastClaim = 0
      },
      Inventory = {},
      GiftedPasses = {},
   }

	return baseProfile
end

return ProfileTemplate
