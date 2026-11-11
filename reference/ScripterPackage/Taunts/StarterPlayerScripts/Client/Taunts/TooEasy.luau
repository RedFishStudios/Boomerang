-- "Too Easy" taunt, 6 seconds, R15, no props. Relaxed and smug, with big upper-body shapes that read from the
-- overhead gameplay camera.
--   0.0-1.0  An exaggerated yawn: right hand to the mouth (palm to the mouth), head and upper body tilting back.
--   1.0-4.0  Both hands behind the head, elbows spread wide out to the sides past the torso, a slight backward lean and
--            a slow relaxed sway.
--   4.0-5.6  The right hand brushes off the left shoulder and flicks out wide to the side; then the left hand brushes
--            off the right shoulder and flicks out wide.
--   5.6-6.0  Arms down and a smooth return to idle.
-- Effects: a little breath puff on the yawn, white dust puffs flying off each shoulder with the flick, and a big bold
-- camera-facing "EZ" above and beside the character during the final brush (gone by 5.6).
-- Only the upper body is animated: the legs keep their normal standing pose, so the feet stay planted where they were
-- (no sliding) and the character doesn't move from its spot. Arm angles were solved against an R15 rig so the hands land
-- on the mouth, behind the head and on the opposite shoulder, with the elbows and flicks well outside the torso.

local Pose = require(script.Parent:WaitForChild("Pose"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local DURATION = 6

-- stylua: ignore
local KEYS: Pose.Keys = {
	Neck = {
		{ 0, 0, 0, 0 }, { 0.35, 14, 0, 0 }, { 0.6, 32, 0, 0 }, { 0.85, 30, 0, 0 }, { 1.2, 8, 0, 0 }, { 3.9, 8, 0, 0 },
		{ 4.1, -10, 30, 0 }, { 4.4, -10, 30, 0 }, { 4.55, 0, -15, 0 }, { 4.75, -10, -30, 0 }, { 5.1, -10, -30, 0 },
		{ 5.25, 0, 15, 0 }, { 5.6, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	Waist = {
		{ 0, 0, 0, 0 }, { 0.6, 15, 0, 0 }, { 0.9, 15, 0, 0 }, { 1.3, 12, 0, 0 }, { 3.9, 12, 0, 0 }, { 4.1, 0, -6, 0 },
		{ 4.55, 0, 4, 0 }, { 4.75, 0, 6, 0 }, { 5.25, 0, -4, 0 }, { 5.6, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	RightShoulder = {
		{ 0, 0, 0, 0 }, { 0.4, 108, 69, -20 }, { 0.85, 108, 69, -20 }, { 1.3, 94, 53, 66 }, { 3.9, 94, 53, 66 },
		{ 4.1, 26, 116, 12 }, { 4.38, 26, 116, 12 }, { 4.5, 51, 12, 63 }, { 4.68, 51, 12, 63 }, { 4.8, 0, 0, 8 },
		{ 5.45, 0, 0, 8 }, { 5.7, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	RightElbow = {
		{ 0, 0, 0, 0 }, { 0.4, 79, 0, 0 }, { 0.85, 79, 0, 0 }, { 1.3, 77, 0, 0 }, { 3.9, 77, 0, 0 }, { 4.1, 77, 0, 0 },
		{ 4.38, 77, 0, 0 }, { 4.5, 0, 0, 0 }, { 4.68, 0, 0, 0 }, { 4.8, 10, 0, 0 }, { 5.45, 10, 0, 0 },
		{ 5.7, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	RightWrist = { { 0, 0, 0, 0 }, { 0.4, -3, -90, -5 }, { 0.85, -3, -90, -5 }, { 1.3, 0, 0, 0 }, { 6, 0, 0, 0 } },
	LeftShoulder = {
		{ 0, 0, 0, 0 }, { 0.4, 0, 0, -10 }, { 0.85, 0, 0, -10 }, { 1.3, 90, -47, -71 }, { 3.9, 90, -47, -71 },
		{ 4.1, 0, 0, -8 }, { 4.6, 0, 0, -8 }, { 4.8, 26, -116, -12 }, { 5.08, 26, -116, -12 }, { 5.2, 51, -12, -63 },
		{ 5.38, 51, -12, -63 }, { 5.7, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	LeftElbow = {
		{ 0, 0, 0, 0 }, { 0.4, 10, 0, 0 }, { 0.85, 10, 0, 0 }, { 1.3, 84, 0, 0 }, { 3.9, 84, 0, 0 }, { 4.1, 10, 0, 0 },
		{ 4.6, 10, 0, 0 }, { 4.8, 77, 0, 0 }, { 5.08, 77, 0, 0 }, { 5.2, 0, 0, 0 }, { 5.38, 0, 0, 0 },
		{ 5.7, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
}

local function wave(t: number, from: number, to: number, hz: number): number
	if t < from or t > to then
		return 0
	end
	local fade = math.sin(math.pi * (t - from) / (to - from))
	return math.sin((t - from) * hz * math.pi * 2) * fade
end

-- Small touches on top of the keys: the yawn's head shake, a slow relaxed sway with the hands behind the head, and
-- quick brush strokes on each shoulder.
local function extra(t: number): { [string]: CFrame }
	local yawn = wave(t, 0.5, 1.0, 2.5)
	local sway = wave(t, 1.4, 3.9, 0.4)
	local brushR = wave(t, 4.12, 4.38, 5)
	local brushL = wave(t, 4.82, 5.08, 5)
	return {
		Neck = CFrame.Angles(0, math.rad(4 * sway), math.rad(3 * yawn)),
		Waist = CFrame.Angles(0, math.rad(5 * sway), 0),
		RightElbow = CFrame.Angles(math.rad(15 * brushR), 0, 0),
		LeftElbow = CFrame.Angles(math.rad(15 * brushL), 0, 0),
	}
end

return function(character: Model, parent: Instance, _skinId: string): number
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if head and torso and root then
		local fx = Effects.session(character, parent, DURATION)
		local s = head.Size.Y / 1.2 -- effects scale with the avatar
		local up, right, forward = Vector3.yAxis, root.CFrame.RightVector, root.CFrame.LookVector
		-- A little cartoon breath puff out of the yawning mouth.
		local mouth = (head.CFrame * CFrame.new(0, -0.15 * s, -0.75 * s)).Position + up * 0.25 * s
		Effects.puff(fx, mouth, (forward * 0.5 + up * 0.8) * s, 0.28 * s, 0.75, 0.5)
		Effects.puff(fx, mouth + up * 0.05, (forward * 0.35 + up * 1.0) * s, 0.2 * s, 0.7, 0.62)
		-- Dust: each brush knocks puffs off the shoulder, then a trail of puffs follows the flicking hand outward (spawned
		-- at the hand's live position, so the dust visibly follows the brush).
		local rightHand = character:FindFirstChild("RightHand") :: BasePart?
		local leftHand = character:FindFirstChild("LeftHand") :: BasePart?
		type Dust = { at: number, from: () -> Vector3, velocity: Vector3, size: number, spawned: boolean? }
		local dust: { Dust } = {}
		local function shoulder(side: number): () -> Vector3
			return function()
				return (torso.CFrame * CFrame.new(side * torso.Size.X * 0.42, torso.Size.Y * 0.38, -0.1)).Position
			end
		end
		local function hand(part: BasePart?): () -> Vector3
			return function()
				return if part then part.Position else torso.Position
			end
		end
		for _, b in
			{
				{ from = 4.14, side = -1, hand = rightHand, dir = 1 },
				{ from = 4.84, side = 1, hand = leftHand, dir = -1 },
			}
		do
			for i = 0, 2 do -- brush strokes on the shoulder
				table.insert(dust, {
					at = b.from + i * 0.08,
					from = shoulder(b.side),
					velocity = (right * b.dir * 1.2 + up * (0.5 + i * 0.25) + forward * 0.5) * s,
					size = 0.32 * s,
				})
			end
			for i = 0, 4 do -- the flick: puffs strung along the hand's path, drifting outward
				table.insert(dust, {
					at = b.from + 0.26 + i * 0.05,
					from = hand(b.hand),
					velocity = (right * b.dir * 1.8 + up * 0.4) * s,
					size = (0.36 - i * 0.03) * s,
				})
			end
		end
		fx.every(function(t)
			for _, d in dust do
				if not d.spawned and t >= d.at then
					d.spawned = true
					Effects.puff(fx, d.from(), d.velocity, d.size, 0.6, t)
				end
			end
		end)
		-- A bold "EZ" pops up beside and above the head during the final brush, gone before the end.
		local ez = Effects.text(fx, "EZ", {
			color = Color3.fromRGB(255, 214, 46),
			stroke = Color3.fromRGB(96, 44, 12),
			strokeThickness = 3,
			glow = Color3.fromRGB(255, 160, 40),
			rotation = -8,
			widthRatio = 1.7,
		})
		-- 5.5x the earlier small EZ, shown for the final brush (left hand on the right shoulder 4.8, flick 5.2), centred
		-- above and out to the side far enough that the avatar stays in view.
		local EZ_HEIGHT = 7.15 * s -- 1.3x the 5.5 of the previous pass
		local EZ_FROM, EZ_TO = 4.78, 5.58
		fx.every(function(t)
			local pos = head.Position
				+ up * (EZ_HEIGHT * 0.5 + 0.9 * s)
				- right * (EZ_HEIGHT * 1.7 * 0.5 + head.Size.X * 0.5 + 0.4 * s)
			if t < EZ_FROM or t > EZ_TO then
				ez.place(pos, 0.01, 1)
				return
			end
			local pop = if t < EZ_FROM + 0.15
				then (t - EZ_FROM) / 0.15 * 1.12
				elseif t < EZ_FROM + 0.25 then 1.12 - (t - EZ_FROM - 0.15) / 0.1 * 0.12
				else 1
			ez.place(
				pos + up * 0.4 * s * math.clamp((t - EZ_FROM) / 0.8, 0, 1),
				EZ_HEIGHT * pop,
				math.clamp((t - (EZ_TO - 0.25)) / 0.25, 0, 1)
			)
		end)
	end
	Pose.run(character, DURATION, KEYS, extra)
	return DURATION
end
