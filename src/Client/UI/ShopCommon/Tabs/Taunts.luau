--[[
	Taunts tab (Cosmetics Shop)

	Description:
	Every taunt on sale, in the Inventory Taunts tab's order (TauntLibrary /
	TauntController, data in Shared/Referential/Taunts). ShopListings omits off-sale taunts. Scrolls past
	6 listings. Follows the ShopTab shape in ShopCommon/ShopBuilder.
]]

local TauntsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local TauntLibrary = require(ReplicatedStorage.Shared.Library.TauntLibrary)
local TauntController = require(ReplicatedStorage.Client.Core.TauntController)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

TauntsTab.Scrollable = true

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function TauntsTab.getListings(): { ShopItems.ShopListing }
	local listings = {}
	for _, tauntId in TauntLibrary.getSortedIds() do
		table.insert(listings, { Type = "Taunt", Id = tauntId })
	end
	return listings
end

function TauntsTab.subscribe(onChanged: () -> ())
	TauntController.TauntGrantedTasks:Add(onChanged)
end

return TauntsTab
