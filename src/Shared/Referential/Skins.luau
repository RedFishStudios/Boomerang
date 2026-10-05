--[[
	Skins

	Description:
	Boomerang skins players can own and equip. A skin decides the model the player holds and throws;
	its WeaponClass (an id in Shared/Constants/Tools) decides the stats. Ownership and the equipped skin
	are saved in the profile (OwnedSkins / EquippedSkin) and handled by SkinService / SkinController.
	Skin ids are saved and sent over the network: never change or reuse one.
]]

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type SkinId = string

export type Skin = {
	Name: string,
	Model: string, -- // Name of the model in Shared/Assets/Tools
	WeaponClass: string, -- // Tool id in Shared/Constants/Tools (stats)
	Price: number, -- // Currency price in the shop
	Order: number, -- // Display order in the Skins menu and the shop
	Default: true?, -- // Owned by every player without being granted, and equipped by default
	OffSale: true?, -- // Hidden from the shop
	ProductId: number?, -- // Robux developer product, if it can be bought with Robux
}

-------------------------------------------------------------------------------
-- DATA
-------------------------------------------------------------------------------

local Skins: { [SkinId]: Skin } = {
	ClassicBoomerang = {
		Name = "Classic",
		Model = "ClassicBoomerang",
		WeaponClass = "ClassicBoomerang",
		Price = 0,
		Order = 1,
		Default = true,
		OffSale = true,
	},
	Shuriken = {
		Name = "Shuriken",
		Model = "Shuriken",
		WeaponClass = "ClassicBoomerang", -- TODO:RELEASE placeholder (every skin uses the Classic stats for now)
		Price = 500, -- TODO:RELEASE placeholder
		Order = 2,
	},
	Fan = {
		Name = "Fan",
		Model = "Fan",
		WeaponClass = "ClassicBoomerang", -- TODO:RELEASE placeholder (every skin uses the Classic stats for now)
		Price = 1000, -- TODO:RELEASE placeholder
		Order = 3,
	},
}

return Skins
