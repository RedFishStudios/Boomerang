--[[
	ShopListings

	Description:
	Turns a ShopItems listing ({ Type = "Item" | "Skin", Id }) into what the Shop shows for it. A skin's data comes from
	Shared/Referential/Skins (through SkinLibrary / SkinController, the same system as the Inventory's Skins tab), an
	item's from Shared/Referential/Items. Used by every tab, so a tab only has to say which listings it has.
]]

local ShopListings = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Referential.Items)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local SkinController = require(ReplicatedStorage.Client.Core.SkinController)
local RarityStyles = require(script.Parent.RarityStyles)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ListingDisplay = {
	Id: string,
	Type: string, -- // "Item" | "Skin"
	Name: string,
	ModelName: string?, -- // Model in Shared/Assets/Tools shown in the listing's viewport
	Rarity: string,
	Price: number, -- // Currency price
	ProductId: number?, -- // Robux developer product, if it can be bought with Robux
	IsPaidRandomItem: boolean?,
	Owned: boolean,
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // RARITY INSERTION POINT: the rarity of a listing is the Rarity of its model's entry in Shared/Constants/Tools.
-- // Rarities aren't really in use yet (every tool there is a "Common" placeholder), so every listing is Common until
-- // they are. RarityStyles decides the colors; nothing else in the Shop has to change when real rarities land.
local function getRarity(modelName: string?): string
	local tool = if modelName then Tools[modelName] else nil
	return (tool and tool.Rarity) or RarityStyles.DEFAULT_RARITY
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // What a listing shows; nil when it doesn't exist or is off sale
function ShopListings.getDisplay(listing: { Type: string, Id: string }): ListingDisplay?
	if listing.Type == "Skin" then
		local skin = SkinLibrary.getSkin(listing.Id)
		if not skin or skin.OffSale then
			return nil
		end
		return {
			Id = listing.Id,
			Type = listing.Type,
			Name = skin.Name,
			ModelName = skin.Model,
			Rarity = getRarity(skin.Model),
			Price = skin.Price,
			ProductId = skin.ProductId,
			Owned = SkinController.ownsSkin(listing.Id),
		}
	end

	local itemData = Items[listing.Id]
	if not itemData or itemData.OffSale then
		return nil
	end
	return {
		Id = listing.Id,
		Type = listing.Type,
		Name = itemData.Name,
		ModelName = itemData.Model,
		Rarity = getRarity(itemData.Model),
		Price = itemData.Price,
		ProductId = itemData.ProductId,
		IsPaidRandomItem = itemData.IsPaidRandomItem,
		Owned = false, -- // Items can be bought again
	}
end

return ShopListings
