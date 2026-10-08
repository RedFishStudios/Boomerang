--[[
	Featured tab (Shop)

	Description:
	Hand-picked listings (ShopItems.Tabs.Featured.Listings). Shows at most 6 (3x2) and doesn't scroll.
	Follows the ShopTab shape in Shop/init.luau.
]]

local FeaturedTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local SkinController = require(ReplicatedStorage.Client.Core.SkinController)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

FeaturedTab.Scrollable = false
FeaturedTab.MaxListings = 6

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function FeaturedTab.getListings(): { ShopItems.ShopListing }
	return ShopItems.Tabs.Featured.Listings or {}
end

-- // A featured skin that was just bought shows as Owned
function FeaturedTab.subscribe(onChanged: () -> ())
	SkinController.SkinGrantedTasks:Add(onChanged)
end

return FeaturedTab
