--!strict
-- MOONSONG: an elegant moonlight ribbon, deep blue outside and cyan inside with a thin silver-white highlight along
-- one edge, a few white feathers tilting and tumbling away from it, and a couple of small, softly glowing blue orbs.
-- Units: widths/sizes/lengths are fractions of the fan's tip-to-tip span; Spacing is in spans of travel; times in s.
local rgb = Color3.fromRGB

return {
	Name = "Moonsong",
	Length = 2,
	Width = 0.3,
	SegmentSpacing = 0.08,
	Lifetime = 1.0,
	FadeTime = 0.4,
	TeleportDistance = 3,
	Transparency = { 0.06, 0.88 },
	TransparencyPower = 1.2,

	Layers = {
		{
			Name = "DeepBlue",
			Width = 1,
			Colors = { { 0, rgb(34, 58, 168) }, { 1, rgb(56, 104, 200) } },
			Wave = { 0.05, 0.5, 0.3 },
		},
		{
			Name = "Cyan",
			Width = 0.6,
			Offset = -0.15,
			Colors = { { 0, rgb(80, 206, 246) }, { 1, rgb(140, 220, 250) } },
			Wave = { 0.05, 0.5, 0.3 },
			Glow = 0.2,
			ZOffset = 1,
		},
		{ -- thin silver-white highlight along one edge
			Name = "Silver",
			Width = 0.12,
			Offset = 3.6,
			Range = { 0, 0.85 },
			Colors = { { 0, rgb(240, 248, 255) }, { 1, rgb(214, 232, 250) } },
			Transparency = { 0.05, 1 },
			Glow = 0.3,
			ZOffset = 2,
		},
	},

	-- Kept clean and airy: two or three white feathers and about two small, softly glowing blue orbs, spaced apart.
	Particles = {
		{
			Name = "Feathers",
			Shape = "Feather",
			Colors = { rgb(252, 250, 242), rgb(244, 240, 226) },
			Size = 0.36,
			Spacing = 0.8,
			MaxAlive = 3,
			Lifetime = 1.05,
			Drift = 0.3,
			Fall = 0.1,
			Spin = 50, -- slow turn
			Tilt = 35, -- degrees of gentle tilt
			Spread = 0.75,
			Motion = "Flutter",
		},
		{
			Name = "Orbs",
			Shape = "Orb", -- a small pale-blue glowing core in a soft halo
			Colors = { rgb(92, 178, 255), rgb(70, 150, 245) },
			Size = 0.07,
			Spacing = 1.0,
			MaxAlive = 2,
			Lifetime = 0.9,
			Drift = 0.08,
			Fall = -0.06, -- floats up a little
			Spread = 0.6,
			Motion = "Float",
			FirstAt = 0.6,
		},
	},
}
