-- Keyframed R15 body animation from tables of joint rotations, so taunts need no uploaded animation assets and play
-- the same on every client (from the client's scripter package; see "How this game plays it" below).
-- keys = { [jointName] = { {time, xDeg, yDeg, zDeg}, ... } }  -- rotations at the joint, keys sorted by time
-- Pose.run(character, duration, keys, extra?) -> stop()
--   extra(t) may return { [jointName] = CFrame } added on top of the keys (procedural wobbles, waves).
--
-- Joint axes (R15, character facing -Z): shoulders/hips +X swing the limb forward and up, shoulder +Z swings the
-- RIGHT arm out to the side (-Z for the left), elbows +X bend, knees -X bend, Neck/Waist +X tilt back, +Y turn left.
-- Between keys the pose eases in and out (smoothstep). The taunt blends in from whatever the character was doing over
-- BLEND_IN and back out to its normal animation over BLEND_OUT, so it starts and ends smoothly in idle.

local RunService = game:GetService("RunService")

local Pose = {}

local BLEND_IN, BLEND_OUT = 0.2, 0.45

Pose.JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightHip",
	"RightKnee",
	"RightAnkle",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
}

export type Keys = { [string]: { { number } } }

-- The character's joints by name (Motor6D or AnimationConstraint, whichever the avatar uses).
function Pose.joints(character: Model): { [string]: Instance }
	local joints = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and not joints[d.Name] then
			joints[d.Name] = d
		end
	end
	return joints
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function angles(k: { number }): CFrame
	return CFrame.Angles(math.rad(k[2]), math.rad(k[3]), math.rad(k[4]))
end

-- The joint rotation at time t from a track of keys.
function Pose.sample(track: { { number } }, t: number): CFrame
	local first, last = track[1], track[#track]
	if t <= first[1] then
		return angles(first)
	elseif t >= last[1] then
		return angles(last)
	end
	for i = 1, #track - 1 do
		local a, b = track[i], track[i + 1]
		if t <= b[1] then
			return angles(a):Lerp(angles(b), smooth((t - a[1]) / (b[1] - a[1])))
		end
	end
	return angles(last)
end

-- // How this game plays it: our rendered characters ignore Transform written from Luau (KeyframeClipTrack's header
-- // explains why), so the keys and extras are sampled at SAMPLE_RATE into a KeyframeSequence, built once per taunt
-- // (or per `variant`, for poses that depend on the character's size) in Shared.AnimationClips on this client, and
-- // played with KeyframeClipTrack, which fades it in over BLEND_IN and out over BLEND_OUT.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeClipTrack = require(ReplicatedStorage.Client.Core.KeyframeClipTrack)

local SAMPLE_RATE = 30 -- // Keyframes per second
local builtClips: { [string]: string } = {} -- // cache key -> KeyframeSequence name
local clipCount = 0

-- // The part a joint moves (the clip pose's name): Motor6D.Part1, or the AnimationConstraint's Attachment1 parent
local function jointPartName(joint: Instance): string?
	local j: any = joint
	if joint:IsA("Motor6D") then
		return j.Part1 and j.Part1.Name
	end
	local attachment = j.Attachment1
	return attachment and attachment.Parent and attachment.Parent.Name
end

-- // Same as KeyframeClipTrack's: clip translations are multiplied by it, so they're divided by it here
local function bodyScale(character: Model): Vector3
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local function scaleValue(name: string): number
		local value = humanoid and humanoid:FindFirstChild(name)
		return if value and value:IsA("NumberValue") then math.clamp(value.Value, 0.25, 3) else 1
	end
	return Vector3.new(scaleValue("BodyWidthScale"), scaleValue("BodyHeightScale"), scaleValue("BodyDepthScale"))
end

local function buildClip(character: Model, duration: number, keys: Keys, extra: ((t: number) -> { [string]: CFrame })?): string
	local joints = Pose.joints(character)
	local frameCount = math.ceil(duration * SAMPLE_RATE)
	-- // Every joint the keys or the extras ever touch gets a pose on every frame
	local names: { [string]: string } = {} -- // joint name -> part name
	local extras: { { [string]: CFrame } } = {}
	for i = 0, frameCount do
		local add = if extra then extra(math.min(i / SAMPLE_RATE, duration)) else {}
		extras[i] = add
		for name in add do
			names[name] = names[name] or (joints[name] and jointPartName(joints[name]))
		end
	end
	for name in keys do
		names[name] = names[name] or (joints[name] and jointPartName(joints[name]))
	end

	local scale = bodyScale(character)
	clipCount += 1
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = `TauntClip{clipCount}`
	sequence.Loop = false
	for i = 0, frameCount do
		local t = math.min(i / SAMPLE_RATE, duration)
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = t
		for name, partName in names do
			if partName == "HumanoidRootPart" then
				continue
			end
			local track = keys[name]
			local target = (if track then Pose.sample(track, t) else CFrame.identity) * (extras[i][name] or CFrame.identity)
			local pose = Instance.new("Pose")
			pose.Name = partName
			pose.CFrame = CFrame.new(target.Position / scale) * target.Rotation
			pose.Weight = 1
			pose.Parent = keyframe
		end
		keyframe.Parent = sequence
	end
	sequence.Parent = ReplicatedStorage.Shared:WaitForChild("AnimationClips")
	return sequence.Name
end

-- Plays the animation; returns a function that stops it early. It also stops if the character is removed or dies.
-- `variant` names a cached clip for poses that depend on the character (e.g. Nap Time's seat height); otherwise the
-- clip is cached per `keys` table.
function Pose.run(
	character: Model,
	duration: number,
	keys: Keys,
	extra: ((t: number) -> { [string]: CFrame })?,
	onDone: (() -> ())?,
	variant: string?
): () -> ()
	local cacheKey = variant or tostring(keys)
	local clipName = builtClips[cacheKey]
	if not clipName then
		clipName = buildClip(character, duration, keys, extra)
		builtClips[cacheKey] = clipName
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local track = KeyframeClipTrack.new(character, clipName, { Looped = false, LowerBodyWhileMoving = true })
	track:Play(BLEND_IN)
	local t0 = os.clock()
	local fadingOut = false
	local stopped = false
	local connection: RBXScriptConnection
	local function stop()
		if stopped then
			return
		end
		stopped = true
		connection:Disconnect()
		track:Destroy()
		if onDone then
			onDone()
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t >= duration or not character.Parent or (humanoid and humanoid.Health <= 0) then
			stop()
		elseif not fadingOut and t >= duration - BLEND_OUT then
			fadingOut = true
			track:Stop(BLEND_OUT)
		end
	end)
	return stop
end

return Pose
