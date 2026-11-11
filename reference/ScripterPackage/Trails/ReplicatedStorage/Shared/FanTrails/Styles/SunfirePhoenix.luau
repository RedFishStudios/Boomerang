--!strict
-- SUNFIRE PHOENIX: one connected cartoon flame plume from the fan in deep crimson: dark crimson outside, crimson
-- middle and a narrow scarlet highlight, each rippling with its own flame tongues (broad bases, tapered curling tips) at slightly different moments, splitting
-- into three feather-like flame tips towards the older end, with scarlet embers peeling off the edges.
-- Units: widths/sizes/lengths are fractions of the fan's tip-to-tip span; Spacing is in spans of travel; times in s.
local rgb = Color3.fromRGB

-- Head colour (at the fan) -> tail colour, from the trail reference.
local DARK = { rgb(174, 20, 37), rgb(113, 9, 29) }
local CRIMSON = { rgb(216, 45, 42), rgb(160, 24, 37) }
local SCARLET = { rgb(239, 100, 44), rgb(195, 40, 37) }
local TIP = { rgb(220, 52, 48), rgb(164, 17, 37) }

return {
	Name = "SunfirePhoenix",
	Length = 2,
	Width = 0.34, -- with the tongues' ripple it briefly reaches about 45% of the span
	SegmentSpacing = 0.04, -- fine segments keep the rippling flame edges smooth
	Lifetime = 0.8,
	FadeTime = 0.35,
	TeleportDistance = 3,
	Transparency = { 0.02, 0.75 },
	TransparencyPower = 1.6,

	Layers = {
		{ -- dark crimson outer flame
			Name = "DarkCrimson",
			Width = 1,
			Range = { 0, 0.7 },
			Taper = 0.45,
			Colors = { { 0, DARK[1] }, { 1, DARK[2] } },
			Wave = { 0.3, 2.2, 1.6 }, -- tongues: bulges travelling back along the plume
			Wiggle = { 0.06, 1.3, 1.1 },
		},
		{ -- crimson middle layer, tongues out of step with the outer one
			Name = "Crimson",
			Width = 0.72,
			Range = { 0, 0.62 },
			Taper = 0.5,
			Colors = { { 0, CRIMSON[1] }, { 1, CRIMSON[2] } },
			Wave = { 0.32, 2.6, 2.0, 1.7 },
			Wiggle = { 0.06, 1.5, 1.3, 1 },
			Glow = 0.07,
			ZOffset = 1,
		},
		{ -- narrow scarlet highlight
			Name = "ScarletCore",
			Width = 0.34,
			Range = { 0, 0.5 },
			Taper = 0.6,
			Colors = { { 0, SCARLET[1] }, { 1, SCARLET[2] } },
			Wave = { 0.28, 3.0, 2.4, 3.1 },
			Glow = 0.12,
			ZOffset = 2,
		},
		-- Feather tips: the plume splits into three tapering flame feathers towards the older end.
		{
			Name = "TipLeft",
			Width = 0.5,
			Range = { 0.4, 0.92 },
			Taper = 0.9,
			Spread = -0.38,
			Colors = { { 0, TIP[1] }, { 1, TIP[2] } },
			Wiggle = { 0.05, 1.2, 1.2 },
			Glow = 0.06,
		},
		{
			Name = "TipMiddle",
			Width = 0.56,
			Range = { 0.4, 1 },
			Taper = 0.85,
			Colors = { { 0, SCARLET[1] }, { 1, SCARLET[2] } },
			Wiggle = { 0.04, 1.2, 1.4, 1.2 },
			Glow = 0.06,
			ZOffset = 1,
		},
		{
			Name = "TipRight",
			Width = 0.5,
			Range = { 0.4, 0.92 },
			Taper = 0.9,
			Spread = 0.38,
			Colors = { { 0, TIP[1] }, { 1, TIP[2] } },
			Wiggle = { 0.05, 1.2, 1.2, 2.4 },
			Glow = 0.06,
		},
	},

	Particles = {
		{
			Name = "Embers",
			Shape = "Ember",
			Colors = { rgb(231, 77, 43), rgb(187, 32, 41) },
			Size = 0.085,
			Spacing = 0.3,
			MaxAlive = 6,
			Lifetime = 0.6,
			Edge = true, -- peel off the flame's outline
			EdgeRange = { 0.06, 0.5 },
			Drift = 0.4,
			Fall = -0.35, -- drift up
			Spread = 0.15,
			Motion = "Ember",
		},
	},
}
