--!strict
-- SUNSET POP: a clean, warm sunlight streak: bright yellow centre, orange around it, a narrow coral-pink outer edge,
-- softening into pink-orange towards the tail, with a few small golden glints. No flames, smoke or embers.
-- Units: widths/sizes/lengths are fractions of the fan's tip-to-tip span; Spacing is in spans of travel; times in s.
local rgb = Color3.fromRGB

return {
	Name = "SunsetPop",
	Length = 2,
	Width = 0.3,
	SegmentSpacing = 0.08,
	Lifetime = 0.9,
	FadeTime = 0.35,
	TeleportDistance = 3,
	Transparency = { 0.05, 0.88 },
	TransparencyPower = 1.3,

	Layers = {
		{ -- coral-pink outer edge
			Name = "CoralEdge",
			Width = 1,
			Colors = { { 0, rgb(255, 110, 128) }, { 1, rgb(255, 150, 160) } },
			Wave = { 0.08, 0.55, 0.35 },
		},
		{ -- orange body
			Name = "Orange",
			Width = 0.74,
			Colors = { { 0, rgb(255, 146, 44) }, { 0.6, rgb(255, 150, 96) }, { 1, rgb(255, 160, 140) } },
			Wave = { 0.08, 0.55, 0.35 },
			Glow = 0.15,
			ZOffset = 1,
		},
		{ -- warm yellow centre, brightest at the fan
			Name = "YellowCore",
			Width = 0.38,
			Range = { 0, 0.85 },
			Colors = { { 0, rgb(255, 238, 110) }, { 0.6, rgb(255, 206, 120) }, { 1, rgb(255, 180, 140) } },
			Wave = { 0.1, 0.55, 0.35, 0.8 },
			Glow = 0.3,
			ZOffset = 2,
		},
	},

	Particles = {
		{
			Name = "Glints",
			Shape = "Diamond",
			Colors = { rgb(255, 212, 76), rgb(255, 226, 120) },
			Size = 0.1,
			Spacing = 0.42,
			MaxAlive = 5,
			Lifetime = 0.55,
			Drift = 0.05,
			Spin = 120,
			Spread = 0.7,
			Motion = "Glint",
		},
	},
}
