--[[
	WinningEmoteLibrary

	Description:
	The "WinningEmote" cosmetic: the animation a player's avatar performs on the winner pedestal (PedestalController).
	The player's equipped value is the Roblox asset id of an animation, stored as a string in the Player attribute
	CosmeticLibrary.ATTRIBUTES.WinningEmote ("EquippedWinningEmote").
	EmoteService sets that attribute from the player's equipped emote (Shared/Referential/Emotes); until it has, or if the
	value isn't a valid asset id, a player gets DEFAULT_ANIMATION_ID.

	On the client, this Library registers the category's resolver with PlayerCosmeticController, so
	`PlayerCosmeticController.get(player, "WinningEmote")` always returns a usable animation asset id string.
]]

local WinningEmoteLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EmoteLibrary = require(ReplicatedStorage.Shared.Library.EmoteLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Animation asset id used when a player has no (valid) winning emote equipped: the default emote's (Shared/Referential/Emotes)
local defaultEmote = EmoteLibrary.getEmote(EmoteLibrary.getDefaultId())
WinningEmoteLibrary.DEFAULT_ANIMATION_ID = if defaultEmote then defaultEmote.AnimationId else "122884053950359"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- The usable animation asset id for a raw equipped value: the value itself when it is a valid asset id (digits only),
--- otherwise DEFAULT_ANIMATION_ID.
function WinningEmoteLibrary.getAnimationId(rawId: string?): string
	if type(rawId) == "string" and rawId:match("^%d+$") then
		return rawId
	end
	return WinningEmoteLibrary.DEFAULT_ANIMATION_ID
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function WinningEmoteLibrary.init()
	if RunService:IsClient() then
		local PlayerCosmeticController = require(ReplicatedStorage.Client.Core.PlayerCosmeticController)
		PlayerCosmeticController.registerResolver("WinningEmote", WinningEmoteLibrary.getAnimationId)
	end
end

function WinningEmoteLibrary.start() end

return WinningEmoteLibrary
