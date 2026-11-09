--[[
	Emotes tab (Cosmetics Shop)

	Description:
	Every emote on sale, in the Inventory Emotes tab's order (EmoteLibrary / EmoteController, data in
	Shared/Referential/Emotes). ShopListings omits off-sale emotes. Scrolls past 6 listings.
	Follows the ShopTab shape in ShopCommon/ShopBuilder.
]]

local EmotesTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local EmoteLibrary = require(ReplicatedStorage.Shared.Library.EmoteLibrary)
local EmoteController = require(ReplicatedStorage.Client.Core.EmoteController)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EmotesTab.Scrollable = true

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EmotesTab.getListings(): { ShopItems.ShopListing }
	local listings = {}
	for _, emoteId in EmoteLibrary.getSortedIds() do
		table.insert(listings, { Type = "Emote", Id = emoteId })
	end
	return listings
end

function EmotesTab.subscribe(onChanged: () -> ())
	EmoteController.EmoteGrantedTasks:Add(onChanged)
end

return EmotesTab
