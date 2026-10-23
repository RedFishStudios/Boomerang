--[[
	Crates tab (Weapons Shop, T-112)

	Description:
	Every weapon crate on sale (Shared/Referential/Crates), in their Order. The Weapons Shop is a single window with only
	this tab (its tab row is hidden). Crates can be bought again and again, so nothing changes their listing.
	Follows the ShopTab shape in ShopCommon/ShopBuilder.
]]

local CratesTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local CrateLibrary = require(ReplicatedStorage.Shared.Library.CrateLibrary)

CratesTab.Scrollable = true

function CratesTab.getListings(): { ShopItems.ShopListing }
	local listings = {}
	for _, crateId in CrateLibrary.getSortedCrateIds() do
		table.insert(listings, { Type = "Crate", Id = crateId })
	end
	return listings
end

function CratesTab.subscribe(_onChanged: () -> ()) end

return CratesTab
