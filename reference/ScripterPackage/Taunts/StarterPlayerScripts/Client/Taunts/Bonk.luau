-- "Bonk!" taunt, 6 seconds, R15, with a cosmetic copy of the player's equipped boomerang (its Inventory art, design and
-- colours unchanged, on a thin card; anchored, no collision, no damage). A confident trick that comically goes wrong.
--   0.0-1.2  Twirls the boomerang in the right hand, then flicks it up and away.
--   1.2-2.6  It flies a short, clearly visible curve out to the front-right and back (flat, so it reads from above).
--   2.6      It bonks the forehead - just outside the head, never inside it - and the head snaps back on that frame.
--   2.6-3.5  The character wobbles and takes one small balancing step in place; the boomerang pops off the head and
--            drops into the waiting left hand.
--   3.5-5.0  Rubs the forehead with the free right hand, head down, embarrassed.
--   5.0-6.0  Straightens up, glances left and right as if nothing happened, and returns to idle.
-- Effects: a short restrained motion trail while it flies, a cartoon impact burst on the contact frame, and three
-- yellow stars circling above the head (2.65-5.0) through the wobble and the rub.

local Pose = require(script.Parent:WaitForChild("Pose"))
local Props = require(script.Parent:WaitForChild("Props"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local DURATION = 6
local RELEASE, CONTACT, CATCH = 1.2, 2.6, 3.3
local STARS_FROM, STARS_TO = 2.65, 5.0 -- dizzy stars: through the wobble and the forehead rub

-- stylua: ignore
local KEYS: Pose.Keys = {
	RightShoulder = {
		{ 0, 0, 0, 0 }, { 0.25, 10, 16, 9 }, { 1.0, 10, 16, 9 }, { 1.15, 76, 68, 55 }, { 1.4, 40, 60, 40 },
		{ 1.8, 10, 20, 10 }, { 2.6, 5, 10, 5 }, { 2.9, 5, 10, 18 }, { 3.5, 20, 30, 20 }, { 3.7, 53, 71, 53 },
		{ 4.9, 53, 71, 53 }, { 5.2, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	RightElbow = {
		{ 0, 0, 0, 0 }, { 0.25, 72, 0, 0 }, { 1.0, 72, 0, 0 }, { 1.15, 0, 0, 0 }, { 1.4, 10, 0, 0 }, { 1.8, 20, 0, 0 },
		{ 2.6, 20, 0, 0 }, { 2.9, 30, 0, 0 }, { 3.5, 40, 0, 0 }, { 3.7, 54, 0, 0 }, { 4.9, 54, 0, 0 },
		{ 5.2, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	RightWrist = {
		{ 0, 0, 0, 0 }, { 3.5, 0, 0, 0 }, { 3.7, 20, -90, -30 }, { 4.9, 20, -90, -30 }, { 5.2, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	LeftShoulder = {
		{ 0, 0, 0, 0 }, { 1.0, 0, 0, -8 }, { 2.0, 0, 0, -8 }, { 2.3, 0, -54, 12 }, { 2.6, 0, -54, 12 },
		{ 2.85, 10, -40, -25 }, { 3.15, 0, -54, 12 }, { 3.5, 0, -54, 12 }, { 4.9, 0, -40, 8 }, { 5.3, 0, -15, 0 },
		{ 6, 0, 0, 0 },
	},
	LeftElbow = {
		{ 0, 0, 0, 0 }, { 2.3, 70, 0, 0 }, { 2.6, 70, 0, 0 }, { 2.85, 40, 0, 0 }, { 3.15, 70, 0, 0 },
		{ 4.9, 70, 0, 0 }, { 5.3, 20, 0, 0 }, { 6, 0, 0, 0 },
	},
	Neck = {
		{ 0, 0, 0, 0 }, { 0.3, -12, 10, 0 }, { 1.0, -12, 10, 0 }, { 1.2, 15, -10, 0 }, { 1.6, 10, -28, 0 },
		{ 2.1, 8, 12, 0 }, { 2.5, 2, 0, 0 }, { 2.6, 2, 0, 0 }, { 2.68, 42, 0, 10 }, { 2.9, 24, 0, -9 },
		{ 3.1, 10, 0, 5 }, { 3.5, -12, 0, 0 }, { 4.9, -14, 8, 0 }, { 5.2, 0, 0, 0 }, { 5.45, 0, 40, 0 },
		{ 5.75, 0, -40, 0 }, { 6, 0, 0, 0 },
	},
	Waist = {
		{ 0, 0, 0, 0 }, { 1.0, 0, 10, 0 }, { 1.2, -4, -8, 0 }, { 2.6, 0, 0, 0 }, { 2.68, 18, 0, 0 },
		{ 2.85, 8, 0, 13 }, { 3.05, 5, 0, -13 }, { 3.25, 2, 0, 8 }, { 3.5, -6, 0, 0 }, { 4.9, -8, 0, 0 },
		{ 5.2, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	-- One small balancing step in place with the right foot.
	RightHip = { { 0, 0, 0, 0 }, { 2.75, 0, 0, 0 }, { 2.92, 40, 0, 0 }, { 3.1, 8, 0, 0 }, { 3.22, 0, 0, 0 }, { 6, 0, 0, 0 } },
	RightKnee = { { 0, 0, 0, 0 }, { 2.75, 0, 0, 0 }, { 2.92, -65, 0, 0 }, { 3.1, -10, 0, 0 }, { 3.22, 0, 0, 0 }, { 6, 0, 0, 0 } },
}

local function extra(t: number): { [string]: CFrame }
	-- Rubbing the forehead: small side-to-side circles.
	local rub = if t > 3.75 and t < 4.85 then math.sin((t - 3.75) * math.pi * 2 * 3) else 0
	return {
		RightShoulder = CFrame.Angles(0, math.rad(7 * rub), math.rad(4 * rub)),
	}
end

local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: number): Vector3
	local v = 1 - u
	return p0 * v * v * v + p1 * 3 * v * v * u + p2 * 3 * v * u * u + p3 * u * u * u
end

return function(character: Model, parent: Instance, skinId: string): number
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rightHand = character:FindFirstChild("RightHand") :: BasePart?
	local leftHand = character:FindFirstChild("LeftHand") :: BasePart?
	if not (head and root and rightHand and leftHand) then
		return 0
	end
	-- About twice the earlier size, so it reads from the zoomed-out camera.
	local size = math.clamp(head.Size.X * 2.5, 2.4, 4.4)
	local fx = Effects.session(character, parent, DURATION)
	local prop = Props.boomerang(parent, skinId, size)
	fx.add(prop.part)
	local rootCF = root.CFrame
	local releasePos: Vector3? = nil
	local contactCF: CFrame? = nil

	-- Where it touches the forehead: in front of the face, its flat side towards the head, so the card stays fully
	-- outside the head (half its thickness plus a small gap clear of the head's front face).
	local function contact(): CFrame
		local front = head.Size.Z / 2 + 0.05
		return head.CFrame * CFrame.new(0, head.Size.Y * 0.2, -front)
	end

	-- A short, restrained motion trail behind the boomerang, on only while it flies, so the curved return reads.
	local trailA = Instance.new("Attachment")
	trailA.Position = Vector3.new(-size * 0.3, 0, 0)
	trailA.Parent = prop.part
	local trailB = Instance.new("Attachment")
	trailB.Position = Vector3.new(size * 0.3, 0, 0)
	trailB.Parent = prop.part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = trailA, trailB
	trail.Lifetime = 0.22
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.3
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 225, 255))
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Enabled = false
	trail.Parent = prop.part

	-- The bonk: a cartoon impact burst at the forehead on the contact frame, then three yellow stars circling the head
	-- while they wobble and rub it, fading as they recover.
	Effects.burst(fx, function()
		return contact().Position + head.CFrame.LookVector * 0.2
	end, 3.2 * head.Size.Y, CONTACT)
	local stars: { Effects.Text } = {}
	for _ = 1, 3 do
		table.insert(
			stars,
			Effects.text(fx, "\u{2605}", {
				color = Color3.fromRGB(255, 222, 40),
				stroke = Color3.fromRGB(200, 110, 20),
				strokeThickness = 1.5,
				glow = Color3.fromRGB(255, 240, 150),
			})
		)
	end

	fx.every(function(t)
		trail.Enabled = t >= RELEASE and t < CONTACT
		for i, star in stars do
			if t < STARS_FROM or t > STARS_TO then
				star.place(head.Position, 0.01, 1)
			else
				-- A tilted ring above the head (reads from overhead and the side), 1.1 turns a second.
				local a = (t - STARS_FROM) * math.pi * 2 * 1.1 + (i - 1) * math.pi * 2 / 3
				local r = head.Size.X * 1.25
				local ring = Vector3.new(math.cos(a) * r, head.Size.Y * 1.0 + math.sin(a * 2) * 0.15, math.sin(a) * r)
				local grow = math.clamp((t - STARS_FROM) / 0.15, 0, 1)
				local fade = math.clamp((t - (STARS_TO - 0.35)) / 0.35, 0, 1)
				star.place(head.Position + ring, 1.35 * head.Size.Y * grow, fade)
			end
		end
		local cf: CFrame
		local flatOnHand = rootCF.Rotation * CFrame.Angles(math.rad(-90), 0, 0) -- lying flat, art facing up
		if t < RELEASE then
			-- Twirl: spinning flat in front of the right hand, held at its edge (the big card stays clear of the body),
			-- speeding up into the flick.
			local spin = (t * 2.2 + t * t * 1.5) * math.pi * 2
			local held = rightHand.Position + rootCF.LookVector * size * 0.45 + rootCF.RightVector * size * 0.1
			cf = CFrame.new(held) * flatOnHand * CFrame.Angles(0, 0, spin)
		elseif t < CONTACT then
			-- Flight: a wide, flat, banked loop out to the front-right and back round to the forehead.
			releasePos = releasePos
				or (rightHand.Position + rootCF.LookVector * size * 0.45 + rootCF.RightVector * size * 0.1)
			local target = contact().Position
			local p1 = (rootCF * CFrame.new(10, 6, -13)).Position
			local p2 = (rootCF * CFrame.new(-8, 5.5, -11)).Position
			local u = (t - RELEASE) / (CONTACT - RELEASE)
			local pos = bezier(releasePos :: Vector3, p1, p2, target, u)
			local spin = (t - RELEASE) * math.pi * 2 * 3.2
			local flat = CFrame.Angles(math.rad(-90), 0, 0) * CFrame.Angles(math.rad(25), 0, 0) -- lying flat, banked
			-- Turn to face the head as it arrives so it lands flat-side on.
			local arrive = math.clamp((u - 0.8) / 0.2, 0, 1)
			local spinning = CFrame.new(pos) * rootCF.Rotation * flat * CFrame.Angles(0, 0, spin)
			local onHead = CFrame.new(pos) * head.CFrame.Rotation * CFrame.Angles(0, 0, spin)
			cf = spinning:Lerp(onHead, arrive)
		elseif t < CATCH then
			-- Pops off the forehead and drops onto the waiting left hand.
			contactCF = contactCF or contact()
			local u = (t - CONTACT) / (CATCH - CONTACT)
			local catchCF = CFrame.new(leftHand.Position + rootCF.LookVector * size * 0.45 + Vector3.new(0, 0.12, 0))
				* flatOnHand
			local from = (contactCF :: CFrame).Position
			local pos = from:Lerp(catchCF.Position, u) + Vector3.new(0, 2.2 * u * (1 - u), 0)
			cf = CFrame.new(pos)
				* (contactCF :: CFrame).Rotation:Lerp(catchCF.Rotation, u)
				* CFrame.Angles(0, 0, u * math.pi * 2)
		else
			-- Resting on the left hand, held at its edge; fades out at the very end.
			cf = CFrame.new(leftHand.Position + rootCF.LookVector * size * 0.45 + Vector3.new(0, 0.12, 0)) * flatOnHand
			prop.setFade(math.clamp((t - 5.55) / 0.4, 0, 1))
		end
		prop.part.CFrame = cf
	end)

	Pose.run(character, DURATION, KEYS, extra)
	return DURATION
end
