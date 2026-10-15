--[[
	Emotes

	Description:
	Emotes players can own and equip. An emote is an animation a player's avatar performs on the winner pedestal
	(PedestalController); it is also previewed on the EmotesRig in the Shop and Inventory (ItemViewport.renderEmote).
	The emote key (e.g. "Breakdance") is the permanent id that is saved and sent over the network; AnimationId is the Roblox
	animation asset id that is published to everyone as the "WinningEmote" cosmetic (CosmeticLibrary / WinningEmoteLibrary).
	Ownership and the equipped emote are saved in the profile (OwnedEmotes / EquippedEmote) and handled by
	EmoteService / EmoteController. Same shape as ChargeUpEffects.
	Emote ids are saved and sent over the network: never change or reuse one.
]]

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type EmoteId = string

export type Emote = {
	Name: string,
	AnimationId: string, -- // Roblox animation asset id (digits)
	Price: number, -- // Currency price in the shop
	Order: number, -- // Display order in the Emotes menu and the shop
	Rarity: string?, -- // Shown in the shop and inventory; "Common" when missing
	Default: true?, -- // Owned by every player without being granted, and equipped by default
	OffSale: true?, -- // Hidden from the shop
	ProductId: number?, -- // Robux developer product, if it can be bought with Robux
}

-------------------------------------------------------------------------------
-- DATA
-------------------------------------------------------------------------------

local Emotes: { [EmoteId]: Emote } = {
	DefaultEmote = {
		Name = "Default",
		AnimationId = "122884053950359",
		Price = 0,
		Order = 1,
		Default = true,
		OffSale = true,
	},
	Breakdance = {
		Name = "Breakdance",
		AnimationId = "5915648917",
		Price = 300,
		Order = 2,
	},
}

return Emotes
