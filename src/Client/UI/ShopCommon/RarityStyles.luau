--[[
	RarityStyles

	Description:
	Shop listing colors by rarity. The rarity is the Rarity of the item's entry in Shared/Constants/Tools (see ShopListings).
	The listing art is grayscale and tinted with `Color`, which can only darken it, so colors are bright.
	Rarities not listed here use Common.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiColors = require(ReplicatedStorage.Shared.Referential.GuiColors)

local RarityStyles = {}

export type RarityStyle = {
	Color: Color3, -- // Tint of the listing frame
	TextColor: Color3, -- // Color of the rarity name
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

RarityStyles.DEFAULT_RARITY = "Common"

local STYLES: { [string]: RarityStyle } = {
	Common = { Color = GuiColors.CommonItemFrame, TextColor = Color3.fromRGB(215, 215, 215) },
	Rare = { Color = Color3.fromRGB(95, 160, 255), TextColor = Color3.fromRGB(95, 185, 255) },
	["Super Rare"] = { Color = Color3.fromRGB(60, 215, 255), TextColor = Color3.fromRGB(70, 225, 255) },
	Epic = { Color = Color3.fromRGB(190, 110, 255), TextColor = Color3.fromRGB(215, 120, 255) },
	Legendary = { Color = Color3.fromRGB(255, 205, 40), TextColor = Color3.fromRGB(255, 190, 40) },
}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function RarityStyles.get(rarity: string?): RarityStyle
	return STYLES[rarity or RarityStyles.DEFAULT_RARITY] or STYLES[RarityStyles.DEFAULT_RARITY]
end

return RarityStyles
