--[[
	Emotes tab (Inventory)

	Description:
	The Emotes tab of the Inventory menu: lists the emotes the player owns (Shared/Referential/Emotes), the default
	emote included. Equip equips the selected emote. Each emote is previewed on the EmotesRig playing its animation
	(ItemViewport.renderEmote). Follows the InventoryTab shape in Inventory/init.luau.
]]

local EmotesTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteLibrary = require(ReplicatedStorage.Shared.Library.EmoteLibrary)
local EmoteController = require(ReplicatedStorage.Client.Core.EmoteController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_RARITY = "Common" -- // When the emote has no Rarity

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EmotesTab.Title = "Your Emotes"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EmotesTab.getItems()
	local equippedId = EmoteController.getEquippedId()
	local items = {}

	for _, emoteId in EmoteLibrary.getSortedIds() do
		local emote = EmoteLibrary.getEmote(emoteId)
		if emote and EmoteController.ownsEmote(emoteId) then
			table.insert(items, {
				Id = emoteId,
				Name = emote.Name,
				Rarity = emote.Rarity or DEFAULT_RARITY,
				EmoteAnimationId = emote.AnimationId,
				Owned = true,
				Equipped = emoteId == equippedId,
			})
		end
	end

	return items
end

-- // Yields until the server answers
function EmotesTab.equipItem(emoteId: string)
	if EmoteController.ownsEmote(emoteId) and EmoteController.getEquippedId() ~= emoteId then
		EmoteController.requestEquip(emoteId)
	end
end

function EmotesTab.subscribe(onChanged: () -> ())
	EmoteController.EmoteGrantedTasks:Add(onChanged)
	EmoteController.EmoteEquippedTasks:Add(onChanged)
end

return EmotesTab
