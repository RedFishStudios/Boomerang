--[[
	Strike Effects tab (Cosmetics Shop)

	Description:
	Every elimination effect ("Strike Effect") on sale, in the Inventory Strikes tab's order (ElimEffectLibrary /
	ElimEffectController, data in Shared/Referential/ElimEffects). ShopListings omits off-sale effects. Scrolls past
	6 listings. Follows the ShopTab shape in ShopCommon/ShopBuilder.
]]

local ElimEffectsTab = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local ElimEffectLibrary = require(ReplicatedStorage.Shared.Library.ElimEffectLibrary)
local ElimEffectController = require(ReplicatedStorage.Client.Core.ElimEffectController)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ElimEffectsTab.Scrollable = true

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ElimEffectsTab.getListings(): { ShopItems.ShopListing }
	local listings = {}
	for _, elimEffectId in ElimEffectLibrary.getSortedIds() do
		table.insert(listings, { Type = "ElimEffect", Id = elimEffectId })
	end
	return listings
end

function ElimEffectsTab.subscribe(onChanged: () -> ())
	ElimEffectController.ElimEffectGrantedTasks:Add(onChanged)
end

return ElimEffectsTab
