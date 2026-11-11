--[[
	SharkRig (helper for the SharkAttack effect)

	Description:
	The shark model imported from the client's shark kit (Shared/Assets/StrikeEffects/Shark: one skinned MeshPart with
	bones Root > Jaw), driven with the same API as the package's runtime-built SharkModel, so SharkAttack is unchanged.

	The "kit frame" is the package's shark frame: +Z towards the nose, +Y up the back, +X sideways, origin at the Root
	bone, 14.55 studs nose to tail at scale 1. The imported model was rescaled to that size in Studio (Model scale
	0.02551) and its Root bone is that origin, with the nose along the bone's +X and the back along +Y.
	The jaw opens by turning the Jaw bone about the kit's X axis (see JAW_OPEN_SIGN if it ever opens the wrong way).

	local shark = SharkRig.get(scale)          -- { model, part, root, jaw } or nil
	SharkRig.place(shark, kitCFrame, open)     -- open: 0 = shut, SharkRig.OPEN = fully open
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharkRig = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Shark = { model: Model, part: BasePart, root: Bone, jaw: Bone }

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // From the package's kit data (SharkKitData), in kit-frame studs at scale 1
local OPEN_DEGREES = 43 -- // The kit's fully open jaw
local JAW_PIVOT = Vector3.new(0, 0.08959, -0.05119) -- // The Jaw bone's head
local MOUTH = { Seam = 0.34078, HalfWidth = 2.90605, Reach = 6.13248 } -- // Mouth interior with the jaw shut

-- // The kit frame's axes in the Root bone's space: kit +X = bone -Z, kit +Y = bone +Y, kit +Z (nose) = bone +X
local KIT_IN_ROOT = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
local ROOT_IN_KIT = KIT_IN_ROOT:Inverse()
local JAW_AXIS = Vector3.new(0, 0, -1) -- // The kit's +X (the hinge axis), in the Jaw bone's space
local JAW_OPEN_SIGN = 1 -- // Flip to -1 if the jaw opens upwards into the head

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SharkRig.OPEN = math.rad(OPEN_DEGREES)
SharkRig.MOUTH = MOUTH

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getTemplate(): Model?
	local folder = ReplicatedStorage.Shared.Assets:FindFirstChild("StrikeEffects")
	local template = folder and folder:FindFirstChild("Shark")
	return if template and template:IsA("Model") then template else nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The mouth's frame (kit frame, scale 1) with the jaw `open` radians: origin where palate and tongue meet at the
-- // hinge, +Y along the middle of the open mouth (pointing out towards the lips), +Z out of the opening on the jaw
-- // side, +X sideways. A swallowed player stands along +Y, centred in the cavity. (Same as the package's.)
function SharkRig.mouthFrame(open: number): CFrame
	local half = CFrame.fromAxisAngle(Vector3.xAxis, open / 2)
	local along = half:VectorToWorldSpace(Vector3.zAxis)
	local out = half:VectorToWorldSpace(-Vector3.yAxis)
	return CFrame.fromMatrix(Vector3.new(0, MOUTH.Seam, JAW_PIVOT.Z), along:Cross(out), along, out)
end

-- // A fresh, anchored, non-colliding copy of the shark at `scale` (1 = 14.55 studs nose to tail), or nil if the
-- // model is missing
function SharkRig.get(scale: number): Shark?
	local template = getTemplate()
	if not template then
		warn("SharkRig: Shared/Assets/StrikeEffects/Shark is missing")
		return nil
	end
	local model = template:Clone()
	model.Name = "Shark"
	model:ScaleTo(template:GetScale() * scale)

	local part: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			part = part or descendant
		end
	end
	local root = part and part:FindFirstChild("Root", true)
	local jaw = root and root:FindFirstChild("Jaw", true)
	if not (part and root and root:IsA("Bone") and jaw and jaw:IsA("Bone")) then
		warn("SharkRig: the shark model needs a MeshPart with bones Root > Jaw")
		model:Destroy()
		return nil
	end
	return { model = model, part = part, root = root, jaw = jaw }
end

-- // Places the shark: kitCFrame puts the kit frame in the world; the jaw turns `open` radians (0 = shut)
function SharkRig.place(shark: Shark, kitCFrame: CFrame, open: number)
	local rootWorld = kitCFrame * ROOT_IN_KIT
	shark.part.CFrame = rootWorld * shark.root.CFrame:Inverse()
	shark.jaw.Transform = CFrame.fromAxisAngle(JAW_AXIS, open * JAW_OPEN_SIGN)
end

return SharkRig
