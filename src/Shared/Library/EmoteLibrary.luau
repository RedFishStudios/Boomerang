--[[
	EmoteLibrary

	Description:
	Shared helpers for emotes (Shared/Referential/Emotes). Works out any player's equipped emote from the "WinningEmote"
	Player attribute that EmoteService sets (see CosmeticLibrary), which holds the emote's animation asset id.
	Safe to use on both server and client.
]]

local EmoteLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Emotes = require(ReplicatedStorage.Shared.Referential.Emotes)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local defaultEmoteId: string = "DefaultEmote"
local emoteIdByAnimationId: { [string]: string } = {}
for emoteId, emote in Emotes do
	emoteIdByAnimationId[emote.AnimationId] = emoteId
	if emote.Default then
		defaultEmoteId = emoteId
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EmoteLibrary.getEmote(emoteId: string?): Emotes.Emote?
	return if emoteId then Emotes[emoteId] else nil
end

function EmoteLibrary.getDefaultId(): string
	return defaultEmoteId
end

-- // Emote ids sorted by their Order
function EmoteLibrary.getSortedIds(): { string }
	local emoteIds = {}
	for emoteId in Emotes do
		table.insert(emoteIds, emoteId)
	end
	table.sort(emoteIds, function(a, b)
		return Emotes[a].Order < Emotes[b].Order
	end)
	return emoteIds
end

-- // Whether this saved data owns the emote (the default emote is always owned)
function EmoteLibrary.dataOwns(data: { OwnedEmotes: { [string]: boolean } }?, emoteId: string): boolean
	local emote = Emotes[emoteId]
	if not emote then
		return false
	end
	if emote.Default then
		return true
	end
	return data ~= nil and data.OwnedEmotes ~= nil and data.OwnedEmotes[emoteId] == true
end

-- // The player's equipped emote id; the default while it isn't set yet or isn't a real emote
function EmoteLibrary.getEquippedId(player: Player): string
	local animationId = CosmeticLibrary.getEquippedRaw(player, "WinningEmote")
	return (animationId and emoteIdByAnimationId[animationId]) or defaultEmoteId
end

return EmoteLibrary
