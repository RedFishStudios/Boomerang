--[[
	Emotes tab (Shop)

	Description:
	Every emote on sale, in the same order as the Inventory's Emotes tab (EmoteLibrary / EmoteController, data in
	Shared/Referential/Emotes). Emotes that are off sale are left out by ShopListings. Scrolls past 6 listings.
	Follows the ShopTab shape in Shop/init.luau.
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
