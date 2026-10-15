--[[
	ChargeUpEffects

	Description:
	Charge up effects players can own and equip. A charge up effect is what plays on a player while they charge a throw
	(WeaponController); today each one shows an arrow on the ground. The effect's id is the name of the logic module in
	Shared/Logics/ChargeUpEffects that animates it (every client runs it locally), so each effect can behave differently.
	Ownership and the equipped effect are saved in the profile (OwnedChargeUpEffects / EquippedChargeUpEffect) and handled by
	ChargeUpEffectService / ChargeUpEffectController. Same shape as Skins.
	Charge up effect ids are saved and sent over the network: never change or reuse one.
]]

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ChargeUpEffectId = string

export type ChargeUpEffect = {
	Name: string,
	Price: number, -- // Currency price in the shop
	Order: number, -- // Display order in the Arrows menu and the shop
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

local ChargeUpEffects: { [ChargeUpEffectId]: ChargeUpEffect } = {
	DefaultChargeUpEffect = {
		Name = "Default",
		Price = 0,
		Order = 1,
		Icon = nil, -- TODO:RELEASE placeholder (no GUI image yet)
		PlaceholderGlyph = "⬆️",
		Default = true,
		OffSale = true,
	},
	RedChargeUpEffect = {
		Name = "Red",
		Price = 250, -- TODO:RELEASE placeholder
		Order = 2,
		Icon = nil, -- TODO:RELEASE placeholder (no GUI image yet)
		PlaceholderGlyph = "🔴",
	},
}

return ChargeUpEffects
