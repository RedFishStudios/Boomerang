-- image asset ids

return {
   RoundArrow = 135765544529212,

   -- Daily Login Rewards / shared GUI art
   LoginRewardsFrame = 127382807461790,
   ListingFrame = 105517889005779,
   ListingFrameButtonGreen = 115489178458642,
   ListingFrameButtonTeal = 137310124184905,
   CloseButton = 83841981001141,

   -- Inventory
   InventoryFrame = 79347675065715, -- // Primary content area (frame with the title plank)
   InventoryItemListingFrame = 112976197760413, -- // Grayscale: tint with ImageColor3. Has transparent padding: to make the visible frame fill its parent, use Size (1.5181, 0, 1.2294, 0) and Position (-0.2596, 0, -0.1397, 0) (visible aspect 0.876)
   InventoryTabFrame = 106475010092350, -- // Grayscale: tint with ImageColor3

   -- Currency
   CurrencyIcon = 110596837298294, -- // The coin: shown for currency amounts (Shop buttons, Daily Rewards)
   RobuxIcon = 108754684100527, -- // The Robux hexagon (Shop Robux price buttons)

   -- Shop
   ShopFrame = 108529108372056, -- // Main body frame (wooden frame, title plank, purple corner stones)
   ShopTabButton = 138983302127969, -- // Grayscale: tint with ImageColor3 (purple selected / brown unselected)
   ShopListingBase = 106960187088227, -- // Grayscale: tint with ImageColor3 (by rarity)
   ShopBalanceFrame = 120067026989991, -- // Plank at the bottom showing the player's balance
   ShopSquareButton = 79716048358641, -- // Grayscale: tint with ImageColor3 (gift button)
   ShopWideButton = 79716048358641, -- // Grayscale: tint with ImageColor3 (price buttons). TODO: same id as ShopSquareButton as given; confirm it's the intended wide art
   GiftIcon = 78111289121317, -- // Gift box shown on the gift button,

	-- Abilities
	ElectricBoomerang = 98510163856303,
	ExplosiveBoomerang = 98510163856303,
	FireBoomerang = 83181687488794,
	TeleportBoomerang = 113756730038308,
	DisguisePickup = 110455057830397,
	HomingBoomerang = 96446271835879,
	OnFireEffect = 118956710558189,
	HotPotato = 90914469539086,
	ShieldPickup = 91847330548907,

}
