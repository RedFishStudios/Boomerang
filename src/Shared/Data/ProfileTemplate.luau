local ProfileTemplate = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CRC32C = require(ReplicatedStorage.Shared.Hashing.CRC32C)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Template = typeof(ProfileTemplate.get())

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ProfileTemplate.get()
	local baseProfile = {
      Elims = 0,
      Wins = 0,
      Losses = 0,
      DailyRewards = {
         Streak = 0,
         LastClaim = 0
      }
   }

	return baseProfile
end

return ProfileTemplate
