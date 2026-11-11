--!strict
-- TIDAL SURGE: a straight strip of flowing blue water directly behind the fan (it follows the fan's path like the other
-- trails; the strip itself never snakes or loops). The wave look lives inside the strip: deep blue water with a cyan
-- surface, white foam lines along both edges broken into patches, pale ripple streaks, all flowing from the fan back
-- towards the tapered, fading tail. White foam flecks and a little spray stay within the strip's width.
-- Units: widths/sizes/lengths are fractions of the fan's tip-to-tip span; Spacing is in spans of travel; times in s.
-- Wave = { amplitude, cycles per span, speed, phase }: a negative speed makes the pattern flow towards the tail.
local rgb = Color3.fromRGB

return {
	Name = "TidalSurge",
	Length = 2,
	Width = 0.3,
	SegmentSpacing = 0.05,
	Lifetime = 0.9,
	FadeTime = 0.35,
	TeleportDistance = 3,
	Transparency = { 0.04, 0.85 },
	TransparencyPower = 1.3,

	Layers = {
		{ -- deep blue water: the full strip, a soft swell in its width
			Name = "DeepWater",
			Width = 1.0,
			Colors = { { 0, rgb(6, 88, 143) }, { 1, rgb(19, 139, 183) } },
			Wave = { 0.06, 1.2, -0.9 },
		},
		{ -- cyan surface water
			Name = "Cyan",
			Width = 0.66,
			Colors = { { 0, rgb(21, 201, 223) }, { 1, rgb(54, 198, 223) } },
			Wave = { 0.14, 1.8, -1.2, 1.2 },
			Glow = 0.1,
			ZOffset = 1,
		},
		{ -- pale ripple streaks flowing back through the middle (pinched into dashes)
			Name = "Ripples",
			Width = 0.14,
			Offset = -0.6,
			Range = { 0.04, 0.8 },
			Colors = { { 0, rgb(193, 249, 250) }, { 1, rgb(160, 230, 240) } },
			Transparency = { 0.15, 1 },
			Wave = { 0.95, 2.4, -1.6 },
			ZOffset = 2,
		},
		{ -- white foam along one edge, broken into patches
			Name = "FoamLeft",
			Width = 0.22,
			Offset = 2.0,
			Range = { 0, 0.85 },
			Colors = { { 0, rgb(250, 255, 255) }, { 1, rgb(214, 246, 250) } },
			Transparency = { 0, 0.9 },
			Wave = { 0.85, 1.6, -1.3 },
			Glow = 0.15,
			ZOffset = 3,
		},
		{ -- and the other edge, out of step
			Name = "FoamRight",
			Width = 0.2,
			Offset = -2.2,
			Range = { 0, 0.8 },
			Colors = { { 0, rgb(250, 255, 255) }, { 1, rgb(214, 246, 250) } },
			Transparency = { 0, 0.9 },
			Wave = { 0.85, 1.6, -1.3, 2.4 },
			Glow = 0.15,
			ZOffset = 3,
		},
	},

	Particles = {
		{
			Name = "Foam",
			Shape = "Foam", -- a small cluster of white foam bubbles lying on the water
			Colors = { rgb(255, 255, 255), rgb(236, 252, 255) },
			Size = 0.1,
			SizeJitter = 0.25,
			Spacing = 0.32,
			MaxAlive = 5,
			Lifetime = 0.6,
			BackOffset = 0.1,
			Spread = 0.4, -- stays inside the strip
			Motion = "Fleck",
		},
		{
			Name = "Spray",
			Shape = "Droplet",
			Colors = { rgb(121, 225, 236) },
			Size = 0.05,
			Spacing = 0.5,
			MaxAlive = 4,
			Lifetime = 0.45,
			Drift = 0.1,
			Fall = -0.15,
			Gravity = 1.4,
			Spread = 0.35,
			Motion = "Drop",
		},
	},
}
