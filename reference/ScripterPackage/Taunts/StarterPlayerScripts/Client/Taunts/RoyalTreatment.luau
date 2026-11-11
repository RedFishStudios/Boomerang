-- "Royal Treatment" taunt, 6 seconds, R15, with a comically oversized chunky gold crown, about 2.7x the head's width
-- (Props.crown: five softly rounded points, one red front gem, a thick rounded lower rim and a solid bottom plate with a
-- shallow recess underneath; purely cosmetic), then a golden "admire me" pose.
--   0.0-1.0  The crown is held out in front, tilted 90 degrees with its open top facing forward, arms extended, hands
--            gripping the rim's lower-left and lower-right edges (about 5 and 7 o'clock).
--   1.0-2.5  Lifted (still tilted) until its lowest edge is above the head; once clear, it's turned upright in front of
--            the face - the hands sliding round the rim to its near edge - raised to hair height, carried back over the
--            head and set gently on top of the head and hair.
--   2.5-5.5  The crown stays on; arms spread wide at shoulder height, elbows slightly bent, palms up, chest and chin
--            lifted. The character shines: a bright gold outline and soft gold aura (a Highlight, so the outfit stays
--            visible), gold sparkles round the body and bursts of outward shine rays.
--   5.5-6.0  The gold fades, the crown fades, the arms come down and it returns to idle.
-- The crown is placed from the hands every frame while it's held, so they stay on its rim. The rim is out of easy reach
-- at the very top of the lift (the crown is 3+ studs wide): there the hands may sit up to ~0.25 studs short of it.

local Pose = require(script.Parent:WaitForChild("Pose"))
local Props = require(script.Parent:WaitForChild("Props"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local DURATION = 6
local CROWN_WIDTH = 2.7 -- times the head's width: deliberately, comically oversized
local TURN_FROM, TURN_TO = 1.5, 1.95 -- turning upright (once the lift has cleared the head)
local RAISE_FROM, SETTLE_FROM, SETTLE_TO = 2.0, 2.15, 2.4 -- raised clear of the hair, then set down on it
local SHINE_FROM, SHINE_TO = 2.5, 5.5
local GOLD = Color3.fromRGB(255, 205, 60)
local GOLD_LIGHT = Color3.fromRGB(255, 236, 150)

-- stylua: ignore
local KEYS: Pose.Keys = {
	RightShoulder = {
		{ 0, 0, 0, 0 }, { 0.3, -6, 44, 18 }, { 1.0, -6, 44, 18 }, { 1.5, 114, 62, -2 }, { 1.95, 114, 62, -2 }, { 2.15, 116, 63, -2 },
		{ 2.4, 89, 54, 60 }, { 2.5, 89, 54, 60 }, { 2.8, 145, -16, 39 }, { 5.5, 145, -16, 39 }, { 5.85, 0, 0, 0 },
		{ 6, 0, 0, 0 },
	},
	RightElbow = {
		{ 0, 0, 0, 0 }, { 0.3, 57, 0, 0 }, { 1.0, 57, 0, 0 }, { 1.5, 0, 0, 0 }, { 1.95, 0, 0, 0 }, { 2.5, 0, 0, 0 },
		{ 2.8, 8, 0, 0 }, { 5.5, 8, 0, 0 }, { 5.85, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	RightWrist = { { 0, 0, 0, 0 }, { 2.5, 0, 0, 0 }, { 2.8, -8, -26, 33 }, { 5.5, -8, -26, 33 }, { 5.85, 0, 0, 0 }, { 6, 0, 0, 0 } },
	LeftShoulder = {
		{ 0, 0, 0, 0 }, { 0.3, -6, -44, -17 }, { 1.0, -6, -44, -17 }, { 1.5, 114, -62, 2 }, { 1.95, 114, -62, 2 }, { 2.15, 116, -63, 2 },
		{ 2.4, 89, -54, -60 }, { 2.5, 89, -54, -60 }, { 2.8, 146, 16, -39 }, { 5.5, 146, 16, -39 }, { 5.85, 0, 0, 0 },
		{ 6, 0, 0, 0 },
	},
	LeftElbow = {
		{ 0, 0, 0, 0 }, { 0.3, 57, 0, 0 }, { 1.0, 57, 0, 0 }, { 1.5, 0, 0, 0 }, { 1.95, 0, 0, 0 }, { 2.5, 0, 0, 0 },
		{ 2.8, 8, 0, 0 }, { 5.5, 8, 0, 0 }, { 5.85, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	LeftWrist = { { 0, 0, 0, 0 }, { 2.5, 0, 0, 0 }, { 2.8, -11, 26, -30 }, { 5.5, -11, 26, -30 }, { 5.85, 0, 0, 0 }, { 6, 0, 0, 0 } },
	Neck = {
		{ 0, 0, 0, 0 }, { 0.3, -8, 0, 0 }, { 1.0, -8, 0, 0 }, { 1.5, 24, 0, 0 }, { 2.0, 18, 0, 0 }, { 2.4, 4, 0, 0 },
		{ 2.8, 15, 0, 0 }, { 5.5, 15, 0, 0 }, { 5.85, 0, 0, 0 }, { 6, 0, 0, 0 },
	},
	Waist = {
		{ 0, 0, 0, 0 }, { 1.5, 4, 0, 0 }, { 2.4, 0, 0, 0 }, { 2.8, 11, 0, 0 }, { 5.5, 11, 0, 0 }, { 5.85, 0, 0, 0 },
		{ 6, 0, 0, 0 },
	},
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- A slow golden shimmer while posing: the chest swells a little.
local function extra(t: number): { [string]: CFrame }
	if t < SHINE_FROM or t > SHINE_TO then
		return {}
	end
	return { Waist = CFrame.Angles(math.rad(1.5 * math.sin((t - SHINE_FROM) * 2.4)), 0, 0) }
end

return function(character: Model, parent: Instance, _skinId: string): number
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local rightHand = character:FindFirstChild("RightHand") :: BasePart?
	local leftHand = character:FindFirstChild("LeftHand") :: BasePart?
	if not (head and root and torso and rightHand and leftHand) then
		return 0
	end
	local fx = Effects.session(character, parent, DURATION)
	local s = head.Size.Y / 1.2
	local width = head.Size.X * CROWN_WIDTH
	local crown = Props.crown(parent, width)
	fx.add(crown.model)
	-- Worn on top of the head and hair (no sinking in: the plate is solid), its recess over the crown of the head.
	local wornY = Props.headTop(character, true) + 0.02 * s

	-- While held, the crown hangs from the hands: tilted with its top facing forward and the hands on the rim's lower
	-- edges, then turned upright with the hands sliding round the rim to its near edge.
	local function heldCF(t: number): CFrame
		local right = rightHand.Position - leftHand.Position
		right = if right.Magnitude > 0.05 then right.Unit else root.CFrame.RightVector
		local forward = root.CFrame.LookVector
		local turn = smooth((t - TURN_FROM) / (TURN_TO - TURN_FROM))
		local up = CFrame.fromAxisAngle(right, math.rad(90 * turn)):VectorToWorldSpace(forward)
		-- Grip: the lower edge (5 and 7 o'clock) while tilted, sliding round to the rim's near edge as it turns upright, so
		-- the crown ends up in front of the face rather than over the head.
		-- The grip leads the turn (square root), keeping the crown forward of the head while it rotates.
		local grip = math.rad(-60 + 120 * math.sqrt(turn))
		local z = right:Cross(up)
		local rimCenter = (rightHand.Position + leftHand.Position) / 2 - z * (crown.rimRadius * math.sin(grip))
		return CFrame.fromMatrix(rimCenter - up * crown.rimTube, right, up)
	end

	-- Clearance: while the crown is carried over or in front of the head, lift it just enough that no point of its rim or
	-- plate dips into a column over the head (head footprint, up to the top of the hair).
	local hairTop = Props.headTop(character, true)
	local function clear(cf: CFrame): CFrame
		local ceiling = head.Position.Y + hairTop + 0.08 * s
		local reach = math.max(head.Size.X, head.Size.Z) * 0.5
		local deficit = 0
		-- Rings over the plate (three radii), round the top of the band and through the points' tips.
		for ring = 1, 5 do
			local radius = if ring <= 3 then crown.rimRadius * ring / 3 else crown.rimRadius
			local y = if ring <= 3 then 0 elseif ring == 4 then crown.height else crown.height + 0.36 * width
			for i = 0, 23 do
				local a = i / 24 * math.pi * 2
				local p = (cf * CFrame.new(math.cos(a) * radius, y, math.sin(a) * radius)).Position
				if ((p - head.Position) * Vector3.new(1, 0, 1)).Magnitude < reach then
					deficit = math.max(deficit, ceiling + crown.rimTube - p.Y)
				end
			end
		end
		return cf + Vector3.new(0, deficit, 0)
	end

	-- The golden "admire me" shine: outline and aura (a Highlight over the whole character), a warm light, sparkles
	-- round the body and bursts of outward rays.
	local shine = Instance.new("Highlight")
	shine.Name = "TauntGoldShine"
	shine.Adornee = character
	shine.DepthMode = Enum.HighlightDepthMode.Occluded
	shine.FillColor = GOLD
	shine.OutlineColor = GOLD_LIGHT
	shine.FillTransparency = 1
	shine.OutlineTransparency = 1
	fx.add(shine)
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 10 * s
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = torso
	fx.add(glow)
	-- Strong, readable shine: four bursts of long, thick rays round the posing body.
	for _, at in { 2.55, 3.3, 4.05, 4.8 } do
		Effects.rays(fx, torso.Position + Vector3.new(0, 0.3 * s, 0), 5.2 * s, at, 0.16 * s, 20)
	end
	local SPARKLES = 16
	for i = 0, SPARKLES - 1 do
		local a = i * 2.399963
		local born = SHINE_FROM + 0.1 + i * (2.7 / SPARKLES)
		local height = (i * 0.618 % 1) * 5 - 2.4
		Effects.glint(fx, function()
			local radius = (1.5 + 0.5 * math.sin(i * 1.7)) * s
			return torso.Position + Vector3.new(math.cos(a) * radius, height * s, math.sin(a) * radius)
		end, 0.7 * s, born)
	end

	fx.every(function(t)
		local worn = head.CFrame * CFrame.new(0, wornY, 0)
		-- Setting it on: first straight up (still in front) to the height it will sit at on top of the hair, then back
		-- over the head and down, so the plate never passes through the head or hair. On tall hair the last bit is above
		-- arm's reach, and the hands let go as it settles.
		local cf: CFrame
		if t < RAISE_FROM then
			cf = clear(heldCF(t))
		else
			local held = clear(heldCF(math.min(t, SETTLE_FROM)))
			-- Raised a little above its final height, carried back over the head at that height, then dropped into place.
			local hover = 0.35 * s
			-- Carried to a spot over the head held level (not following the head's tilt yet), then handed to the head.
			local over = CFrame.new(head.Position + Vector3.new(0, wornY, 0)) * root.CFrame.Rotation
			local lift = math.max(0, over.Position.Y + hover - held.Position.Y)
			local raised = held + Vector3.new(0, lift * smooth((t - RAISE_FROM) / (SETTLE_FROM - RAISE_FROM)), 0)
			if t < SETTLE_FROM then
				cf = raised
			elseif t < SETTLE_TO then
				local u = (t - SETTLE_FROM) / (SETTLE_TO - SETTLE_FROM)
				local carried = raised:Lerp(over + Vector3.new(0, hover, 0), smooth(u / 0.6))
				local dropped = carried - Vector3.new(0, hover * smooth((u - 0.6) / 0.3), 0)
				cf = dropped:Lerp(worn, smooth((u - 0.85) / 0.15))
			else
				cf = worn
			end
		end
		crown.place(cf, smooth((t - 0.05) / 0.25)) -- appears in the hands
		local fade = smooth((t - SHINE_TO) / 0.45)
		crown.setFade(fade)
		local on = smooth((t - SHINE_FROM) / 0.25) * (1 - fade)
		shine.FillTransparency = 1 - 0.28 * on -- a soft gold tint: the outfit stays clearly visible
		shine.OutlineTransparency = 1 - on
		glow.Brightness = 1.6 * on
	end)

	Pose.run(character, DURATION, KEYS, extra)
	return DURATION
end
