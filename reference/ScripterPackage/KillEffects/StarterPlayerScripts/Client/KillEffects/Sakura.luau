-- "Sakura" kill effect, exactly 3 seconds.
--   0.00-0.15  The avatar vanishes (soft airy swoosh) and seven solid blossoms appear where it stood.
--   0.15-2.25  They descend slowly along clear falling paths, gently speeding up and tumbling slightly, and land on
--              the real floor below them (each at its own authored moment between 2.05 and 2.25).
--   2.25-2.65  One small bounce and a damped rock, then they settle flat on the floor.
--   2.65-3.00  The settled blossoms fade out completely.
--
-- Each blossom is solid geometry (five thick pale-pink petals round a darker pink centre), built once as a template
-- and cloned seven times. Motion is analytic (no physics): a fixed fall path per flower (a stylised slow fall: it
-- starts already moving and accelerates gently, like something light but with weight - no hovering or drifting up),
-- one floor raycast per flower at the start, and an authored bounce. Spots, sizes, directions, tumble and landing
-- times are fixed, so it's the same every time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Rig = require(script.Parent:WaitForChild("Rig"))

local Art = Assets.KillFx

local END = 3.0
local FADE_START = 2.65
local START_SPEED = 0.35 -- share of the drop covered at constant speed; the rest is gentle acceleration
local DRIFT = 0.55 -- scales `push` (studs/s) so the paths stay short and clear over the long fall
local SPIN = 0.5 -- scales `tumble` for a slight rotation
local PETAL = Color3.fromRGB(255, 202, 218)
local CENTRE = Color3.fromRGB(222, 88, 134)
local REST_HEIGHT = 0.06 -- centre-to-underside when lying flat, as a fraction of the diameter

-- Seven blossoms in the character's frame (x right, z back, y = fraction of body height above the feet).
-- size = diameter in studs; push = sideways drift while falling (x, z studs/s); tumble = axis and degrees/s;
-- land = effect time it touches the floor.
local FLOWERS = {
	{
		at = Vector3.new(-0.35, 0.9, 0.0),
		size = 1.3,
		appear = 0.04,
		push = Vector2.new(-0.9, 0.2),
		axis = Vector3.new(1, 0, 0.3),
		tumble = 160,
		yaw = 10,
		land = 2.12,
	},
	{
		at = Vector3.new(0.7, 0.76, -0.1),
		size = 1.05,
		appear = 0.06,
		push = Vector2.new(1.1, -0.3),
		axis = Vector3.new(0.2, 0, 1),
		tumble = -190,
		yaw = 70,
		land = 2.22,
	},
	{
		at = Vector3.new(-0.6, 0.6, 0.15),
		size = 1.1,
		appear = 0.08,
		push = Vector2.new(-1.0, 0.7),
		axis = Vector3.new(1, 0, -0.5),
		tumble = 140,
		yaw = 130,
		land = 2.05,
	},
	{
		at = Vector3.new(0.05, 0.55, -0.2),
		size = 1.25,
		appear = 0.1,
		push = Vector2.new(0.15, -1.0),
		axis = Vector3.new(0.6, 0, 1),
		tumble = -150,
		yaw = 200,
		land = 2.25,
	},
	{
		at = Vector3.new(0.6, 0.5, 0.15),
		size = 1.0,
		appear = 0.11,
		push = Vector2.new(1.0, 0.8),
		axis = Vector3.new(1, 0, 0.8),
		tumble = 200,
		yaw = 250,
		land = 2.15,
	},
	{
		at = Vector3.new(-0.4, 0.38, -0.05),
		size = 1.05,
		appear = 0.13,
		push = Vector2.new(-0.7, -0.9),
		axis = Vector3.new(0.3, 0, -1),
		tumble = -170,
		yaw = 300,
		land = 2.08,
	},
	{
		at = Vector3.new(0.4, 0.32, 0.15),
		size = 1.0,
		appear = 0.14,
		push = Vector2.new(0.6, 1.0),
		axis = Vector3.new(1, 0, 0.1),
		tumble = 180,
		yaw = 340,
		land = 2.18,
	},
}

type Layout = { offset: CFrame, size: Vector3 }
type Piece = { part: BasePart, offset: CFrame, size: Vector3 }

-- One blossom of unit diameter, lying flat (facing +Y): pieces named P1..P6 so clones map back by name.
local function buildTemplate(): (Model, { Layout })
	local model = Instance.new("Model")
	model.Name = "Blossom"
	local layout: { Layout } = {}
	local function piece(size: Vector3, color: Color3, offset: CFrame)
		table.insert(layout, { offset = offset, size = size })
		local p = Fx.part(model, {
			Name = "P" .. #layout,
			Size = size,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	for k = 0, 4 do
		-- Thick rounded petal, tilted up a little into a shallow cup.
		piece(
			Vector3.new(0.44, 0.1, 0.56),
			PETAL,
			CFrame.Angles(0, math.rad(k * 72), 0) * CFrame.new(0, 0.02, -0.27) * CFrame.Angles(math.rad(12), 0, 0)
		)
	end
	piece(Vector3.new(0.26, 0.16, 0.26), CENTRE, CFrame.new(0, 0.05, 0))
	return model, layout
end

return function(character: Model, parent: Instance)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local t0 = os.clock()

	local feetY, topY = math.huge, -math.huge
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d ~= root then
			feetY = math.min(feetY, d.Position.Y - d.Size.Y / 2)
			topY = math.max(topY, d.Position.Y + d.Size.Y / 2)
		end
	end
	if feetY == math.huge then
		return
	end
	local height = topY - feetY
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local base = Vector3.new(root.Position.X, feetY, root.Position.Z)
	local frame = CFrame.lookAt(base, base + look.Unit)

	local model = Instance.new("Model")
	model.Name = character.Name .. "_Sakura"
	model.Parent = parent
	local host = Fx.host(model, frame * CFrame.new(0, height * 0.55, 0))

	-- Vanish with a soft airy swoosh and a faint pink puff.
	Fx.sound(host, Art.AirySwoosh, 0.9, 1.15, t0, 0.9)
	local puff = Fx.emitter(host, {
		Texture = Art.Puff,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 220)),
		Size = Fx.seq(0, 1.4, 1, 2.8),
		Transparency = Fx.seq(0, 0.6, 1, 1),
		Lifetime = NumberRange.new(0.3),
		Speed = NumberRange.new(1),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.2,
	})
	puff:Emit(if Fx.detail(base) < 1 then 1 else 3)
	Rig.hide(character)

	-- Floor under each flower: one raycast each, ignoring the character and effects.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, parent }
	params.IgnoreWater = true

	local template, layout = buildTemplate()
	type Flower = { spec: any, pieces: { Piece }, start: Vector3, restY: number, landT: number, startRot: CFrame }
	local flowers: { Flower } = {}
	for _, f in FLOWERS do
		local start = (frame * CFrame.new(f.at.X, f.at.Y * height, f.at.Z)).Position
		local hit = workspace:Raycast(start, Vector3.new(0, -(height + 30), 0), params)
		local restY = (if hit then hit.Position.Y else feetY) + f.size * REST_HEIGHT
		local landT = f.land - f.appear -- fall duration
		local clone = template:Clone()
		clone.Parent = model
		local pieces: { Piece } = {}
		for i, l in layout do
			table.insert(
				pieces,
				{ part = clone:FindFirstChild("P" .. i) :: BasePart, offset = l.offset, size = l.size * f.size }
			)
		end
		local startRot = frame.Rotation * CFrame.Angles(math.rad(-60), math.rad(f.yaw), 0) -- tipped toward the viewer
		table.insert(flowers, {
			spec = f,
			pieces = pieces,
			start = start,
			restY = restY,
			landT = landT,
			startRot = startRot,
		})
	end
	template:Destroy()

	Fx.everyFrame(t0, END, function(t)
		local fade = Fx.span(t, FADE_START, END - 0.03)
		for _, fl in flowers do
			local f = fl.spec
			local tau = t - f.appear
			local scale = math.max(Fx.easeOutBack(Fx.span(t, f.appear, f.appear + 0.08)), 0.001)
			local drift = (frame.RightVector * f.push.X + frame.LookVector * -f.push.Y) * DRIFT
			local spin = math.rad(f.tumble) * SPIN
			local drop = fl.start.Y - fl.restY
			local pos, rot
			if tau <= fl.landT then
				-- Falling: down a fixed path that starts moving at once and accelerates gently, with a small sideways
				-- drift (easing off near the floor) and a slight tumble round its own axis.
				local tt = math.max(0, tau)
				local u = tt / fl.landT
				local fall = START_SPEED * u + (1 - START_SPEED) * u * u
				pos = fl.start + drift * fl.landT * (u * (1 - 0.3 * u) / 0.7) - Vector3.new(0, drop * fall, 0)
				rot = fl.startRot * CFrame.fromAxisAngle(f.axis.Unit, spin * tt)
			else
				-- Landed (2.05-2.25): one small bounce, then settle flat with a damped rock, done by ~2.65.
				local s = tau - fl.landT
				local landPos = fl.start + drift * fl.landT
				local hop = 0
				if s < 0.2 then
					local u = s / 0.2
					hop = 4 * u * (1 - u) * 0.1 * f.size
				end
				pos = Vector3.new(landPos.X, fl.restY + hop, landPos.Z)
				local landedRot = fl.startRot * CFrame.fromAxisAngle(f.axis.Unit, spin * fl.landT)
				local flat = CFrame.Angles(0, math.rad(f.yaw), 0)
				local settle = Fx.easeOut(math.min(1, s / 0.3))
				local rock = 0.16 * math.exp(-s * 9) * math.sin(s * 22)
				rot = landedRot:Lerp(flat, settle) * CFrame.Angles(rock, 0, rock * 0.6)
			end
			local cf = CFrame.new(pos) * rot
			local visible = t >= f.appear
			for _, p in fl.pieces do
				p.part.CFrame = cf * CFrame.new(p.offset.Position * f.size * scale) * p.offset.Rotation
				p.part.Size = p.size * scale
				p.part.Transparency = if visible then fade else 1
			end
		end
	end)

	Fx.at(t0, END, function()
		model:Destroy()
	end)
end
