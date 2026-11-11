-- Freezes a dying character: hides the real one (locally) and returns a copy locked in its exact pose.
--
-- Every part of the copy is anchored where it was, so the pose can't change and the body can't fall apart. This
-- works whatever the rig uses for joints (Motor6D, or the AnimationConstraint + BallSocket joints of current R15
-- avatars). The skeleton (which part hangs off which, and each joint's pivot) is remembered so an effect can still
-- bend the frozen body kinematically with Rig.pose.

local RunService = game:GetService("RunService")

local Rig = {}

type Link = {
	parent: BasePart,
	-- The child's CFrame relative to its parent, split at the joint pivot so a rotation can be inserted there.
	toPivot: CFrame, -- parent space -> pivot
	fromPivot: CFrame, -- pivot -> child
	joint: string?, -- joint name (e.g. "RightShoulder"); nil for rigid attachments such as accessories
}

export type Frozen = {
	model: Model,
	parts: { BasePart }, -- every visible part, including accessory handles
	root: BasePart,
	feetY: number, -- world height of the lowest part's bottom
	topY: number, -- world height of the highest part's top
	links: { [BasePart]: Link },
	order: { BasePart }, -- parents before children
	rest: { [BasePart]: CFrame }, -- frozen pose
}

local VISUAL_CLUTTER = {
	"Script",
	"LocalScript",
	"ModuleScript",
	"Animator",
	"Sound",
	"ForceField",
	"BillboardGui",
	"SurfaceGui",
	"ParticleEmitter",
	"Trail",
	"Beam",
	"Light",
	"Fire",
	"Smoke",
	"Sparkles",
	"Highlight",
}

local function isClutter(inst: Instance): boolean
	for _, className in VISUAL_CLUTTER do
		if inst:IsA(className) then
			return true
		end
	end
	return false
end

-- Hides the original character on this client only.
function Rig.hide(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
			d.Enabled = false
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
end

-- Pose snapshots keyed by character. Unused here: the package filled it from Humanoid.Died on player.Character, but
-- our visible body is CharacterRenderController's model, which keeps its pose because the ragdoll is skipped.
type Snapshot = { time: number, cframes: { [string]: CFrame } }
local snapshots: { [Model]: Snapshot } = setmetatable({}, { __mode = "k" }) :: any

-- Path of a part inside its character ("RightUpperArm", "HatAccessory.Handle"), with a counter for duplicates.
local function partPaths(model: Model): { [BasePart]: string }
	local paths: { [BasePart]: string } = {}
	local seen: { [string]: number } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local names = {}
			local node: Instance? = d
			while node and node ~= model do
				table.insert(names, 1, node.Name)
				node = node.Parent
			end
			local key = table.concat(names, ".")
			seen[key] = (seen[key] or 0) + 1
			paths[d] = key .. "#" .. seen[key]
		end
	end
	return paths
end

-- Reads every joint as (parent part, child part, pivot in world space, name), using the `rest` pose.
local function readJoints(
	model: Model,
	rest: { [BasePart]: CFrame }
): { { parent: BasePart, child: BasePart, pivot: CFrame, name: string?, rigid: boolean } }
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 and rest[d.Part1] then
			table.insert(
				joints,
				{ parent = d.Part0, child = d.Part1, pivot = rest[d.Part1] * d.C1, name = d.Name, rigid = false }
			)
		elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			local p0, p1 = d.Attachment0.Parent, d.Attachment1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") and rest[p1] then
				table.insert(
					joints,
					{ parent = p0, child = p1, pivot = rest[p1] * d.Attachment1.CFrame, name = d.Name, rigid = false }
				)
			end
		elseif (d:IsA("Weld") or d:IsA("ManualWeld") or d:IsA("WeldConstraint")) and d.Part0 and d.Part1 then
			if rest[d.Part1] then
				table.insert(joints, { parent = d.Part0, child = d.Part1, pivot = rest[d.Part1], rigid = true })
			end
		elseif d:IsA("RigidConstraint") and d.Attachment0 and d.Attachment1 then
			local p0, p1 = d.Attachment0.Parent, d.Attachment1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") and rest[p1] then
				table.insert(joints, { parent = p0, child = p1, pivot = rest[p1], rigid = true })
			end
		end
	end
	return joints
end

function Rig.freeze(character: Model, parent: Instance): Frozen?
	if not character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	-- The pose: the snapshot taken at the instant of death if there is one (it's what the player saw), else now.
	local snapshot = snapshots[character]
	if snapshot and os.clock() - snapshot.time > 5 then
		snapshot = nil
	end

	local wasArchivable = character.Archivable
	character.Archivable = true
	local model = character:Clone()
	character.Archivable = wasArchivable
	if not model then
		return nil
	end
	Rig.hide(character)

	model.Name = character.Name .. "_ElimEffect"
	for _, d in model:GetDescendants() do
		if isClutter(d) then
			d:Destroy()
		end
	end

	-- Record the frozen pose and the skeleton, then remove every joint/constraint and place and anchor each part,
	-- so nothing can move it.
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local rest: { [BasePart]: CFrame } = {}
	for part, key in partPaths(model) do
		rest[part] = (snapshot and snapshot.cframes[key]) or part.CFrame
	end
	local links: { [BasePart]: Link } = {}
	for _, j in readJoints(model, rest) do
		if links[j.child] == nil and j.child ~= root and rest[j.parent] then
			links[j.child] = {
				parent = j.parent,
				toPivot = rest[j.parent]:Inverse() * j.pivot,
				fromPivot = j.pivot:Inverse() * rest[j.child],
				joint = if j.rigid then nil else j.name,
			}
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	for part, cf in rest do
		part.Anchored = true
		part.CFrame = cf
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.EvaluateStateMachine = false -- no walking, standing up or ragdolling
		humanoid.Health = humanoid.MaxHealth
	end

	local parts: { BasePart } = {}
	local feetY, topY = math.huge, -math.huge
	for part in rest do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if part ~= root and part.Transparency < 1 then
			table.insert(parts, part)
			local half = part.Size.Y / 2
			feetY = math.min(feetY, part.Position.Y - half)
			topY = math.max(topY, part.Position.Y + half)
		end
	end

	-- Parents before children, so Rig.pose can walk down the skeleton in one pass.
	local order: { BasePart } = {}
	local placed: { [BasePart]: boolean } = {}
	local function place(part: BasePart, depth: number)
		if placed[part] or depth > 64 then
			return
		end
		local link = links[part]
		if link then
			place(link.parent, depth + 1)
		end
		placed[part] = true
		table.insert(order, part)
	end
	for part in rest do
		place(part, 0)
	end

	model.Parent = parent
	return {
		model = model,
		parts = parts,
		root = root,
		feetY = feetY,
		topY = topY,
		links = links,
		order = order,
		rest = rest,
	}
end

-- Bends the frozen body: `rotations` maps joint names to a rotation in that joint's own frame. Children (forearm,
-- hand, accessories) follow their parents. alpha 0 = frozen pose, 1 = full rotation.
function Rig.pose(frozen: Frozen, rotations: { [string]: CFrame }, alpha: number, offset: CFrame?)
	local world: { [BasePart]: CFrame } = {}
	for _, part in frozen.order do
		local link = frozen.links[part]
		if not link or not world[link.parent] then
			world[part] = (offset or CFrame.new()) * frozen.rest[part]
		else
			local bend = if link.joint and rotations[link.joint]
				then CFrame.new():Lerp(rotations[link.joint], alpha)
				else CFrame.new()
			world[part] = world[link.parent] * link.toPivot * bend * link.fromPivot
		end
		if part.Parent then
			part.CFrame = world[part]
		end
	end
end

-- Tweens Rig.pose from 0 to 1 over `seconds` with an overshoot ease (a quick, readable reaction).
function Rig.animate(frozen: Frozen, rotations: { [string]: CFrame }, seconds: number)
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - start) / seconds, 0, 1)
		-- easeOutBack
		local c1, c3 = 1.70158, 2.70158
		local eased = 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
		if frozen.model.Parent then
			Rig.pose(frozen, rotations, eased)
		end
		if t >= 1 or not frozen.model.Parent then
			connection:Disconnect()
		end
	end)
end

return Rig
