-- "Stone Statue" elimination effect, exactly 3 seconds.
--   0.000-0.375  The pose freezes at once; grey stone coats the whole avatar from the feet up.
--   0.375-1.875  Statue hold: completely still (every part anchored).
--   1.875-3.000  Soft grey dust dissolve, top to bottom; dust pushes outward round the whole body so it reads from
--                above; every particle is gone by 3.000.
-- Colours, crack placement and particle counts are fixed, so it looks the same on every death. The stone and
-- cracks cover the top surfaces too (head, shoulders, upper arms, hats), for the elevated gameplay camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Constants.ElimEffectAssets)
local Fx = require(script.Parent:WaitForChild("Fx"))
local Rig = require(script.Parent:WaitForChild("Rig"))


local STONE = Color3.fromRGB(128, 127, 123) -- medium grey
local STONE_FRESH = Color3.fromRGB(176, 175, 170) -- the coating starts lighter and settles to STONE
local STONE_MATERIAL = Enum.Material.Concrete -- matte, subtly rough, broad tonal variation
local FACE_TINT = Color3.fromRGB(78, 77, 74) -- face decal stays as a faint carved detail
local DUST = Color3.fromRGB(152, 150, 145)

local COAT_END = 0.375
local COAT_SWEEP = 0.33 -- feet-to-head sweep; the last part settles by COAT_END
local HOLD_END = 1.875
local DISSOLVE_STAGGER = 0.15 -- head starts first, feet last
local FADE_TIME = 0.6 -- per part; the last part is gone by HOLD_END + DISSOLVE_STAGGER + FADE_TIME = 2.625
local END = 3.0

-- Crack faces, fixed per body part. Top faces are included so cracks read from overhead.
local CRACKS = {
	Head = { Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Top },
	UpperTorso = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Top },
	LeftUpperArm = { Enum.NormalId.Left, Enum.NormalId.Front, Enum.NormalId.Top },
	RightUpperArm = { Enum.NormalId.Right, Enum.NormalId.Top },
	LeftLowerArm = { Enum.NormalId.Front },
	RightLowerArm = { Enum.NormalId.Back, Enum.NormalId.Right },
}
local ACCESSORY_CRACKS = { Enum.NormalId.Top, Enum.NormalId.Front } -- hats, hair and other accessories

local function petrify(part: BasePart)
	part.Material = STONE_MATERIAL
	part.Color = STONE_FRESH
	if part:IsA("MeshPart") then
		part.TextureID = ""
	end
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		elseif child:IsA("SpecialMesh") then
			child.TextureId = ""
			child.VertexColor = Vector3.one
		elseif child:IsA("Decal") then
			child.Color3 = FACE_TINT
			child.Transparency = math.max(child.Transparency, 0.55)
		end
	end
	local faces = CRACKS[part.Name]
	if not faces and part.Parent and part.Parent:IsA("Accessory") then
		faces = ACCESSORY_CRACKS
	end
	for _, face in faces or {} do
		local crack = Instance.new("Decal")
		crack.Name = "StoneCrack"
		crack.Texture = Art.Cracks
		crack.Face = face
		crack.Transparency = 0.2
		crack.Parent = part
	end
	Fx.tween(part, 0.12, { Color = STONE })
end

-- Dust leaves the part outward and slightly up, slows in the air, then sinks; lifetimes end before END.
local function dissolve(part: BasePart, index: number, startTime: number)
	local volume = part.Size.X * part.Size.Y * part.Size.Z
	local life = math.min(0.85, END - startTime - 0.05)
	local dust = Fx.emitter(part, {
		Texture = Art.Puff,
		Color = ColorSequence.new(DUST),
		Size = Fx.seq(0, 0.55, 1, 1.25),
		Transparency = Fx.seq(0, 0.4, 0.7, 0.7, 1, 1),
		Lifetime = NumberRange.new(life),
		Speed = NumberRange.new(2.4),
		SpreadAngle = Vector2.new(85, 85),
		Acceleration = Vector3.new(0, -3, 0),
		Drag = 2.5,
		Rotation = NumberRange.new((index * 53) % 360),
	})
	local chips = Fx.emitter(part, {
		Texture = Art.Flake,
		Color = ColorSequence.new(Color3.fromRGB(112, 111, 107)),
		Size = NumberSequence.new(0.14),
		Transparency = Fx.seq(0, 0, 0.8, 0, 1, 1),
		Lifetime = NumberRange.new(math.min(0.6, life)),
		Speed = NumberRange.new(2),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -30, 0),
		Rotation = NumberRange.new((index * 47) % 360),
	})
	local detail = Fx.detail(part.Position)
	dust:Emit(math.max(1, math.floor(math.clamp(math.floor(volume * 1.6), 2, 6) * detail)))
	chips:Emit(math.max(1, math.floor(math.clamp(math.floor(volume), 1, 3) * detail)))

	Fx.tween(part, FADE_TIME, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	for _, child in part:GetChildren() do
		if child:IsA("Decal") then
			Fx.tween(child, FADE_TIME, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		end
	end
end

return function(character: Model, parent: Instance)
	local frozen = Rig.freeze(character, parent) -- the pose is locked from this instant
	if not frozen then
		return
	end
	local t0 = os.clock()
	local model = frozen.model
	local height = math.max(frozen.topY - frozen.feetY, 0.1)
	local center = Vector3.new(frozen.root.Position.X, frozen.feetY, frozen.root.Position.Z)
	local host = Fx.host(model, CFrame.new(center + Vector3.new(0, 0.1, 0)), Vector3.new(2, 0.2, 2))

	-- Sound: deep heavy SWOOSH over the coating (loudest), stone grind under it, muted impact when it's done.
	Fx.sound(host, Art.Swoosh, 1.6, 0.72, t0, 2.6)
	Fx.sound(host, Art.StoneGrind, 0.45, 1.1, t0, 0.8)
	Fx.at(t0, COAT_END, function()
		Fx.sound(host, Art.StoneClunk, 0.9, 0.85, t0, 2.4)
	end)

	-- Petrification: stone sweeps from the feet to the head, with a small dust ring at the base.
	local base = Fx.emitter(host, {
		Texture = Art.Puff,
		Color = ColorSequence.new(Color3.fromRGB(165, 163, 158)),
		Size = Fx.seq(0, 0.6, 1, 1.5),
		Transparency = Fx.seq(0, 0.5, 1, 1),
		Lifetime = NumberRange.new(0.5),
		Speed = NumberRange.new(3.5),
		SpreadAngle = Vector2.new(88, 88),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -3, 0),
		Drag = 4,
	})
	base:Emit(8)
	for _, part in frozen.parts do
		local mid = (part.Position.Y - frozen.feetY) / height
		Fx.at(t0, COAT_SWEEP * math.clamp(mid, 0, 1), function()
			petrify(part)
		end)
	end
	-- Clothing graphics go once the coating has reached the torso; the shapes stay as plain stone.
	Fx.at(t0, COAT_SWEEP * 0.4, function()
		for _, d in model:GetChildren() do
			if d:IsA("Clothing") or d:IsA("ShirtGraphic") then
				d:Destroy()
			end
		end
	end)

	-- Dissolve: head first, feet last.
	Fx.at(t0, HOLD_END, function()
		Fx.sound(host, Art.StoneCrumble, 0.45, 1, t0, 2.75)
		for index, part in frozen.parts do
			local fromTop = 1 - math.clamp((part.Position.Y - frozen.feetY) / height, 0, 1)
			local start = HOLD_END + DISSOLVE_STAGGER * fromTop
			Fx.at(t0, start, function()
				dissolve(part, index, start)
			end)
		end
		-- A low ring of dust rolling outward from the base: the dissolve's main read from overhead.
		local spread = Fx.emitter(host, {
			Texture = Art.Puff,
			Color = ColorSequence.new(DUST),
			Size = Fx.seq(0, 0.9, 1, 2),
			Transparency = Fx.seq(0, 0.45, 0.7, 0.75, 1, 1),
			Lifetime = NumberRange.new(0.75),
			Speed = NumberRange.new(4.5),
			SpreadAngle = Vector2.new(89, 89),
			EmissionDirection = Enum.NormalId.Top,
			Drag = 3,
			Rotation = NumberRange.new(30),
		})
		Fx.at(t0, 2.15, function()
			spread:Emit(10)
		end)
	end)

	Fx.at(t0, END, function()
		model:Destroy()
	end)
end
