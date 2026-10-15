--[[
	ChargeUpEffects

	Description:
	Charge up effects players can own and equip. A charge up effect is the arrow shown on the ground while a player aims a throw
	(WeaponController); it is rendered locally by every client from the arrow's template in Shared/Assets/Gui.
	Ownership and the equipped arrow are saved in the profile (OwnedChargeUpEffects / EquippedChargeUpEffect) and handled by
	ChargeUpEffectService / ChargeUpEffectController. Same shape as Skins.
	Charge up effect ids are saved and sent over the network: never change or reuse one.
]]

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ChargeUpEffectId = string

export type ChargeUpEffect = {
	Name: string,
	Asset: string, -- // Name of the arrow template in Shared/Assets/Gui
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
		Asset = "DefaultAimArrow",
		Price = 0,
		Order = 1,
		Icon = nil, -- TODO:RELEASE placeholder (no GUI image yet)
		PlaceholderGlyph = "⬆️",
		Default = true,
		OffSale = true,
	},
	RedChargeUpEffect = {
		Name = "Red",
		Asset = "RedAimArrow",
		Price = 250, -- TODO:RELEASE placeholder
		Order = 2,
		Icon = nil, -- TODO:RELEASE placeholder (no GUI image yet)
		PlaceholderGlyph = "🔴",
	},
}

return ChargeUpEffects
