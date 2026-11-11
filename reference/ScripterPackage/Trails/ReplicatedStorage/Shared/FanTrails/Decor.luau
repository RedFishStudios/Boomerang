--!strict
-- Decoration shapes for FanTrails: a thin mesh bamboo leaf, blossoms, petals, feathers, foam curls, droplets and embers
-- built from a few smooth parts (so they have real thickness and read from the side), and flat camera-facing glints,
-- stars and crescents built from GUI frames. No textures or uploads needed.
--
-- Every shape is built at size 1 (its main length, in studs) in its own space: +Z along its length, +Y its face
-- normal. `place(cframe, scale)` positions and sizes it, `fade(a)` fades it (0 = as built, 1 = invisible),
-- `pose(p)` (curls only) animates its shape, `destroy()` removes it.

local Decor = {}

export type Shape = {
	place: (cframe: CFrame, scale: number) -> (),
	fade: (alpha: number) -> (),
	pose: ((progress: number) -> ())?,
	destroy: () -> (),
}

type Piece = { part: BasePart, offset: CFrame, size: Vector3, transparency: number }

local function smooth(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- A shape made of parts. `add` takes a part's size and offset at scale 1.
local function partShape(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = parent
	local pieces: { Piece } = {}
	local self = {}
	function self.add(
		kind: "Ellipsoid" | "Cylinder" | "Block",
		size: Vector3,
		offset: CFrame,
		color: Color3,
		opts: {
			material: Enum.Material?,
			transparency: number?,
		}?
	): Piece
		local p = Instance.new("Part")
		smooth(p)
		p.Color = color
		p.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
		if kind == "Ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		elseif kind == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder -- along X
		end
		local piece = { part = p, offset = offset, size = size, transparency = (opts and opts.transparency) or 0 }
		p.Transparency = piece.transparency
		p.Size = size
		p.Parent = folder
		table.insert(pieces, piece)
		return piece
	end
	-- An existing part (e.g. a cloned mesh), sized `size` at scale 1.
	function self.addPart(p: BasePart, size: Vector3, offset: CFrame): Piece
		smooth(p)
		local piece = { part = p, offset = offset, size = size, transparency = 0 }
		p.Transparency = 0
		p.Size = size
		p.Parent = folder
		table.insert(pieces, piece)
		return piece
	end
	function self.place(cframe: CFrame, scale: number)
		local s = math.max(scale, 0.001)
		for _, piece in pieces do
			piece.part.Size = piece.size * s
			piece.part.CFrame = cframe * CFrame.new(piece.offset.Position * s) * piece.offset.Rotation
		end
	end
	function self.fade(alpha: number)
		for _, piece in pieces do
			piece.part.Transparency = piece.transparency + (1 - piece.transparency) * alpha
		end
	end
	function self.destroy()
		folder:Destroy()
	end
	self.pieces = pieces
	return self
end

local function darker(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end

-- Bamboo leaf ------------------------------------------------------------------------------------------------------
-- A thin, elongated blade built once per client as a mesh (EditableMesh): pointed tip, gently curved edges widest about
-- a third of the way along, a slight upward bend along its length, a shallow V crease down the middle, double-sided,
-- with restrained shading (a lighter midrib, slightly darker edges). The part's Color tints it.
-- Size 1 = the leaf's length; it lies along Z with its face up (+Y).
local AssetService = game:GetService("AssetService")

local leafTemplate: MeshPart? = nil
local leafBuilding = false

local function buildLeaf(): MeshPart
	local em = AssetService:CreateEditableMesh()
	local ROWS = 12
	local rib = em:AddColor(Color3.new(1, 1, 0.86), 1) -- the midrib, a touch lighter and warmer
	local edge = em:AddColor(Color3.new(0.8, 0.84, 0.78), 1)
	local function shape(t: number): (number, number, number)
		local halfWidth = 0.1 * math.sin(math.pi * t ^ 0.62) ^ 0.85 -- narrow stalk end, widest ~1/3, long pointed tip
		local bend = 0.07 * (1 - (2 * t - 1) ^ 2) - 0.03 * t * t -- arches up, the tip dipping slightly
		local sweep = 0.035 * t * t -- a slight sideways curve
		return halfWidth, bend, sweep
	end
	-- Each row: left edge, midrib, right edge (top surface); the bottom surface is a copy 0.006 below.
	local top, bottom = {}, {}
	for i = 0, ROWS do
		local t = i / ROWS
		local w, y, x = shape(t)
		local z = t - 0.5
		local fold = w * 0.35 -- the V crease: edges raised relative to the midrib
		top[i] = {
			em:AddVertex(Vector3.new(x - w, y + fold, z)),
			em:AddVertex(Vector3.new(x, y, z)),
			em:AddVertex(Vector3.new(x + w, y + fold, z)),
		}
		bottom[i] = {
			em:AddVertex(Vector3.new(x - w, y + fold - 0.006, z)),
			em:AddVertex(Vector3.new(x, y - 0.006, z)),
			em:AddVertex(Vector3.new(x + w, y + fold - 0.006, z)),
		}
	end
	local function face(a: number, b: number, c: number, ca: number, cb: number, cc: number)
		local pa, pb, pc = em:GetPosition(a), em:GetPosition(b), em:GetPosition(c)
		local n = (pb - pa):Cross(pc - pa)
		if n.Magnitude < 1e-9 then
			return
		end
		local normal = em:AddNormal(n.Unit)
		local f = em:AddTriangle(a, b, c)
		em:SetFaceNormals(f, { normal, normal, normal })
		em:SetFaceColors(f, { ca, cb, cc })
	end
	for i = 0, ROWS - 1 do
		for k = 1, 2 do
			local a, b = top[i][k], top[i][k + 1]
			local c, d = top[i + 1][k], top[i + 1][k + 1]
			local cl = if k == 1 then edge else rib -- left and right colour of this strip
			local cr = if k == 1 then rib else edge
			face(a, c, b, cl, cl, cr)
			face(b, c, d, cr, cl, cr)
			local ba, bb = bottom[i][k], bottom[i][k + 1]
			local bc, bd = bottom[i + 1][k], bottom[i + 1][k + 1]
			face(ba, bb, bc, cl, cr, cl)
			face(bb, bd, bc, cr, cr, cl)
		end
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Precise,
	})
	part.Name = "BambooLeaf"
	part.Material = Enum.Material.SmoothPlastic
	smooth(part)
	return part
end

-- Build the leaf mesh in the background (FanTrails calls this when it loads). Until it's ready, or where EditableMesh
-- isn't available, Decor.Leaf uses a thin part-based leaf instead.
function Decor.prepare()
	if leafTemplate or leafBuilding then
		return
	end
	leafBuilding = true
	task.spawn(function()
		local ok, result = pcall(buildLeaf)
		if ok then
			leafTemplate = result
		else
			warn("[FanTrails] leaf mesh unavailable, using the part leaf: " .. tostring(result))
		end
	end)
end

function Decor.Leaf(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	if leafTemplate then
		local leaf = leafTemplate:Clone()
		leaf.Color = color
		local size = leafTemplate.Size / math.max(leafTemplate.Size.Z, 1e-3) -- normalised to length 1
		s.addPart(leaf, size, CFrame.new())
		return s :: any
	end
	-- Fallback: two very thin, slightly folded halves and a fine midrib.
	for _, side in { -1, 1 } do
		s.add(
			"Ellipsoid",
			Vector3.new(0.11, 0.012, 1),
			CFrame.new(side * 0.045, 0.006, 0) * CFrame.Angles(0, side * math.rad(1), side * math.rad(-10)),
			if side < 0 then color else color:Lerp(Color3.new(1, 1, 1), 0.06)
		)
	end
	s.add(
		"Cylinder",
		Vector3.new(0.9, 0.01, 0.01),
		CFrame.new(0, 0.01, 0) * CFrame.Angles(0, math.rad(90), 0),
		color:Lerp(Color3.new(1, 1, 0.8), 0.25)
	)
	return s :: any
end

-- A sakura blossom: five rounded pink petals, each with a small notch at its tip (two overlapping lobes), cupped
-- slightly upward around a golden-yellow centre. Size 1 = the flower's diameter.
function Decor.Blossom(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	local deep = color:Lerp(Color3.fromRGB(214, 70, 120), 0.55)
	s.add("Ellipsoid", Vector3.new(0.4, 0.07, 0.4), CFrame.new(0, 0.005, 0), deep) -- the blush in the middle
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5
		local petal = CFrame.Angles(0, a, 0) * CFrame.new(0, 0.03, -0.25) * CFrame.Angles(math.rad(14), 0, 0)
		for _, side in { -1, 1 } do
			s.add(
				"Ellipsoid",
				Vector3.new(0.2, 0.075, 0.34),
				petal * CFrame.new(side * 0.045, 0, 0) * CFrame.Angles(0, side * math.rad(-10), 0),
				color
			)
		end
	end
	s.add("Ellipsoid", Vector3.new(0.17, 0.11, 0.17), CFrame.new(0, 0.07, 0), Color3.fromRGB(255, 206, 60))
	for k = 0, 4 do -- stamen dots
		local a = (k + 0.5) * math.pi * 2 / 5
		s.add(
			"Ellipsoid",
			Vector3.new(0.05, 0.05, 0.05),
			CFrame.Angles(0, a, 0) * CFrame.new(0, 0.09, -0.12),
			Color3.fromRGB(255, 176, 40)
		)
	end
	return s :: any
end

-- A loose sakura petal: broad, slightly cupped, with a notch at the tip.
function Decor.Petal(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	for _, side in { -1, 1 } do
		s.add(
			"Ellipsoid",
			Vector3.new(0.62, 0.16, 1),
			CFrame.new(side * 0.13, 0, 0) * CFrame.Angles(0, side * math.rad(-10), side * math.rad(-12)),
			color
		)
	end
	return s :: any
end

-- A white feather: a curved vane in three broad divisions along a central shaft.
function Decor.Feather(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	local shaft = darker(color, 0.12)
	local segments = { { -0.3, 0.3, 0.4, -12 }, { 0.02, 0.34, 0.4, 0 }, { 0.32, 0.25, 0.34, 12 } } -- z, width, length, yaw
	for _, seg in segments do
		local z = seg[1]
		local x = 0.12 * z * z -- the curve
		s.add(
			"Ellipsoid",
			Vector3.new(seg[2], 0.045, seg[3]),
			CFrame.new(x + 0.04, 0, z) * CFrame.Angles(0, math.rad(seg[4]), 0),
			color
		)
	end
	for _, piece in { { -0.25, 0.55, -10 }, { 0.22, 0.5, 9 } } do
		local z = piece[1]
		s.add(
			"Cylinder",
			Vector3.new(piece[2], 0.035, 0.035),
			CFrame.new(0.12 * z * z, 0.02, z) * CFrame.Angles(0, math.rad(90 + piece[3]), 0),
			shaft
		)
	end
	return s :: any
end

-- A white foam curl: a crest of rounded beads along a tightening spiral in its Y-Z plane (curling back towards -Z...+Z
-- as `pose` goes 0 -> 1). Size 1 = the crest's height.
function Decor.Curl(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	local BEADS = 7
	local beads = {}
	for i = 1, BEADS do
		local r = 0.36 - (i - 1) * 0.032
		beads[i] = s.add("Ellipsoid", Vector3.new(r, r, r), CFrame.new(), color)
	end
	s.add("Ellipsoid", Vector3.new(0.1, 0.32, 0.45), CFrame.new(0, -0.4, 0.08), Color3.fromRGB(150, 225, 240)) -- its foot (flat once the curl is laid on its side)
	function s.pose(progress: number)
		-- Beads along an inward spiral starting at the foot (bottom), rising up the front (-Z), over the top and curling
		-- down the back (+Z); the sweep grows as the crest curls over.
		local sweep = math.rad(150 + 150 * progress)
		for i, piece in beads do
			local u = (i - 1) / (BEADS - 1)
			local a = u * sweep
			local r = 0.42 * (1 - 0.4 * u)
			piece.offset = CFrame.new(0, -r * math.cos(a), -r * math.sin(a))
		end
	end
	s.pose(0)
	return s :: any
end

-- A water droplet: a rounded teardrop (stretched along +Z, the way it's flying).
function Decor.Droplet(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	s.add("Ellipsoid", Vector3.new(0.75, 0.75, 1), CFrame.new(), color, { transparency = 0.05 })
	s.add("Ellipsoid", Vector3.new(0.4, 0.4, 0.55), CFrame.new(0, 0, -0.28), color)
	s.add("Ellipsoid", Vector3.new(0.22, 0.22, 0.22), CFrame.new(-0.16, 0.2, 0.12), Color3.new(1, 1, 1))
	return s :: any
end

-- A foam fleck: a small cluster of flattened white bubbles lying on the water. Size 1 = its width.
function Decor.Foam(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	for _, b in { { 0, 0, 0.55 }, { 0.3, 0.12, 0.38 }, { -0.28, 0.18, 0.34 }, { 0.08, -0.3, 0.3 } } do
		s.add(
			"Ellipsoid",
			Vector3.new(b[3], b[3] * 0.32, b[3]),
			CFrame.new(b[1], 0, b[2]),
			color:Lerp(Color3.fromRGB(205, 240, 250), math.abs(b[2]))
		)
	end
	return s :: any
end

-- A small glowing orb: a bright pale-blue core inside a soft, mostly transparent halo. Size 1 = the core's diameter.
function Decor.Orb(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	s.add(
		"Ellipsoid",
		Vector3.new(2.1, 2.1, 2.1),
		CFrame.new(),
		color,
		{ material = Enum.Material.Neon, transparency = 0.82 }
	)
	s.add(
		"Ellipsoid",
		Vector3.new(1, 1, 1),
		CFrame.new(),
		color:Lerp(Color3.new(1, 1, 1), 0.12),
		{ material = Enum.Material.Neon }
	)
	return s :: any
end

-- An ember: a small glowing amber bead.
function Decor.Ember(parent: Instance, color: Color3): Shape
	local s = partShape(parent)
	s.add("Ellipsoid", Vector3.new(1, 1, 1), CFrame.new(), color, { material = Enum.Material.Neon })
	return s :: any
end

-- Flat, camera-facing shapes drawn with frames in a BillboardGui (always face the camera, keep depth).
local function billboardShape(parent: Instance, build: (gui: BillboardGui) -> { GuiObject })
	local anchor = Instance.new("Part")
	smooth(anchor)
	anchor.Name = "Decor"
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.05, 0.05, 0.05)
	anchor.Parent = parent
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local frames = build(gui)
	local base = {}
	for i, f in frames do
		base[i] = f.BackgroundTransparency
	end
	local self = {}
	function self.place(cframe: CFrame, scale: number)
		anchor.CFrame = CFrame.new(cframe.Position)
		gui.Size = UDim2.fromScale(math.max(scale, 0.001), math.max(scale, 0.001))
		local _, yaw = cframe:ToOrientation()
		gui:SetAttribute("Spin", yaw)
		for _, f in frames do
			if f:GetAttribute("Spins") then
				f.Rotation = (f:GetAttribute("BaseRotation") :: number or 0) + math.deg(yaw)
			end
		end
	end
	function self.fade(alpha: number)
		for i, f in frames do
			f.BackgroundTransparency = base[i] + (1 - base[i]) * alpha
		end
	end
	function self.destroy()
		anchor:Destroy()
	end
	return self
end

local function frame(gui: Instance, size: Vector2, pos: Vector2, color: Color3, rotation: number, round: number)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromScale(size.X, size.Y)
	f.Position = UDim2.fromScale(pos.X, pos.Y)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rotation
	f:SetAttribute("BaseRotation", rotation)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(round, 0)
	c.Parent = f
	f.Parent = gui
	return f
end

-- A rounded golden diamond glint with a bright centre.
function Decor.Diamond(parent: Instance, color: Color3): Shape
	return billboardShape(parent, function(gui)
		local outer = frame(gui, Vector2.new(0.62, 0.62), Vector2.new(0.5, 0.5), color, 45, 0.28)
		local inner =
			frame(gui, Vector2.new(0.3, 0.3), Vector2.new(0.5, 0.5), color:Lerp(Color3.new(1, 1, 1), 0.65), 45, 0.3)
		return { outer, inner }
	end) :: any
end

-- A four-point star glint: two crossed tapering pills and a bright centre.
function Decor.Star4(parent: Instance, color: Color3): Shape
	return billboardShape(parent, function(gui)
		local a = frame(gui, Vector2.new(1, 0.16), Vector2.new(0.5, 0.5), color, 0, 1)
		local b = frame(gui, Vector2.new(0.16, 1), Vector2.new(0.5, 0.5), color, 0, 1)
		local c = frame(gui, Vector2.new(0.3, 0.3), Vector2.new(0.5, 0.5), Color3.new(1, 1, 1), 45, 0.25)
		for _, f in { a, b, c } do
			f:SetAttribute("Spins", true)
		end
		return { a, b, c }
	end) :: any
end

-- A small crescent moon: round beads along an arc, thick in the middle and thin at the horns.
function Decor.Crescent(parent: Instance, color: Color3): Shape
	return billboardShape(parent, function(gui)
		local beads = {}
		local N = 11
		for i = 0, N - 1 do
			local u = i / (N - 1)
			local a = math.rad(-110 + 220 * u)
			local size = 0.08 + 0.2 * math.sin(math.pi * u)
			local pos = Vector2.new(0.5 - 0.36 * math.cos(a) + 0.08 * math.sin(math.pi * u), 0.5 + 0.36 * math.sin(a))
			table.insert(beads, frame(gui, Vector2.new(size, size), pos, color, 0, 0.5))
		end
		return beads
	end) :: any
end

return Decor
