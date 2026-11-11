-- "Ashes" kill effect, exactly 3 seconds.
--   0.00-0.60  Ignition: short flames start right at the feet.
--   0.60-1.50  Flames climb round the legs and torso into a full fire (main SWOOSH here). The body never moves: it
--              stays frozen in the exact pose it died in while it chars and crumbles.
--   1.50-2.25  Charcoal silhouette inside the moving flames.
--   2.25-3.00  Head-to-feet crumble into ash (body gone by ~2.75), flames die down, ash pile/smoke/embers clear by 3.00.
--
-- The fire is a few broad cartoon flames, not particles and no floor decal: each flame is a Beam from a fixed base
-- point to a moving tip, textured with one stylised flame shape (art/kill-effects/FlameGen.cs: rounded base, curved
-- tapered tip, red-orange rim, orange body, yellow inner flame) stretched along it with flat, unlit colours. Every
-- flame has its own authored height, lean, sway, bend and timing, so the fire moves smoothly upward, bending and
-- stretching, but plays out identically on every death. They overlap in three layers (feet, thighs/torso, shoulders)
-- into one connected fire with small gaps, so the charcoal body stays readable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Rig = require(script.Parent:WaitForChild("Rig"))

local Art = Assets.KillFx

local CHARCOAL = Color3.fromRGB(47, 45, 44)
local FIRE_LIGHT = Color3.fromRGB(255, 140, 55)
local END = 3.0

-- Flame tongues in three layers so the fire covers the whole body. Each row:
--   angle (deg) and radius (studs) round the feet; base = height its root sits at (fraction of the body's height);
--   top = height its tip reaches (fraction; up to 1.4 = 40% above the head); width (studs, broad bases);
--   lean/swirl push the tip outward/sideways (studs); phase/freq drive flicker and bend; delay staggers the climb;
--   out is when (after 2.25) it dies down.
-- width = the flame image's full width in studs (the shape itself tapers to its tip).
-- stylua: ignore
local TONGUE_ROWS = {
	--  angle radius base  top   width lean  swirl  phase freq  delay out
	-- Feet: broad flames rooted right at the feet, front/back/sides.
	{    15,  0.55, 0.0,  1.05, 2.3,  0.25,  0.2,  0.0,  0.9,  0.00, 0.05 },
	{    95,  0.6,  0.0,  0.95, 2.1,  0.25, -0.25, 1.3,  1.05, 0.06, 0.18 },
	{   175,  0.55, 0.0,  1.1,  2.3,  0.25,  0.2,  2.1,  0.85, 0.02, 0.1 },
	{   260,  0.6,  0.0,  1.0,  2.2,  0.25, -0.2,  3.4,  1.0,  0.08, 0.25 },
	{   330,  0.55, 0.0,  0.98, 2.1,  0.25,  0.25, 4.2,  0.95, 0.04, 0.02 },
	-- Thighs/torso: wrapping the middle of the body.
	{    55,  0.6,  0.3,  1.2,  1.8,  0.2,   0.2,  2.8,  0.9,  0.12, 0.12 },
	{   140,  0.6,  0.32, 1.15, 1.7,  0.2,  -0.25, 5.0,  1.1,  0.16, 0.3 },
	{   220,  0.6,  0.28, 1.22, 1.8,  0.2,   0.2,  1.9,  0.95, 0.1,  0.08 },
	{   300,  0.6,  0.3,  1.18, 1.7,  0.2,  -0.2,  3.9,  1.15, 0.14, 0.22 },
	-- Shoulders: tips 25-40% above the head.
	{   100,  0.45, 0.58, 1.36, 1.4,  0.15,  0.25, 2.5,  0.8,  0.24, 0.06 },
	{   235,  0.45, 0.6,  1.4,  1.4,  0.15, -0.25, 1.1,  0.85, 0.22, 0.0 },
	{   350,  0.45, 0.6,  1.32, 1.3,  0.15,  0.2,  3.2,  0.9,  0.3,  0.03 },
}
local TONGUES = {}
for _, r in TONGUE_ROWS do
	table.insert(TONGUES, {
		angle = r[1],
		radius = r[2],
		base = r[3],
		top = r[4],
		width = r[5],
		lean = r[6],
		swirl = r[7],
		phase = r[8],
		freq = r[9],
		delay = r[10],
		out = r[11],
	})
end

-- Ash pile: a low powdery mound plus a few fixed chunks (offsets from the centre of the stance, in studs).
local PILE_CHUNKS = {
	{ offset = Vector3.new(0.45, 0.12, 0.2), size = Vector3.new(0.45, 0.3, 0.4), color = Color3.fromRGB(88, 86, 84) },
	{ offset = Vector3.new(-0.5, 0.1, -0.15), size = Vector3.new(0.35, 0.25, 0.4), color = Color3.fromRGB(60, 58, 57) },
	{
		offset = Vector3.new(0.05, 0.16, -0.45),
		size = Vector3.new(0.4, 0.3, 0.3),
		color = Color3.fromRGB(120, 118, 114),
	},
	{ offset = Vector3.new(-0.15, 0.2, 0.35), size = Vector3.new(0.3, 0.3, 0.3), color = Color3.fromRGB(72, 70, 68) },
	{
		offset = Vector3.new(0.7, 0.07, -0.35),
		size = Vector3.new(0.22, 0.16, 0.24),
		color = Color3.fromRGB(100, 98, 95),
	},
}

-- How tall a tongue is at time t (0..1 of its full height): a short base over 0-0.6, the climb over 0.6-1.5, a
-- steady flicker, then dying down after 2.25.
local function growth(t: number, f): number
	-- Only the ground ring burns during ignition (0-0.6); raised layers wait for the climb.
	local base = if f.base > 0 then 0 else 0.25 * Fx.smooth(Fx.span(t, f.delay * 0.6, f.delay * 0.6 + 0.4))
	local climb = (if f.base > 0 then 1 else 0.75) * Fx.easeOut(Fx.span(t, 0.6 + f.delay, 1.3 + f.delay))
	local flicker = 1 + 0.07 * math.sin(t * f.freq * math.pi * 2 + f.phase) + 0.03 * math.sin(t * 4.1 + f.phase * 2)
	local die = 1 - Fx.smooth(Fx.span(t, 2.25 + f.out, 2.78))
	return (base + climb) * flicker * die
end

-- One cartoon flame: the whole flame image stretched once from base (Attachment0) to tip, flat and unlit so its
-- colours stay clean (no bloom).
local function makeBeam(host: BasePart, name: string, texture: string): (Beam, Attachment, Attachment)
	local a0 = Instance.new("Attachment")
	a0.Name = name .. "Base"
	a0.Parent = host
	local a1 = Instance.new("Attachment")
	a1.Name = name .. "Tip"
	a1.Parent = host
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = texture
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.TextureLength = 1
	beam.TextureSpeed = 0
	beam.FaceCamera = true
	beam.Segments = 12
	beam.LightEmission = 0
	beam.LightInfluence = 0
	beam.Brightness = 1
	beam.Transparency = NumberSequence.new(0)
	beam.Parent = host
	return beam, a0, a1
end

local function charcoal(part: BasePart, model: Model)
	part.Material = Enum.Material.Slate
	if part:IsA("MeshPart") then
		part.TextureID = ""
	end
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		elseif child:IsA("SpecialMesh") then
			child.TextureId = ""
		elseif child:IsA("Decal") then
			Fx.tween(child, 0.25, { Color3 = CHARCOAL })
		end
	end
	Fx.tween(part, 0.25, { Color = CHARCOAL })
	for _, d in model:GetChildren() do
		if d:IsA("Clothing") then
			Fx.tween(d, 0.25, { Color3 = Color3.fromRGB(40, 38, 37) })
		end
	end
end

-- A part crumbles: flakes leave from that spot (light ones drift up, dark ones and a chunk fall), then it's gone.
local function crumble(part: BasePart, startTime: number)
	local volume = part.Size.X * part.Size.Y * part.Size.Z
	local life = math.max(0.15, END - startTime - 0.04)
	local light = Fx.emitter(part, {
		Texture = Art.Flake,
		Color = ColorSequence.new(Color3.fromRGB(178, 175, 170)),
		Size = Fx.seq(0, 0.11, 1, 0.07),
		Transparency = Fx.seq(0, 0, 0.7, 0.1, 1, 1),
		Lifetime = NumberRange.new(math.min(0.7, life)),
		Speed = NumberRange.new(1.8),
		SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, 3, 0),
		RotSpeed = NumberRange.new(90),
	})
	local dark = Fx.emitter(part, {
		Texture = Art.Flake,
		Color = ColorSequence.new(Color3.fromRGB(68, 66, 64)),
		Size = NumberSequence.new(0.1),
		Transparency = Fx.seq(0, 0, 0.8, 0, 1, 1),
		Lifetime = NumberRange.new(math.min(0.5, life)),
		Speed = NumberRange.new(1.3),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -18, 0),
		RotSpeed = NumberRange.new(-120),
	})
	local chunk = Fx.emitter(part, {
		Texture = Art.Flake,
		Color = ColorSequence.new(Color3.fromRGB(54, 52, 51)),
		Size = NumberSequence.new(0.26),
		Transparency = Fx.seq(0, 0, 0.85, 0, 1, 1),
		Lifetime = NumberRange.new(math.min(0.45, life)),
		Speed = NumberRange.new(0.6),
		Acceleration = Vector3.new(0, -26, 0),
	})
	light:Emit(math.clamp(math.floor(volume * 3), 2, 6))
	dark:Emit(math.clamp(math.floor(volume * 4), 3, 8))
	if volume > 0.6 then
		chunk:Emit(1)
	end
	Fx.tween(part, 0.08, { Transparency = 1 }, Enum.EasingStyle.Linear)
	for _, child in part:GetChildren() do
		if child:IsA("Decal") then
			Fx.tween(child, 0.08, { Transparency = 1 }, Enum.EasingStyle.Linear)
		end
	end
end

local function ashPile(parent: Instance, center: Vector3): { BasePart }
	local parts = {}
	local function piece(offset: Vector3, size: Vector3, color: Color3, material: Enum.Material)
		local p = Fx.part(parent, {
			Name = "Ash",
			Material = material,
			Color = color,
			Size = size,
			CFrame = CFrame.new(center + offset),
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(0.2, 0.2, 0.2)
		mesh.Parent = p
		table.insert(parts, p)
		Fx.tween(mesh, 0.15, { Scale = Vector3.one })
	end
	piece(Vector3.new(0, 0.08, 0), Vector3.new(2.3, 0.34, 1.9), Color3.fromRGB(96, 94, 91), Enum.Material.Sand)
	piece(Vector3.new(0.35, 0.1, -0.2), Vector3.new(1.3, 0.42, 1.2), Color3.fromRGB(110, 108, 104), Enum.Material.Sand)
	for _, c in PILE_CHUNKS do
		piece(c.offset, c.size, c.color, Enum.Material.Slate)
	end
	return parts
end

return function(character: Model, parent: Instance)
	local frozen = Rig.freeze(character, parent)
	if not frozen then
		return
	end
	local t0 = os.clock()
	local model = frozen.model
	local height = math.max(frozen.topY - frozen.feetY, 0.1)
	local center = Vector3.new(frozen.root.Position.X, frozen.feetY, frozen.root.Position.Z)
	local host = Fx.host(model, CFrame.new(center + Vector3.new(0, 0.1, 0)), Vector3.new(1.8, 0.2, 1.8))
	local detail = Fx.detail(center)

	-- Sound: a big layered SWOOOOSH as the flames surge up (loudest): the fire blast on top, a deep pitched-down
	-- whoosh for body and a roaring noise rush that sustains briefly, then crackle and a dry ash collapse underneath.
	Fx.at(t0, 0.5, function()
		Fx.sound(host, Art.FireSwoosh, 1.9, 0.95, t0, 2.5)
		Fx.sound(host, Art.Swoosh, 1.2, 0.6, t0, 2.2)
		Fx.sound(host, Art.FireRoar, 1.1, 1.05, t0, 1.9)
	end)
	Fx.at(t0, 0.15, function()
		Fx.sound(host, Art.FireCrackle, 0.35, 1, t0, 2.6)
	end)
	Fx.at(t0, 2.25, function()
		Fx.sound(host, Art.AshCollapse, 0.55, 1.1, t0, 2.8)
	end)

	local light = Instance.new("PointLight")
	light.Color = FIRE_LIGHT
	light.Range = 10
	light.Brightness = 0
	light.Shadows = false
	light.Parent = host

	-- Beams.
	type Tongue = { beam: Beam, a0: Attachment, a1: Attachment, spec: any, dir: Vector3, tangent: Vector3 }
	local tongues: { Tongue } = {}
	for i, f in TONGUES do
		local beam, a0, a1 = makeBeam(host, "Flame" .. i, if i % 2 == 0 then Art.FlameA else Art.FlameB)
		local a = math.rad(f.angle)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(
			tongues,
			{ beam = beam, a0 = a0, a1 = a1, spec = f, dir = dir, tangent = Vector3.new(-dir.Z, 0, dir.X) }
		)
	end
	local up = Vector3.yAxis
	Fx.everyFrame(t0, END, function(t)
		light.Brightness = 1.6 * Fx.smooth(Fx.span(t, 0.1, 0.9)) * (1 - Fx.smooth(Fx.span(t, 2.2, 2.9)))

		for _, tg in tongues do
			local f = tg.spec
			local g = growth(t, f)
			local rootY = height * f.base + 0.05
			-- 0.93 keeps the flicker peaks within 25-40% above the head.
			-- The flame image's round base sits a little below its root so it starts right at the feet.
			local h = height * (f.top * 0.95 - f.base) * g + 0.35
			local sway = 0.22 * math.sin(t * f.freq * 3.1 + f.phase)
			local base = center + tg.dir * f.radius + up * (rootY - 0.2)
			local tip = center + tg.dir * (f.radius + f.lean * g) + tg.tangent * (f.swirl * g + sway) + up * (rootY + h)
			tg.a0.WorldCFrame = CFrame.fromMatrix(base, tg.tangent, up)
			tg.a1.WorldCFrame = CFrame.fromMatrix(tip, tg.tangent, up)
			-- Width breathes a little against the length, so the flame stretches and squashes as it rises.
			local w = f.width * (0.94 - 0.06 * math.sin(t * f.freq * 3.4 + f.phase * 1.7)) * math.clamp(g * 1.6, 0, 1)
			tg.beam.Width0 = w
			tg.beam.Width1 = w * 0.8
			local bend = 0.35 * h / math.max(height, 1)
			tg.beam.CurveSize0 = bend * math.sin(t * f.freq * 2.2 + f.phase)
			tg.beam.CurveSize1 = -bend * 0.6 * math.sin(t * f.freq * 2.9 + f.phase + 1)
			tg.beam.Enabled = g > 0.02
		end
	end)

	-- Embers and a thin trace of smoke; their lifetimes all end before 3.00.
	local embers = Fx.emitter(host, {
		Texture = Art.Ember,
		Color = Fx.colors(0, Color3.fromRGB(255, 214, 90), 1, Color3.fromRGB(255, 110, 40)),
		Size = Fx.seq(0, 0.16, 1, 0.05),
		Transparency = Fx.seq(0, 0, 0.8, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.55, 0.65),
		Speed = NumberRange.new(6, 9),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 2, 0),
		LightEmission = 0.4,
		Rate = 5 * detail,
	})
	local smoke = Fx.emitter(host, {
		Texture = Art.Puff,
		Color = ColorSequence.new(Color3.fromRGB(92, 90, 88)),
		Size = Fx.seq(0, 1.1, 1, 2.6),
		Transparency = Fx.seq(0, 0.8, 1, 1),
		Lifetime = NumberRange.new(0.6),
		Speed = NumberRange.new(5),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 1, 0),
		Rate = 2 * detail,
	})
	Fx.at(t0, 0.5, function()
		embers.Enabled = true
	end)
	Fx.at(t0, 1.2, function()
		smoke.Enabled = true
	end)
	Fx.at(t0, 2.3, function()
		embers.Enabled = false
		smoke.Enabled = false
	end)

	-- Charcoal silhouette.
	Fx.at(t0, 1.5, function()
		for _, part in frozen.parts do
			charcoal(part, model)
		end
	end)

	-- Ash: head and shoulders first, down to the feet, finished by ~2.73.
	for _, part in frozen.parts do
		local top = part.Position.Y + part.Size.Y / 2
		local fromTop = math.clamp((frozen.topY - top) / height, 0, 1)
		local start = 2.25 + 0.4 * fromTop
		Fx.at(t0, start, function()
			crumble(part, start)
		end)
	end
	local pile: { BasePart } = {}
	Fx.at(t0, 2.4, function()
		pile = ashPile(model, center)
	end)
	Fx.at(t0, 2.75, function()
		for _, p in pile do
			Fx.tween(p, 0.2, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		end
	end)

	Fx.at(t0, END, function()
		model:Destroy()
	end)
end
