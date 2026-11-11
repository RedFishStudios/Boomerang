-- The Shark Attack kill effect's shark: the supplied Boomerang shark 3D kit (art/shark/kit), used as it is.
--
-- Shared.SharkKitData holds the kit's mesh exactly as modelled (generated from its GLB by art/shark/KitConvert.cs):
-- the body (Root bone) and the lower jaw with its teeth and tongue (Jaw bone), with the kit's vertex colours. The kit
-- is rigged with rigid weights on those two bones, so two mesh parts reproduce its rig exactly: the jaw part turns
-- about the Jaw bone's pivot by the kit's own open rotation (0 = fully closed, OPEN = fully open, 43 degrees).
--
-- Each client builds the two mesh parts once with EditableMesh (SharkModel.prepare(), started at load) and every
-- effect clones them.
--
-- local shark = SharkModel.get(scale)  -- { model, body = { {part, offset} }, jaw = { {part, offset} }, hinge }
-- SharkModel.place(shark, sharkCFrame, openRadians)

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SharkKitData"))

local SharkModel = {}

export type Piece = { part: BasePart, offset: CFrame } -- offset in the shark's frame (jaw: closed pose)
export type Shark = { model: Model, body: { Piece }, jaw: { Piece }, hinge: Vector3 }

-- The kit's fully open jaw, in radians.
SharkModel.OPEN = math.rad(Data.OpenDegrees)
-- The mouth interior measured from the kit (scale 1): Seam height, cavity HalfWidth, Reach forward of the hinge.
SharkModel.MOUTH = Data.Mouth

local AXIS = Data.Axis.Unit

-- The mouth's frame (shark frame, scale 1) with the jaw `open` radians: origin where palate and tongue meet at the
-- hinge, +Y along the middle of the open mouth (halfway between palate and jaw, pointing out towards the lips), +Z
-- out of the opening on the jaw side, +X sideways. A swallowed player stands along +Y, centred in the cavity.
function SharkModel.mouthFrame(open: number): CFrame
	local half = CFrame.fromAxisAngle(AXIS, open / 2)
	local along = half:VectorToWorldSpace(Vector3.zAxis) -- palate runs along +Z; the jaw is turned by `open`
	local out = half:VectorToWorldSpace(-Vector3.yAxis) -- the jaw (belly) side
	return CFrame.fromMatrix(Vector3.new(0, Data.Mouth.Seam, Data.Pivot.Z), along:Cross(out), along, out)
end

-- Standard base64 -> buffer.
local function decode(text: string): buffer
	local lookup = {}
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do
		lookup[string.byte(alphabet, i)] = i - 1
	end
	local padding = 0
	if string.sub(text, -2) == "==" then
		padding = 2
	elseif string.sub(text, -1) == "=" then
		padding = 1
	end
	local out = buffer.create(#text // 4 * 3 - padding)
	local o = 0
	for i = 1, #text, 4 do
		local a, b, c, d = string.byte(text, i, i + 3)
		local n = lookup[a] * 262144 + lookup[b] * 4096 + (lookup[c] or 0) * 64 + (lookup[d] or 0)
		buffer.writeu8(out, o, n // 65536)
		if o + 1 < buffer.len(out) then
			buffer.writeu8(out, o + 1, (n // 256) % 256)
		end
		if o + 2 < buffer.len(out) then
			buffer.writeu8(out, o + 2, n % 256)
		end
		o += 3
	end
	return out
end

-- One kit mesh as an anchored, non-colliding MeshPart centred on its bounds.
local function buildPart(name: string, mesh): MeshPart
	local q = Data.PositionQuantum
	local vertices = decode(mesh.Vertices)
	local triangles = decode(mesh.Triangles)
	local em = AssetService:CreateEditableMesh()
	local colorIds = {}
	for i, color in Data.Palette do
		colorIds[i] = em:AddColor(color, 1)
	end
	local vertexIds, normalIds, vertexColors = table.create(mesh.VertexCount), table.create(mesh.VertexCount), {}
	for i = 0, mesh.VertexCount - 1 do
		local p = i * 10
		vertexIds[i + 1] = em:AddVertex(
			Vector3.new(
				buffer.readi16(vertices, p) * q,
				buffer.readi16(vertices, p + 2) * q,
				buffer.readi16(vertices, p + 4) * q
			)
		)
		normalIds[i + 1] = em:AddNormal(
			Vector3.new(buffer.readi8(vertices, p + 6), buffer.readi8(vertices, p + 7), buffer.readi8(vertices, p + 8))
				/ 127
		)
		vertexColors[i + 1] = colorIds[buffer.readu8(vertices, p + 9) + 1]
	end
	for t = 0, mesh.TriangleCount - 1 do
		local a = buffer.readu16(triangles, t * 6) + 1
		local b = buffer.readu16(triangles, t * 6 + 2) + 1
		local c = buffer.readu16(triangles, t * 6 + 4) + 1
		local face = em:AddTriangle(vertexIds[a], vertexIds[b], vertexIds[c])
		em:SetFaceNormals(face, { normalIds[a], normalIds[b], normalIds[c] })
		em:SetFaceColors(face, { vertexColors[a], vertexColors[b], vertexColors[c] })
		if t % 2000 == 1999 then
			task.wait()
		end
	end
	local part = AssetService:CreateMeshPartAsync(
		Content.fromObject(em),
		{ CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Precise }
	)
	part.Name = name
	part.Color = Color3.new(1, 1, 1) -- the vertex colours show as modelled
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = mesh.Size
	return part
end

local template: Shark? = nil
local building = false

local function build(): Shark
	local model = Instance.new("Model")
	model.Name = "Shark"
	local body = buildPart("Body", Data.Meshes.Body)
	body.Parent = model
	local jaw = buildPart("Jaw", Data.Meshes.Jaw)
	jaw.Parent = model
	return {
		model = model,
		body = { { part = body, offset = CFrame.new(Data.Meshes.Body.Center) } },
		jaw = { { part = jaw, offset = CFrame.new(Data.Meshes.Jaw.Center) } },
		hinge = Data.Pivot,
	}
end

-- Builds the template now (yields while the meshes are built). Safe to call more than once.
function SharkModel.prepare()
	while building do
		task.wait()
	end
	if not template then
		building = true
		local ok, result = pcall(build)
		building = false
		if ok then
			template = result
		else
			warn("[SharkModel] couldn't build the shark kit mesh:", result)
		end
	end
end

-- A fresh copy of the shark at `scale` (1 = 14.6 studs nose to tail), or nil if it couldn't be built.
function SharkModel.get(scale: number): Shark?
	SharkModel.prepare()
	local t = template
	if not t then
		return nil
	end
	local model = t.model:Clone()
	local function copy(list: { Piece }): { Piece }
		local out = {}
		for _, piece in list do
			local part = model:FindFirstChild(piece.part.Name) :: BasePart
			part.Size = piece.part.Size * scale
			table.insert(
				out,
				{ part = part, offset = CFrame.new(piece.offset.Position * scale) * piece.offset.Rotation }
			)
		end
		return out
	end
	return { model = model, body = copy(t.body), jaw = copy(t.jaw), hinge = t.hinge * scale }
end

-- Positions the shark: sharkCFrame places its frame in the world; the jaw turns `open` radians about the kit's Jaw
-- pivot and axis (0 = closed, SharkModel.OPEN = fully open).
function SharkModel.place(shark: Shark, sharkCFrame: CFrame, open: number)
	for _, piece in shark.body do
		piece.part.CFrame = sharkCFrame * piece.offset
	end
	local jawFrame = sharkCFrame * CFrame.new(shark.hinge) * CFrame.fromAxisAngle(AXIS, open) * CFrame.new(-shark.hinge)
	for _, piece in shark.jaw do
		piece.part.CFrame = jawFrame * piece.offset
	end
end

return SharkModel
