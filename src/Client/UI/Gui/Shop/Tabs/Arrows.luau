--[[
	Arrows tab (Shop)

	Description:
	Every charge up effect on sale, in the same order as the Inventory's Arrows tab (ChargeUpEffectLibrary / ChargeUpEffectController, data in
	Shared/Referential/ChargeUpEffects). Arrows that are off sale are left out by ShopListings. Scrolls past 6 listings.
	Follows the ShopTab shape in Shop/init.luau.
]]

local ArrowsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local ChargeUpEffectLibrary = require(ReplicatedStorage.Shared.Library.ChargeUpEffectLibrary)
local ChargeUpEffectController = require(ReplicatedStorage.Client.Core.ChargeUpEffectController)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ArrowsTab.Scrollable = true

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ArrowsTab.getListings(): { ShopItems.ShopListing }
	local listings = {}
	for _, chargeUpEffectId in ChargeUpEffectLibrary.getSortedIds() do
		table.insert(listings, { Type = "ChargeUpEffect", Id = chargeUpEffectId })
	end
	return listings
end

function ArrowsTab.subscribe(onChanged: () -> ())
	ChargeUpEffectController.ChargeUpEffectGrantedTasks:Add(onChanged)
end

return ArrowsTab
