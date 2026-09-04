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
	local profile = {}

   profile.Elims = 0
   profile.Wins = 0
   profile.Losses = 0

	return profile
end

return ProfileTemplate
