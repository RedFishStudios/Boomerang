--[[
	Taunts

	Description:
	Taunts players can own and equip, played with T (gamepad Y, or the touch button) in the RoundEnded phase, while
	everyone is still in the arena after a round. A taunt's id is the name of its module in
	Client/Core/TauntController/Taunts (every client plays it locally). Separate from Emotes, which the winner performs on
	the pedestal. Ownership and the equipped taunt are saved in the profile (OwnedTaunts / EquippedTaunt) and handled by
	TauntService / TauntController. Same shape as ChargeUpEffects. From the client's scripter package.
	Taunt ids are saved and sent over the network: never change or reuse one.
]]

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type TauntId = string

export type Taunt = {
	Name: string,
	Price: number, -- // Currency price in the shop
	Order: number, -- // Display order in the Taunts menu and the shop
	Rarity: string?, -- // Shown in the shop and inventory; "Common" when missing
	Icon: number?, -- // GUI image asset id; nil shows a placeholder label until the art exists
	PlaceholderGlyph: string?, -- // Emoji shown by the placeholder label while Icon is nil
	Default: true?, -- // Owned by every player without being granted, and equipped by default
	OffSale: true?, -- // Hidden from the shop
	ProductId: number?, -- // Robux developer product, if it can be bought with Robux
}

-------------------------------------------------------------------------------
-- DATA
-------------------------------------------------------------------------------

local Taunts: { [TauntId]: Taunt } = {
	TooEasy = {
		Name = "Too Easy",
		Price = 0,
		Order = 1,
		Icon = 127410866517037, -- // The package's "Laugh" card
		Default = true,
		OffSale = true,
	},
	Bonk = {
		Name = "Bonk!",
		Price = 500, -- TODO:RELEASE placeholder
		Order = 2,
		Rarity = "Rare", -- TODO:RELEASE placeholder (the package's rarity)
		Icon = 99346101856261, -- // The package's "Dance" card
	},
	RoyalTreatment = {
		Name = "Royal Treatment",
		Price = 1000, -- TODO:RELEASE placeholder
		Order = 3,
		Rarity = "Epic", -- TODO:RELEASE placeholder (the package's rarity)
		Icon = 110494031510556, -- // The package's "Flex" card
	},
	NapTime = {
		Name = "Nap Time",
		Price = 2500, -- TODO:RELEASE placeholder
		Order = 4,
		Rarity = "Legendary", -- TODO:RELEASE placeholder (the package's rarity)
		Icon = 127410866517037, -- TODO:RELEASE placeholder (the package reuses the "Laugh" card)
	},
}

return Taunts
