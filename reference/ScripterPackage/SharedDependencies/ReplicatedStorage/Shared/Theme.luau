-- Shared design tokens for all UI. Change colors/fonts here, not in individual screens.
-- Palette sampled from the "Official Boomerang! UI" mockups. Painted art lives in Shared.Assets.

local Theme = {}

Theme.Colors = {
	-- Text: cream fill, dark brown outline and drop shadow (as on the mockup's "30" and labels).
	Text = Color3.fromRGB(252, 243, 224),
	Outline = Color3.fromRGB(70, 44, 28),
	Shadow = Color3.fromRGB(46, 28, 18),
	-- Dark brown lettering printed straight on cream panels (Stats window names and numbers).
	Ink = Color3.fromRGB(92, 48, 18),
	InkSoft = Color3.fromRGB(125, 85, 50), -- secondary lines such as the @username
	-- Sky blue behind the avatar headshot (as in the Stats mockup).
	AvatarBackdrop = Color3.fromRGB(96, 170, 230),

	-- Palette for screens drawn without art.
	Wood = Color3.fromRGB(150, 98, 58),
	WoodDark = Color3.fromRGB(104, 64, 38),
	Parchment = Color3.fromRGB(226, 196, 146),
	Stone = Color3.fromRGB(132, 108, 158),
	Gold = Color3.fromRGB(244, 188, 64),
	Gem = Color3.fromRGB(150, 104, 226),
	ButtonGreen = Color3.fromRGB(136, 182, 72),
}

-- Rarity label colors ("Common" matches the tan lettering in the Skins mockup).
Theme.Rarity = {
	Common = Color3.fromRGB(236, 206, 158),
	Rare = Color3.fromRGB(110, 190, 255),
	Epic = Color3.fromRGB(196, 120, 255),
	Legendary = Color3.fromRGB(255, 196, 64),
}

Theme.Font = Font.fromEnum(Enum.Font.FredokaOne)

Theme.Motion = {
	Hover = 1.05,
	Press = 0.94,
	Time = 0.12,
}

return Theme
