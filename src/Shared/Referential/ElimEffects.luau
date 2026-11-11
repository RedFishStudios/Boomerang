--[[
	ElimEffects

	Description:
	Elimination effects ("Strike Effects" in the game) players can own and equip. When a player is eliminated by
	another player, the eliminator's equipped effect plays on the eliminated player's body, for everyone. The effect's
	id is the name of its module in Client/Core/ElimEffectController/Effects; the default effect has no module and
	plays nothing (the normal ragdoll). Ownership and the equipped effect are saved in the profile (OwnedElimEffects /
	EquippedElimEffect) and handled by ElimEffectService / ElimEffectController. Same shape as ChargeUpEffects.
	From the client's scripter package (its "Kill Effects": Skull, Stone, Ashes, Sakura, Shark).
	Elimination effect ids are saved and sent over the network: never change or reuse one.
]]

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ElimEffectId = string

export type ElimEffect = {
	Name: string,
	Price: number, -- // Currency price in the shop
	Order: number, -- // Display order in the Strikes menu and the shop
	Rarity: string?, -- // Shown in the shop and inventory; "Common" when missing
	Icon: number?, -- // GUI image asset id; nil shows a placeholder label until the art exists
	PlaceholderGlyph: string?, -- // Emoji shown by the placeholder label while Icon is nil
	Default: true?, -- // Owned by every player without being granted, and equipped by default. Plays nothing
	OffSale: true?, -- // Hidden from the shop
	ProductId: number?, -- // Robux developer product, if it can be bought with Robux
}

-------------------------------------------------------------------------------
-- DATA
-------------------------------------------------------------------------------

local ElimEffects: { [ElimEffectId]: ElimEffect } = {
	DefaultElimEffect = {
		Name = "Default",
		Price = 0,
		Order = 1,
		Icon = 75872067653950, -- // The package's "Skull" card
		Default = true,
		OffSale = true,
	},
	StoneStatue = {
		Name = "Stone Statue",
		Price = 500, -- TODO:RELEASE placeholder
		Order = 2,
		Rarity = "Rare", -- TODO:RELEASE placeholder (the package's rarity)
		Icon = 102302090252595,
	},
	Ashes = {
		Name = "Ashes",
		Price = 1000, -- TODO:RELEASE placeholder
		Order = 3,
		Rarity = "Epic", -- TODO:RELEASE placeholder (the package's rarity)
		Icon = 135143054207331,
	},
	Sakura = {
		Name = "Sakura",
		Price = 1000, -- TODO:RELEASE placeholder
		Order = 4,
		Rarity = "Epic", -- TODO:RELEASE placeholder (the package's rarity)
		Icon = 137908369916180,
	},
	SharkAttack = {
		Name = "Shark Attack",
		Price = 2500, -- TODO:RELEASE placeholder
		Order = 5,
		Rarity = "Legendary", -- TODO:RELEASE placeholder (the package's rarity)
		Icon = 113492942953005,
	},
}

return ElimEffects
