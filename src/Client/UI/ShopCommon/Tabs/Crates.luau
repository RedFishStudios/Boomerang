--[[
	Crates tab (Weapons Shop)

	Description:
	Every weapon crate on sale (Shared/Referential/Crates), in their Order. The Weapons Shop has only this tab (its tab
	row is hidden). Crates can be bought repeatedly, so their listing never changes.
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
