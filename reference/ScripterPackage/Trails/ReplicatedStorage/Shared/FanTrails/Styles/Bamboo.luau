--!strict
-- BAMBOO FAN: a calm green gust of wind with a pale-cream centre line and gently separated edge streaks, plus a few
-- bamboo leaves turning slowly as they fall behind.
-- Units: widths/sizes/lengths are fractions of the fan's tip-to-tip span; Spacing is in spans of travel; times in s.
local rgb = Color3.fromRGB

return {
	Name = "Bamboo",
	Length = 2, -- trail length behind the fan, in fan spans (hard limit, enforced every frame)
	Width = 0.3, -- ribbon width at the fan, as a fraction of the span (20-35%)
	SegmentSpacing = 0.08, -- spans of travel between ribbon points (smoothness)
	Lifetime = 0.9, -- a section disappears after this long even if the fan is slow
	FadeTime = 0.35, -- after Stop(): the rest of the trail shrinks and fades over this
	TeleportDistance = 3, -- a jump bigger than this (spans, in one frame) clears the trail instead of joining it
	Transparency = { 0.08, 0.9 }, -- at the fan, at the tail
	TransparencyPower = 1.4,

	Layers = {
		{ -- the gust: fresh leaf green at the fan, softer translucent green at the tail
			Name = "Gust",
			Width = 1,
			Colors = { { 0, rgb(88, 190, 66) }, { 0.5, rgb(122, 206, 104) }, { 1, rgb(176, 226, 160) } },
			Wave = { 0.06, 0.7, 0.4 },
			Glow = 0.12,
		},
		{ -- a separated wind streak just outside one edge
			Name = "StreakA",
			Width = 0.16,
			Offset = 3.6,
			Range = { 0.06, 0.8 },
			Colors = { { 0, rgb(66, 168, 58) }, { 1, rgb(150, 214, 130) } },
			Transparency = { 0.2, 1 },
			Wiggle = { 0.05, 0.9, 0.5 },
		},
		{ -- and a shorter one outside the other edge
			Name = "StreakB",
			Width = 0.12,
			Offset = -4.6,
			Range = { 0.14, 0.62 },
			Colors = { { 0, rgb(70, 170, 60) }, { 1, rgb(150, 214, 130) } },
			Transparency = { 0.25, 1 },
			Wiggle = { 0.05, 0.9, 0.5, 2 },
		},
		{ -- the narrow pale-cream highlight through the centre
			Name = "Highlight",
			Width = 0.26,
			Range = { 0, 0.8 },
			Colors = { { 0, rgb(252, 248, 218) }, { 1, rgb(232, 244, 206) } },
			Transparency = { 0.05, 1 },
			Glow = 0.2,
			ZOffset = 1,
		},
	},

	Particles = {
		{
			Name = "Leaves",
			Shape = "Leaf",
			Colors = { rgb(78, 156, 56), rgb(36, 100, 40) }, -- alternating medium and dark green
			Size = 0.26, -- leaf length, in spans
			Spacing = 0.45, -- one leaf every this many spans of travel
			MaxAlive = 5,
			Lifetime = 1.0,
			Drift = 0.32, -- spans/s away from the centreline
			Fall = 0.22, -- spans/s downward
			Spin = 80, -- deg/s, a slow turn
			Spread = 0.75,
			Motion = "Flutter",
		},
	},
}
