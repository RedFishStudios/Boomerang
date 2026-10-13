--[[
	Arrows tab (Shop)

	Description:
	Every aim arrow on sale, in the same order as the Inventory's Arrows tab (AimArrowLibrary / AimArrowController, data in
	Shared/Referential/AimArrows). Arrows that are off sale are left out by ShopListings. Scrolls past 6 listings.
	Follows the ShopTab shape in Shop/init.luau.
]]

local ArrowsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local AimArrowLibrary = require(ReplicatedStorage.Shared.Library.AimArrowLibrary)
local AimArrowController = require(ReplicatedStorage.Client.Core.AimArrowController)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ArrowsTab.Scrollable = true

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ArrowsTab.getListings(): { ShopItems.ShopListing }
	local listings = {}
	for _, aimArrowId in AimArrowLibrary.getSortedIds() do
		table.insert(listings, { Type = "AimArrow", Id = aimArrowId })
	end
	return listings
end

function ArrowsTab.subscribe(onChanged: () -> ())
	AimArrowController.AimArrowGrantedTasks:Add(onChanged)
end

return ArrowsTab
