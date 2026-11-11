-- Cosmetic taunt props, built locally on each client: anchored, no collision, no queries, no touches, so they never
-- affect gameplay. Callers position them every frame and destroy them when the taunt ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage.Shared.Referential.Skins)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)

local Props = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

export type Boomerang = { part: BasePart, size: number, setFade: (alpha: number) -> () }

-- A small copy of the player's equipped weapon skin (its model in Shared/Assets/Tools, Shared/Referential/Skins),
-- `size` studs across, welded to an invisible anchored card part: callers move `part` and the model follows.
-- (The package drew the skin's 2D art on a card; our skins are 3D models.)
function Props.boomerang(parent: Instance, skinId: string, size: number): Boomerang
	local skin = Skins[skinId] or Skins[SkinLibrary.getDefaultSkinId()]
	local card = part(parent, {
		Name = "TauntBoomerang",
		Size = Vector3.new(size, size, 0.06),
		Transparency = 1,
	})
	local template = skin and ReplicatedStorage.Shared.Assets.Tools:FindFirstChild(skin.Model)
	local parts: { BasePart } = {}
	if template and template:IsA("Model") then
		local model = template:Clone()
		local extents = model:GetExtentsSize()
		local largest = math.max(extents.X, extents.Y, extents.Z)
		if largest > 0 then
			model:ScaleTo(model:GetScale() * size / largest)
		end
		model:PivotTo(card.CFrame)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				d.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = card
				weld.Part1 = d
				weld.Parent = d
				table.insert(parts, d)
			elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
				d:Destroy()
			end
		end
		model.Parent = card
	end
	return {
		part = card,
		size = size,
		setFade = function(alpha: number)
			for _, p in parts do
				p.LocalTransparencyModifier = alpha
			end
		end,
	}
end

export type Crown = {
	model: Model,
	height: number, -- of the band, studs (the crown's base sits at its origin)
	rimRadius: number, -- radius of the thick lower rim's tube centre line, studs
	rimTube: number, -- that tube's radius (its centre is this far above the origin)
	place: (cframe: CFrame, scale: number) -> (), -- origin = centre of the bottom of the band
	setFade: (alpha: number) -> (),
}

local GOLD = Color3.fromRGB(255, 196, 52)
local GOLD_DARK = Color3.fromRGB(226, 150, 30)
local GEM = Color3.fromRGB(222, 36, 58)

-- A small chunky gold crown: a thick round band, five softly rounded points with ball tips, and one red gem at the
-- front (-Z). Built for a 1-stud-wide head (`width`), positioned with place().
function Props.crown(parent: Instance, width: number): Crown
	local model = Instance.new("Model")
	model.Name = "TauntCrown"
	model.Parent = parent
	local pieces: { { part: BasePart, offset: CFrame, size: Vector3 } } = {}
	local function piece(props, offset: CFrame)
		local p = part(model, props)
		table.insert(pieces, { part = p, offset = offset, size = p.Size })
		return p
	end
	local w = width
	local bandH = 0.32 * w
	-- Band: a hollow ring (so a hair bun or hat can show through the middle instead of being swallowed by a solid
	-- block), made of short thick segments, with a darker rim round the bottom.
	local SEGMENTS = 14
	local function ring(radius: number, height: number, thickness: number, y: number, color: Color3)
		local length = 2 * math.pi * radius / SEGMENTS * 1.08
		for i = 0, SEGMENTS - 1 do
			local a = (i + 0.5) / SEGMENTS * math.pi * 2
			local at = Vector3.new(math.sin(a) * radius, y, -math.cos(a) * radius)
			piece(
				{ Size = Vector3.new(length, height, thickness), Color = color },
				CFrame.lookAt(at, Vector3.new(0, y, 0))
			)
		end
	end
	ring(0.45 * w, bandH, 0.11 * w, bandH / 2, GOLD)
	-- Base: a thick rounded lower rim (round segments with balls at the joins, so it reads as one smooth tube) wrapped
	-- round the bottom of the band, and a solid bottom plate with a shallow recess in the middle of the underside so
	-- the crown sits on the head. The crown's origin is the underside of the rim.
	local RIM_R, RIM_TUBE = 0.47 * w, 0.075 * w
	for i = 0, SEGMENTS - 1 do
		local a0 = i / SEGMENTS * math.pi * 2
		local a1 = (i + 1) / SEGMENTS * math.pi * 2
		local p0 = Vector3.new(math.sin(a0) * RIM_R, RIM_TUBE, -math.cos(a0) * RIM_R)
		local p1 = Vector3.new(math.sin(a1) * RIM_R, RIM_TUBE, -math.cos(a1) * RIM_R)
		piece({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new((p1 - p0).Magnitude, RIM_TUBE * 2, RIM_TUBE * 2),
			Color = GOLD,
		}, CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.rad(90), 0))
		piece({ Shape = Enum.PartType.Ball, Size = Vector3.one * RIM_TUBE * 2, Color = GOLD }, CFrame.new(p0))
	end
	-- Bottom plate: a flat ring from the rim in towards the middle...
	local PLATE_T, INNER = 0.05 * w, 0.2 * w
	local mid = (RIM_R + INNER) / 2
	for i = 0, SEGMENTS - 1 do
		local a = (i + 0.5) / SEGMENTS * math.pi * 2
		local at = Vector3.new(math.sin(a) * mid, PLATE_T / 2, -math.cos(a) * mid)
		piece({
			Size = Vector3.new(2 * math.pi * RIM_R / SEGMENTS * 1.05, PLATE_T, RIM_R - INNER + 0.02 * w),
			Color = GOLD,
		}, CFrame.lookAt(at, Vector3.new(0, PLATE_T / 2, 0)))
	end
	-- ...and a raised centre disc: the shallow recess underneath (slightly darker, as it's in shadow).
	piece({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(PLATE_T, INNER * 2 + 0.04 * w, INNER * 2 + 0.04 * w),
		Color = GOLD_DARK,
	}, CFrame.new(0, PLATE_T * 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)))
	-- Five points round the top: rounded blobs leaning slightly outward, each with a ball tip.
	for i = 0, 4 do
		local a = math.rad(i * 72)
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a)) -- first point at the front
		local base = dir * 0.4 * w + Vector3.new(0, bandH, 0)
		local blob = piece(
			{ Size = Vector3.new(0.3 * w, 0.42 * w, 0.18 * w), Color = GOLD },
			CFrame.lookAt(base, base + dir) * CFrame.new(0, 0.12 * w, 0) * CFrame.Angles(math.rad(-10), 0, 0)
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = blob
		local tipPos = base + Vector3.new(0, 0.34 * w, 0) + dir * 0.05 * w
		piece({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.13 * w, Color = GOLD }, CFrame.new(tipPos))
	end
	-- The red gem on the front of the band.
	local gem = piece(
		{ Size = Vector3.new(0.2 * w, 0.2 * w, 0.1 * w), Color = GEM, Reflectance = 0.15 },
		CFrame.new(0, bandH * 0.5, -0.5 * w)
	)
	local gemMesh = Instance.new("SpecialMesh")
	gemMesh.MeshType = Enum.MeshType.Sphere
	gemMesh.Parent = gem

	return {
		model = model,
		height = bandH,
		rimRadius = RIM_R,
		rimTube = RIM_TUBE,
		place = function(cframe: CFrame, scale: number)
			for _, p in pieces do
				p.part.Size = p.size * math.max(scale, 0.001)
				p.part.CFrame = cframe * CFrame.new(p.offset.Position * scale) * p.offset.Rotation
			end
		end,
		setFade = function(alpha: number)
			for _, p in pieces do
				p.part.Transparency = alpha
			end
		end,
	}
end

-- Folding beach deck chair ------------------------------------------------------------------------------------------
--
-- Chair space: origin on the ground under the sitter's HumanoidRootPart, -Z = the way the sitter faces (the chair
-- stands behind them, +Z), +Y up, sized for a 5-stud character (scale it with the character's height). The side view
-- below is (y, z) in studs.

local WOOD = Color3.fromRGB(206, 146, 84)
local WOOD_DARK = Color3.fromRGB(160, 104, 56)
local STRIPE_BLUE = Color3.fromRGB(48, 118, 210)
local STRIPE_WHITE = Color3.fromRGB(246, 246, 240)

-- The fabric sling's centre line: from the low front bar, down to the sag where the hips rest, then a long straight
-- backrest sloping back at 55 degrees from vertical, up past head height (it carries the sleeper's back and head), to
-- the top bar.
-- stylua: ignore
Props.SLING = {
	Vector2.new(0.5, 0.2), Vector2.new(0.24, 0.62), Vector2.new(0.22, 1.05), Vector2.new(0.36, 1.45),
	Vector2.new(0.7, 1.94), Vector2.new(1.16, 2.6), Vector2.new(1.62, 3.25), Vector2.new(2.02, 3.83),
}
Props.BACKREST_RECLINE = 55 -- degrees from vertical
Props.SLING_HALF_WIDTH = 0.95
Props.RAIL_X = 1.04
-- Where the side frame (main rail) runs, ground at the front to the top of the back.
Props.MAIN_RAIL = { Vector2.new(0.02, 0.0), Vector2.new(2.14, 3.98) }
-- The headrest pillow: the head centre is `along` studs up the backrest from SLING[5]; `headRadius` is kept clear.
Props.PILLOW = { along = 1.36, headRadius = 0.58, thickness = 0.25 }

export type Chair = {
	model: Model,
	place: (cframe: CFrame, scale: number) -> (), -- cframe = chair space origin in the world
	setFade: (alpha: number) -> (),
}

-- A low, deeply reclining folding beach chair with a long backrest: warm wooden frame with softly rounded rails,
-- crossed folding legs, crossbars, and a continuous blue-and-white striped fabric sling (stripes running front to back)
-- sagging between the front bar and the top bar.
function Props.deckChair(parent: Instance): Chair
	local model = Instance.new("Model")
	model.Name = "TauntDeckChair"
	model.Parent = parent
	local pieces: { { part: BasePart, offset: CFrame, size: Vector3 } } = {}
	local function add(p: BasePart, offset: CFrame)
		table.insert(pieces, { part = p, offset = offset, size = p.Size })
	end
	-- A round wooden rail between two points (y, z) on side x; cylinders run along X, so turn X onto the rail.
	local function rail(x: number, a: Vector2, b: Vector2, radius: number, color: Color3?)
		local pa, pb = Vector3.new(x, a.X, a.Y), Vector3.new(x, b.X, b.Y)
		local length = (pb - pa).Magnitude
		local p = part(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(length + radius * 2, radius * 2, radius * 2),
			Color = color or WOOD,
			Material = Enum.Material.Wood,
		})
		add(p, CFrame.lookAt((pa + pb) / 2, pb) * CFrame.Angles(0, math.rad(90), 0))
	end
	-- A crossbar along X at (y, z).
	local function bar(at: Vector2, halfWidth: number, radius: number)
		local p = part(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(halfWidth * 2, radius * 2, radius * 2),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
		})
		add(p, CFrame.new(0, at.X, at.Y))
	end

	local R = Props.RAIL_X
	for _, x in { -R, R } do
		rail(x, Props.MAIN_RAIL[1], Props.MAIN_RAIL[2], 0.08) -- side frame: ground at the front up to the top of the back
		rail(x, Vector2.new(0.02, 3.3), Vector2.new(0.9, 0.6), 0.075) -- back leg, crossing the side frame
		rail(x, Vector2.new(0.5, 0.15), Vector2.new(0.28, 2.4), 0.07) -- seat rail from the front bar back to the leg
	end
	bar(Props.SLING[1], R + 0.06, 0.075) -- front bar (the sling's front edge)
	bar(Props.SLING[#Props.SLING], R + 0.06, 0.08) -- top bar (the sling's top edge)
	bar(Vector2.new(0.1, 3.25), R + 0.04, 0.06) -- back legs' foot bar
	bar(Vector2.new(0.1, 0.08), R + 0.04, 0.06) -- side frames' foot bar

	-- The sling: seven stripes across, each a chain of thin panels following the sagging centre line.
	local STRIPES = 7
	local width = Props.SLING_HALF_WIDTH * 2 / STRIPES
	for s = 0, STRIPES - 1 do
		local x = -Props.SLING_HALF_WIDTH + (s + 0.5) * width
		-- Outer stripes sag a touch less than the middle ones (the fabric is held at the bars, slack in the middle).
		local slack = 1 - math.abs(x) / Props.SLING_HALF_WIDTH * 0.35
		for i = 1, #Props.SLING - 1 do
			local a, b = Props.SLING[i], Props.SLING[i + 1]
			local function lift(v: Vector2, idx: number): Vector2
				-- Middle points droop by up to 0.06 more for the inner stripes.
				local interior = if idx == 1 or idx == #Props.SLING then 0 else 1
				return Vector2.new(v.X - 0.06 * interior * slack, v.Y)
			end
			local pa = lift(a, i)
			local pb = lift(b, i + 1)
			local A, B = Vector3.new(x, pa.X, pa.Y), Vector3.new(x, pb.X, pb.Y)
			local p = part(model, {
				Size = Vector3.new(width * 1.02, 0.05, (B - A).Magnitude + 0.03),
				Color = if s % 2 == 0 then STRIPE_BLUE else STRIPE_WHITE,
				Material = Enum.Material.Fabric,
			})
			add(p, CFrame.lookAt((A + B) / 2, B))
		end
	end

	-- A soft striped horseshoe headrest pillow on the backrest, cradling the sleeper's head: a cushion either side of the
	-- head and a bolster across above it, all clear of a head of radius Props.PILLOW.headRadius centred `along` studs up
	-- the backrest from SLING[5], so the head nestles between them on the fabric without touching them.
	local slope = (Props.SLING[#Props.SLING] - Props.SLING[5]).Unit -- (y, z) up the backrest
	local P = Props.PILLOW
	local base = Props.SLING[5] + Vector2.new(-0.06, 0) + slope * P.along -- on the fabric, level with the head centre
	-- Pillow space: X across the chair, Y off the fabric, -Z up the backrest.
	local pillowCF = CFrame.lookAt(Vector3.new(0, base.X, base.Y), Vector3.new(0, base.X + slope.X, base.Y + slope.Y))

	local function cushion(size: Vector3, at: Vector3, color: Color3)
		local p = part(model, { Size = size, Color = color, Material = Enum.Material.Fabric })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		add(p, pillowCF * CFrame.new(at))
	end
	local gap = P.headRadius + 0.04
	local LOBE = Vector3.new(0.36, P.thickness * 2, 0.95)
	local BOLSTER = Vector3.new(2 * (gap + LOBE.X), P.thickness * 1.8, 0.4)
	for _, side in { -1, 1 } do
		cushion(LOBE, Vector3.new(side * (gap + LOBE.X / 2), P.thickness * 0.5, -0.1), STRIPE_WHITE)
		-- A blue stripe round each side cushion (slightly fatter so it shows, narrower along the slope).
		cushion(
			LOBE * Vector3.new(1.06, 1.06, 0.3),
			Vector3.new(side * (gap + LOBE.X / 2), P.thickness * 0.5, -0.1),
			STRIPE_BLUE
		)
	end
	cushion(BOLSTER, Vector3.new(0, P.thickness * 0.45, -(gap + BOLSTER.Z / 2)), STRIPE_WHITE)
	cushion(
		BOLSTER * Vector3.new(0.3, 1.06, 1.06),
		Vector3.new(0, P.thickness * 0.45, -(gap + BOLSTER.Z / 2)),
		STRIPE_BLUE
	)

	return {
		model = model,
		place = function(cframe: CFrame, scale: number)
			for _, p in pieces do
				p.part.Size = p.size * math.max(scale, 0.001)
				p.part.CFrame = cframe * CFrame.new(p.offset.Position * scale) * p.offset.Rotation
			end
		end,
		setFade = function(alpha: number)
			for _, p in pieces do
				p.part.Transparency = alpha
			end
		end,
	}
end

-- Where a hat should sit on this character (head space): the top of the head, raised over the hair/hat accessories
-- that cover it so the crown rests on the hair cap instead of sinking into it - but by at most a quarter of a head, so
-- a tall bun or hat pokes up through the (hollow) crown rather than lifting it into the air. With `uncapped`, the full
-- height of the hair (for a crown with a solid base that must sit on top of it).
function Props.headTop(character: Model, uncapped: boolean?): number
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return 0.6
	end
	local top = head.Size.Y / 2
	for _, acc in character:GetChildren() do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle") :: BasePart?
			if handle then
				local rel = head.CFrame:ToObjectSpace(handle.CFrame)
				local half = handle.Size / 2
				-- Only things over the crown of the head (not face accessories, backpacks or shoulder pets).
				if math.abs(rel.Position.X) < head.Size.X * 0.6 and math.abs(rel.Position.Z) < head.Size.Z * 0.7 then
					local hTop = rel.Position.Y + math.abs(rel.UpVector.Y) * half.Y
					if hTop > top and hTop < head.Size.Y * 2 then
						-- Sit into fluffy hair a little rather than float on its very top.
						top = math.max(top, hTop - (if uncapped then 0 else 0.2 * head.Size.Y))
					end
				end
			end
		end
	end
	if uncapped then
		return top
	end
	return math.min(top, head.Size.Y * 0.75)
end

return Props
