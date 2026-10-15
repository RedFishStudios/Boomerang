--[[
	WinningEmoteLibrary

	Description:
	The "WinningEmote" cosmetic: the animation a player's avatar performs on the winner pedestal (PedestalController).
	The player's equipped value is the Roblox asset id of an animation, stored as a string in the Player attribute
	CosmeticLibrary.ATTRIBUTES.WinningEmote ("EquippedWinningEmote").
	Players can't choose one yet, so nobody sets that attribute and everyone gets DEFAULT_ANIMATION_ID. Once players can
	equip emotes, the server writes the id with `CosmeticLibrary.setEquipped(player, "WinningEmote", assetId)`.

	On the client, this Library registers the category's resolver with PlayerCosmeticController, so
	`PlayerCosmeticController.get(player, "WinningEmote")` always returns a usable animation asset id string.
]]

local WinningEmoteLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Animation asset id used when a player has no (valid) winning emote equipped
WinningEmoteLibrary.DEFAULT_ANIMATION_ID = "122884053950359"

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
