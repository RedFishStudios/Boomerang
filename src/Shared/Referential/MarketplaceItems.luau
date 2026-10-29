--[[
	MarketplaceItems

	Description:
	Every Robux item the game sells: developer products (bought any number of times; granted by ProductService
	through a receipt) and gamepasses (owned once, forever). Look them up by name or by id through MarketplaceLibrary.
	Names must be unique across both kinds. Product ids and gamepass ids are separate number ranges on Roblox, so an id
	is only meaningful together with its type (ProductsById / GamepassesById).
]]

export type RobuxItemType = "Product" | "Gamepass"

export type RobuxItem = {
	Type: RobuxItemType,
	Id: number,
	Display: string,
	IconId: number?, -- Overrides product's real icon
	IsPaidRandomItem: boolean?, -- Item is disabled in a region where paid random items are restricted
}

-------------------------------------------------------------------------------
-- DATA
-------------------------------------------------------------------------------

-- // Developer products, by name
local Products: { [string]: { Id: number, Display: string, IconId: number?, IsPaidRandomItem: boolean? } } = {
	Placeholder = {
		Id = 3714074543,
		Display = "Placeholder",
	},
}

-- // Gamepasses, by name
local Gamepasses: { [string]: { Id: number, Display: string, IconId: number?, IsPaidRandomItem: boolean? } } = {}

-------------------------------------------------------------------------------
-- LOOKUP TABLES
-------------------------------------------------------------------------------

local MarketplaceItems: {
	ByName: { [string]: RobuxItem }, -- // Products and gamepasses
	ProductsById: { [number]: RobuxItem },
	GamepassesById: { [number]: RobuxItem },
	ById: { [number]: RobuxItem }, -- // Same table as ProductsById (kept for older code)
} = {
	ByName = {},
	ProductsById = {},
	GamepassesById = {},
	ById = {},
}
MarketplaceItems.ById = MarketplaceItems.ProductsById

local function register(definitions, itemType: RobuxItemType, byId: { [number]: RobuxItem })
	for name, definition in definitions do
		assert(not MarketplaceItems.ByName[name], `MarketplaceItems: duplicate name {name}`)
		local item: RobuxItem = {
			Type = itemType,
			Id = definition.Id,
			Display = definition.Display,
			IconId = definition.IconId,
			IsPaidRandomItem = definition.IsPaidRandomItem,
		}
		MarketplaceItems.ByName[name] = item
		byId[item.Id] = item
	end
end

register(Products, "Product", MarketplaceItems.ProductsById)
register(Gamepasses, "Gamepass", MarketplaceItems.GamepassesById)

return MarketplaceItems
