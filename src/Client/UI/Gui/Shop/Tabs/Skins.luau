--[[
	Skins tab (Shop)

	Description:
	Every boomerang skin on sale, in the same order as the Inventory's Skins tab (SkinLibrary / SkinController, data in
	Shared/Referential/Skins). Skins that are off sale are left out by ShopListings. Scrolls past 6 listings.
	Follows the ShopTab shape in Shop/init.luau.
]]

local SkinsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local SkinController = require(ReplicatedStorage.Client.Core.SkinController)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SkinsTab.Scrollable = true

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SkinsTab.getListings(): { ShopItems.ShopListing }
	local listings = {}
	for _, skinId in SkinLibrary.getSortedSkinIds() do
		table.insert(listings, { Type = "Skin", Id = skinId })
	end
	return listings
end

function SkinsTab.subscribe(onChanged: () -> ())
	SkinController.SkinGrantedTasks:Add(onChanged)
end

return SkinsTab
