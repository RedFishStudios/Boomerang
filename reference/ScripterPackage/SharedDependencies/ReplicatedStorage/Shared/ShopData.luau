-- What the Shop is selling right now. Edit this to run a new limited egg.

local ShopData = {}

ShopData.Banner = {
	title = "Limited Garbage Egg Skins",
	-- When the offer ends, as a UTC date. The Shop shows a countdown to it.
	endsAt = DateTime.fromUniversalTime(2026, 11, 23, 0, 0, 0).UnixTimestamp,
}

-- One entry per card, left to right. `skinId` refers to Shared.Cosmetics (Skins). Prices are in Robux; set
-- `productId` to the Developer Product id once it exists, otherwise the Buy button reports that it isn't set up.
ShopData.Offers = {
	{ skinId = "PaperMecha", odds = 61, price = 99, eggs = 1, productId = nil :: number? },
	{ skinId = "LunchBagSpy", odds = 29, price = 249, eggs = 3, productId = nil :: number? },
	{ skinId = "CptRed", odds = 9, price = 399, eggs = 5, productId = nil :: number? },
	{ skinId = "ParaBottler", odds = 1, price = 399, eggs = 5, productId = nil :: number? },
}

return ShopData
