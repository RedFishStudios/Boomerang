--!strict
-- SAKURA DRIFT: a soft rose-pink ribbon with a narrow ivory centre and darker pink edges, and loose cupped petals
-- (no whole flowers) fluttering gently down behind it. Separate from the three-second Sakura kill effect.
-- Units: widths/sizes/lengths are fractions of the fan's tip-to-tip span; Spacing is in spans of travel; times in s.
local rgb = Color3.fromRGB

return {
	Name = "SakuraDrift",
	Length = 2,
	Width = 0.3,
	SegmentSpacing = 0.08,
	Lifetime = 0.9,
	FadeTime = 0.35,
	TeleportDistance = 3,
	Transparency = { 0.06, 0.88 },
	TransparencyPower = 1.3,

	Layers = {
		{
			Name = "PinkEdge",
			Width = 1,
			Colors = { { 0, rgb(230, 104, 148) }, { 1, rgb(240, 150, 180) } },
		},
		{
			Name = "Rose",
			Width = 0.76,
			Colors = { { 0, rgb(255, 162, 192) }, { 1, rgb(255, 196, 214) } },
			Glow = 0.1,
			ZOffset = 1,
		},
		{
			Name = "IvoryCore",
			Width = 0.22,
			Range = { 0, 0.8 },
			Colors = { { 0, rgb(255, 248, 238) }, { 1, rgb(255, 230, 236) } },
			Transparency = { 0.05, 1 },
			Glow = 0.15,
			ZOffset = 2,
		},
	},

	Particles = {
		{
			Name = "Petals",
			Shape = "Petal",
			Colors = { rgb(248, 172, 196), rgb(232, 116, 161), rgb(239, 147, 184) }, -- light, deep and mid rose
			Size = 0.13, -- petal length, in spans
			Spacing = 0.28,
			MaxAlive = 7,
			Lifetime = 0.9,
			Drift = 0.32,
			Fall = 0.3,
			Spin = 90,
			Tilt = 35,
			Spread = 0.85,
			Motion = "Flutter", -- cupped side kept mostly to the sky, so they read from overhead
			FirstAt = 0.4,
		},
	},
}
