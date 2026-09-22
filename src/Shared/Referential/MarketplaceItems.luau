export type RobuxItem = {
	Id: number,
	Display: string,
	IconId: number?, -- Overrides product's real icon
	IsPaidRandomItem: boolean?, -- Item is disabled in a region where paid random items are restricted
}

local MarketplaceItems: {
   ByName: { [string]: RobuxItem },
   ById: { [number]: RobuxItem }
} = {
   ByName = {
      Placeholder = {
         Id = 3714074543,
         Display = "Placeholder",
	   }
   },
   ById = {}
}

-- // Initialize ById tables
for name, product in pairs(MarketplaceItems.ByName) do
	MarketplaceItems.ById[product.Id] = product
end

return MarketplaceItems