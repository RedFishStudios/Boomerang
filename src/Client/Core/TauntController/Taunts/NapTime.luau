-- "Nap Time" taunt, 6 seconds, R15, with a reclining beach chair (Props.deckChair: wooden folding frame, blue-and-
-- white striped sling, a long backrest that carries the back and head) and a blue "Zzz" trail. Purely cosmetic.
--   0.0-1.2  The chair appears behind the character; they lower into the seat and recline into the sleeping pose:
--            hips in the seat, torso lying back against the backrest, head resting back, legs stretched forward with
--            the knees slightly bent and the heels on the ground, left hand on the stomach, right hand beside the body.
--   1.2-4.7  Held, eyes closed, breathing gently; big bright-blue "z z Z" letters (small to about a head tall, thin white
--            outline, soft glow, camera-facing) float up and out from beside the head, outside the body's outline.
--   4.7-5.2  The Zzz stop and the eyes open; a small head movement as they wake, and they lean forward.
--   5.2-6.0  They stand up and return to idle; the chair fades once they're clear of it.
--
-- Fit: the chair is scaled to the character's height. The seated body is placed through the Root joint (the
-- HumanoidRootPart itself never moves): pelvis in the seat's sag and the torso at the backrest's 55-degree slope, just
-- in front of the fabric. Legs and arms were solved against an R15 rig so the heels reach the ground and the hands land
-- on the stomach and beside the hip.

local Pose = require(script.Parent:WaitForChild("Pose"))
local Props = require(script.Parent:WaitForChild("Props"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local DURATION = 6
-- Seated pelvis (LowerTorso centre) in chair space for a 5-stud character: (height, back), just above the seat's sag.
local PELVIS = Vector2.new(0.62, 1.15)
local SIT, SLEEP, WAKE = 15, Props.BACKREST_RECLINE, -5 -- torso tilt back, degrees
local ZZZ_FROM, ZZZ_TO, ZZZ_EVERY, ZZZ_GAP, ZZZ_LIFE = 1.4, 4.7, 1.2, 0.35, 1.7
-- Each group: small, medium, big (sizes are fractions of the head's height; the big Z is about a head tall).
-- Sizes are 5.5x the earlier small Zzz so they read at gameplay zoom (the big Z is about 6.6 studs for a 1.2-stud head).
local ZZZ_SCALE = 7.15 -- 1.3x the previous 5.5
local ZZZ_STEPS = {
	{ text = "z", size = 0.45 * ZZZ_SCALE },
	{ text = "z", size = 0.7 * ZZZ_SCALE },
	{ text = "Z", size = 1.0 * ZZZ_SCALE },
}
local ZZZ_BLUE = Color3.fromRGB(30, 144, 255)
local ZZZ_GLOW = Color3.fromRGB(130, 200, 255)

-- The legs' keys end at 5.2 (seated, about to stand): from there leg IK (below) keeps the feet on the ground while
-- the body rises.
-- stylua: ignore
local KEYS: Pose.Keys = {
	RightHip = {
		{ 0, 0, 0, 0 }, { 0.15, 0, 0, 0 }, { 0.5, 50, 5, 0 }, { 0.8, 92, 11, 0 }, { 1.2, 36, 13, 3 }, { 4.7, 36, 13, 3 },
		{ 5.0, 113, 8, 2 }, { 5.2, 113, 8, 2 },
	},
	LeftHip = {
		{ 0, 0, 0, 0 }, { 0.15, 0, 0, 0 }, { 0.5, 50, -5, 0 }, { 0.8, 92, -11, 0 }, { 1.2, 36, -13, -3 },
		{ 4.7, 36, -13, -3 }, { 5.0, 113, -9, -1 }, { 5.2, 113, -9, -1 },
	},
	RightKnee = {
		{ 0, 0, 0, 0 }, { 0.15, 0, 0, 0 }, { 0.5, -50, 0, 0 }, { 0.8, -83, 0, 0 }, { 1.2, -30, 0, 0 }, { 4.7, -30, 0, 0 },
		{ 5.0, -89, 0, 0 }, { 5.2, -89, 0, 0 },
	},
	LeftKnee = {
		{ 0, 0, 0, 0 }, { 0.15, 0, 0, 0 }, { 0.5, -50, 0, 0 }, { 0.8, -83, 0, 0 }, { 1.2, -30, 0, 0 }, { 4.7, -30, 0, 0 },
		{ 5.0, -89, 0, 0 }, { 5.2, -89, 0, 0 },
	},
	RightShoulder = {
		{ 0, 0, 0, 0 }, { 0.4, -35, 12, 15 }, { 0.8, -80, 28, 19 }, { 1.2, -99, 27, 37 }, { 4.7, -99, 27, 37 },
		{ 5.0, -80, 28, 19 }, { 5.3, -80, 28, 19 }, { 5.75, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	RightElbow = {
		{ 0, 0, 0, 0 }, { 0.4, 35, 0, 0 }, { 0.8, 86, 0, 0 }, { 1.2, 83, 0, 0 }, { 4.7, 83, 0, 0 }, { 5.0, 86, 0, 0 },
		{ 5.3, 86, 0, 0 }, { 5.75, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	LeftShoulder = {
		{ 0, 0, 0, 0 }, { 0.4, -35, -12, -15 }, { 0.8, -79, -28, -18 }, { 1.2, 10, -132, 70 }, { 4.7, 10, -132, 70 },
		{ 5.0, -79, -28, -18 }, { 5.3, -79, -28, -18 }, { 5.75, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	LeftElbow = {
		{ 0, 0, 0, 0 }, { 0.4, 35, 0, 0 }, { 0.8, 86, 0, 0 }, { 1.2, 148, 0, 0 }, { 4.7, 148, 0, 0 }, { 5.0, 86, 0, 0 },
		{ 5.3, 86, 0, 0 }, { 5.75, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	-- Glance down while sitting, head resting back on the chair's pillow while asleep (tipped forward just enough to sit
	-- on it rather than on the fabric), a small look round on waking.
	Neck = {
		{ 0, 0, 0, 0 }, { 0.5, -10, 0, 0 }, { 1.2, -28, 0, 0 }, { 4.7, -28, 0, 0 }, { 4.85, -10, 18, 0 }, { 5.05, -6, -12, 0 },
		{ 5.25, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	Waist = {
		{ 0, 0, 0, 0 }, { 0.5, -8, 0, 0 }, { 1.2, 0, 0, 0 }, { 4.7, 0, 0, 0 }, { 4.95, -12, 0, 0 }, { 5.2, -8, 0, 0 },
		{ 5.75, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

return function(character: Model, parent: Instance, _skinId: string): number
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	local joints = Pose.joints(character)
	local rootJoint = joints.Root :: any
	if not (root and rootJoint and head) then
		return 0
	end
	-- Ground, height and the chair's frame (on the ground under the root part, facing where the character faces).
	local ground = math.huge
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			ground = math.min(ground, p.Position.Y - p.Size.Y / 2)
		end
	end
	local s = math.clamp((head.Position.Y + head.Size.Y / 2 - ground) / 5, 0.5, 2.5)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local base = Vector3.new(root.Position.X, ground, root.Position.Z)
	local chairCF = CFrame.lookAt(base, base + look)
	local hrpH = root.Position.Y - ground

	-- The Root joint transform that puts the pelvis in the seat, tilted back by `recline` degrees.
	local a0: CFrame, a1: CFrame
	if rootJoint:IsA("Motor6D") then
		a0, a1 = rootJoint.C0, rootJoint.C1
	else
		a0, a1 = rootJoint.Attachment0.CFrame, rootJoint.Attachment1.CFrame
	end
	local function seated(recline: number): CFrame
		local want = CFrame.new(0, PELVIS.X * s - hrpH, PELVIS.Y * s) * CFrame.Angles(math.rad(recline), 0, 0)
		return a0:Inverse() * want * a1
	end
	local sit, sleep, wake = seated(SIT), seated(SLEEP), seated(WAKE)
	local standing = CFrame.new()
	local function rootAt(t: number): CFrame
		if t < 0.15 then
			return standing
		elseif t < 0.8 then
			return standing:Lerp(sit, smooth((t - 0.15) / 0.65))
		elseif t < 1.2 then
			return sit:Lerp(sleep, smooth((t - 0.8) / 0.4))
		elseif t < 4.7 then
			-- Slow, gentle breathing: the chest rises and falls a little.
			return sleep * CFrame.Angles(math.rad(-1.4 * math.sin((t - 1.2) * 2.2)), 0, 0)
		elseif t < 5.2 then
			return sleep:Lerp(wake, smooth((t - 4.7) / 0.5))
		end
		return wake:Lerp(standing, smooth((t - 5.2) / 0.55))
	end

	local fx = Effects.session(character, parent, DURATION)
	local chair = Props.deckChair(parent)
	fx.add(chair.model)
	local right = root.CFrame.RightVector * Vector3.new(1, 0, 1)
	right = if right.Magnitude > 0.01 then right.Unit else Vector3.new(1, 0, 0)
	local setEyes = Effects.eyes(fx, character)

	-- Zzz: groups of three letters - small "z", medium "z", big "Z" (about a head tall) - a beat apart, beside the head
	-- and outside the body's outline, each drifting up and out, growing a little, then fading.
	type Z = { text: Effects.Text, born: number, size: number }
	local zs: { Z } = {}
	local born = ZZZ_FROM
	while born < ZZZ_TO do
		for i, step in ZZZ_STEPS do
			local at = born + (i - 1) * ZZZ_GAP
			if at < ZZZ_TO then
				local text = Effects.text(fx, step.text, {
					color = ZZZ_BLUE,
					stroke = Color3.new(1, 1, 1),
					strokeThickness = 1.5,
					glow = ZZZ_GLOW,
					rotation = 10,
				})
				text.place(head.Position, 0, 1)
				table.insert(zs, { text = text, born = at, size = step.size * head.Size.Y })
			end
		end
		born += ZZZ_EVERY
	end

	fx.every(function(t)
		-- The chair pops in behind them (0-0.3) and fades once they've stood clear (5.7-5.95).
		chair.place(chairCF, s * (0.7 + 0.3 * smooth(t / 0.3)))
		chair.setFade(math.max(1 - smooth(t / 0.2), smooth((t - 5.7) / 0.25)))
		-- Eyes close as they settle into sleep and open again when they wake.
		setEyes(if t > 1.0 and t < 4.75 then 1 else 0)
		for _, z in zs do
			local u = (t - z.born) / ZZZ_LIFE
			if u < 0 or u > 1 then
				z.text.place(head.Position, 0.01, 1)
			else
				-- Above and beside the sleeper, far enough out that even the big Z (centred half its width away) leaves the
				-- avatar in view.
				local half = z.size * 0.5
				local from = head.Position
					+ right * (head.Size.X * 0.5 + half + 0.4 * s)
					+ Vector3.new(0, half * 0.6 + 0.6 * s, 0)
				local sway = math.sin(u * math.pi * 2) * 0.3 * s
				local pos = from + Vector3.new(0, 3.2 * s * u, 0) + right * (1.8 * s * u + sway)
				z.text.place(pos, z.size * (0.8 + 0.25 * smooth(u * 2)), smooth((u - 0.6) / 0.4))
			end
		end
	end)

	-- Leg IK for standing up (5.2-5.75): each ankle glides from where it is when seated back to where it stood before
	-- the taunt, and the hip and knee are solved every frame from the rising pelvis (two-bone IK, knee forward), so the
	-- feet stay on the ground instead of dipping through it while the body rises.
	local function pivotLocal(j: any): CFrame
		return if j:IsA("Motor6D") then j.C0 else j.Attachment0.CFrame
	end
	local function pivotWorld(j: any): Vector3
		return if j:IsA("Motor6D") then (j.Part0.CFrame * j.C0).Position else j.Attachment0.WorldPosition
	end
	type Leg = { side: string, hip: any, knee: any, ankle: any, l1: number, l2: number, stand: Vector3, from: Vector3? }
	local legs: { Leg } = {}
	for _, side in { "Right", "Left" } do
		local hip, knee, ankle = joints[side .. "Hip"], joints[side .. "Knee"], joints[side .. "Ankle"]
		if hip and knee and ankle then
			table.insert(legs, {
				side = side,
				hip = hip,
				knee = knee,
				ankle = ankle,
				l1 = (pivotWorld(hip) - pivotWorld(knee)).Magnitude,
				l2 = (pivotWorld(knee) - pivotWorld(ankle)).Magnitude,
				stand = pivotWorld(ankle),
			})
		end
	end
	local function legIK(t: number, out: { [string]: CFrame })
		local pelvis = root.CFrame * a0 * rootAt(t) * a1:Inverse()
		local u = smooth((t - 5.2) / 0.55)
		for _, leg in legs do
			leg.from = leg.from or pivotWorld(leg.ankle)
			local glide = (leg.from :: Vector3):Lerp(leg.stand, u)
			-- Never below the height the ankle stands at, so the foot glides along the ground rather than into it.
			local target = Vector3.new(glide.X, math.max(glide.Y, leg.stand.Y), glide.Z)
			local hipFrame = pelvis * pivotLocal(leg.hip)
			local v = target - hipFrame.Position
			local d = math.clamp(v.Magnitude, 0.05, leg.l1 + leg.l2 - 0.001)
			local alpha = math.acos(math.clamp((leg.l1 ^ 2 + d ^ 2 - leg.l2 ^ 2) / (2 * leg.l1 * d), -1, 1))
			local thigh = CFrame.fromAxisAngle(pelvis.RightVector, alpha):VectorToWorldSpace(v.Unit)
			local local_ = hipFrame:VectorToObjectSpace(thigh)
			local hipAngle = math.atan2(-local_.Z, -local_.Y)
			local interior = math.acos(math.clamp((leg.l1 ^ 2 + leg.l2 ^ 2 - d ^ 2) / (2 * leg.l1 * leg.l2), -1, 1))
			-- Pose.run multiplies extras onto the keys, so give the difference from the last seated key.
			local hipKey = Pose.sample(KEYS[leg.side .. "Hip"], t)
			local kneeKey = Pose.sample(KEYS[leg.side .. "Knee"], t)
			out[leg.side .. "Hip"] = hipKey:Inverse() * CFrame.Angles(hipAngle, 0, 0)
			out[leg.side .. "Knee"] = kneeKey:Inverse() * CFrame.Angles(-(math.pi - interior), 0, 0)
		end
	end

	Pose.run(character, DURATION, KEYS, function(t)
		local out = { Root = rootAt(t) }
		if t >= 5.2 then
			legIK(t, out)
		end
		return out
	end, nil, string.format("NapTime_%.2f_%.2f", s, hrpH)) -- // The seat pose depends on the avatar's size
	return DURATION
end
