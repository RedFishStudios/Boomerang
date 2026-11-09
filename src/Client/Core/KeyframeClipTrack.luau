--[[
	KeyframeClipTrack

	Plays unpublished animation data (a KeyframeSequence, e.g. from Shared/AnimationClips) on a character without an
	animation asset id. Mimics the AnimationTrack members AnimationController uses: Play(fadeIn), Stop(fadeOut),
	IsPlaying, Looped, Destroy() and GetMarkerReachedSignal(name).

	Every frame (PreSimulation), each joint named by the clip is blended from the Animator's pose (the joint's Transform)
	toward the clip's pose by Pose.Weight times the fade. Joints the clip doesn't name, or names with weight 0, keep the
	Animator's pose (so an upper-body clip leaves walking legs alone). Later clips apply over earlier ones.

	Writing Transform from Luau has no effect on rendered characters (anchored root; the engine only takes Transform from
	the Animator), so the blend goes through the joint's C0:
	C0 = restC0 * wantedPose * animatorPose:Inverse(), which the engine turns into restC0 * wantedPose. C0 returns to
	rest when no clip uses the joint. AnimationConstraint joints ignore this too, so the first clip played on a character
	converts its AnimationConstraints to equivalent Motor6Ds.

	Optional:
	  - an intro clip, played once before the main clip (which then loops if Looped)
	  - LowerBodyWhileMoving = false: while the character moves, the clip releases the hips and legs (the walk shows
	    through) and passes the hip turn up to the waist, so a full-body clip still reads while running.

	Poses are applied as authored, with translations scaled by the character's body scale. Easing: Constant holds; every
	other style plays linear (all clips are linear).
	Each client runs this for every character it renders.
]]

local KeyframeClipTrack = {}
KeyframeClipTrack.__index = KeyframeClipTrack

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Shared.Classes.Signal)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CLIPS_FOLDER_NAME = "AnimationClips" -- // ReplicatedStorage.Shared.AnimationClips

local LOWER_BODY_JOINTS = {
	LowerTorso = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
}

local CONVERTED_JOINT_ATTRIBUTE = "ConvertedFromAnimationConstraint"

local MOVING_FULL_SPEED = 4 -- // Studs/second at which a character counts as fully moving (lower body fully released)
local MOVING_RESPONSE = 12 -- // How fast the moving amount follows speed (per second)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type JointKeys = {
	Times: { number },
	CFrames: { CFrame },
	Weights: { number },
	Holds: { boolean }, -- // Constant easing: hold this key's pose until the next key
}

type Marker = { Name: string, Time: number }

type CompiledClip = {
	Name: string,
	Length: number,
	Looped: boolean,
	Joints: { [string]: JointKeys },
	Markers: { Marker },
}

type RigState = {
	Character: Model,
	Root: BasePart?,
	Motors: { [string]: Motor6D },
	RestC0: { [Motor6D]: CFrame },
	Bent: { [Motor6D]: true }, -- // Joints whose C0 is currently off rest
	Scale: Vector3,
	Tracks: { any }, -- // KeyframeClipTrack, in play order
	LastRootPosition: Vector3?,
	MovingAmount: number,
}

export type KeyframeClipTrack = typeof(setmetatable(
	{} :: {
		Name: string,
		Character: Model,
		Looped: boolean,
		IsPlaying: boolean,
		Length: number,
		TimePosition: number,
		Speed: number,
		_intro: CompiledClip?,
		_clip: CompiledClip,
		_inIntro: boolean,
		_fade: number,
		_fadeRate: number,
		_stopping: boolean,
		_lowerBodyWhileMoving: boolean,
		_markerSignals: { [string]: any },
		_destroyed: boolean,
	},
	KeyframeClipTrack
))

export type Options = {
	IntroClip: string?,
	Looped: boolean?,
	LowerBodyWhileMoving: boolean?, -- // Default true
	Speed: number?, -- // Playback rate (default 1)
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local compiledClips: { [KeyframeSequence]: CompiledClip } = {}
local rigs: { [Model]: RigState } = {}
local stepConnection: RBXScriptConnection? = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function compileClip(sequence: KeyframeSequence): CompiledClip
	local cached = compiledClips[sequence]
	if cached then
		return cached
	end

	local keyframes = sequence:GetKeyframes() :: { Keyframe }
	table.sort(keyframes, function(a, b)
		return a.Time < b.Time
	end)

	local joints: { [string]: JointKeys } = {}
	local markers: { Marker } = {}
	local length = 0

	for _, keyframe in keyframes do
		length = math.max(length, keyframe.Time)
		for _, descendant in keyframe:GetDescendants() do
			if descendant:IsA("Pose") then
				if descendant.Name == "HumanoidRootPart" then
					continue -- // The root is never animated (only a hierarchy container)
				end
				local keys = joints[descendant.Name]
				if not keys then
					keys = { Times = {}, CFrames = {}, Weights = {}, Holds = {} }
					joints[descendant.Name] = keys
				end
				table.insert(keys.Times, keyframe.Time)
				table.insert(keys.CFrames, descendant.CFrame)
				table.insert(keys.Weights, descendant.Weight)
				table.insert(keys.Holds, descendant.EasingStyle == Enum.PoseEasingStyle.Constant)
			elseif descendant:IsA("KeyframeMarker") then
				table.insert(markers, { Name = descendant.Name, Time = keyframe.Time })
			end
		end
	end

	local clip: CompiledClip = {
		Name = sequence.Name,
		Length = length,
		Looped = sequence.Loop,
		Joints = joints,
		Markers = markers,
	}
	compiledClips[sequence] = clip
	return clip
end

local function findClip(clipName: string): CompiledClip
	local folder = ReplicatedStorage.Shared:WaitForChild(CLIPS_FOLDER_NAME)
	local sequence = folder:WaitForChild(clipName, 5)
	assert(sequence and sequence:IsA("KeyframeSequence"), `KeyframeClipTrack: no KeyframeSequence named {clipName} in Shared.{CLIPS_FOLDER_NAME}`)
	return compileClip(sequence :: KeyframeSequence)
end

local function sampleJoint(keys: JointKeys, t: number): (CFrame, number)
	local times = keys.Times
	local count = #times
	if t <= times[1] or count == 1 then
		return keys.CFrames[1], keys.Weights[1]
	end
	if t >= times[count] then
		return keys.CFrames[count], keys.Weights[count]
	end
	for i = 2, count do
		if t <= times[i] then
			local previous = i - 1
			if keys.Holds[previous] then
				return keys.CFrames[previous], keys.Weights[previous]
			end
			local alpha = (t - times[previous]) / math.max(times[i] - times[previous], 1e-6)
			local weight = keys.Weights[previous] + (keys.Weights[i] - keys.Weights[previous]) * alpha
			return keys.CFrames[previous]:Lerp(keys.CFrames[i], alpha), weight
		end
	end
	return keys.CFrames[count], keys.Weights[count]
end

local function getBodyScale(character: Model): Vector3
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local function scaleValue(name: string): number
		local value = humanoid and humanoid:FindFirstChild(name)
		return if value and value:IsA("NumberValue") then math.clamp(value.Value, 0.25, 3) else 1
	end
	return Vector3.new(scaleValue("BodyWidthScale"), scaleValue("BodyHeightScale"), scaleValue("BodyDepthScale"))
end

-- // Converts an AnimationConstraint to the equivalent Motor6D (same parts, offsets, name and parent)
local function convertToMotor(constraint: AnimationConstraint): Motor6D?
	local attachment0, attachment1 = constraint.Attachment0, constraint.Attachment1
	if not attachment0 or not attachment1 then
		return nil
	end
	local part0, part1 = attachment0.Parent, attachment1.Parent
	if not part0 or not part0:IsA("BasePart") or not part1 or not part1:IsA("BasePart") then
		return nil
	end
	local motor = Instance.new("Motor6D")
	motor.Name = constraint.Name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = attachment0.CFrame
	motor.C1 = attachment1.CFrame
	motor:SetAttribute(CONVERTED_JOINT_ATTRIBUTE, true) -- // So the ragdoll frees it like the constraint
	local parent = constraint.Parent
	constraint:Destroy()
	motor.Parent = parent
	return motor
end

local function bindRig(character: Model): RigState
	local motors: { [string]: Motor6D } = {}
	local restC0: { [Motor6D]: CFrame } = {}
	for _, descendant in character:GetDescendants() do
		local motor: Motor6D? = nil
		if descendant:IsA("Motor6D") then
			motor = descendant
		elseif descendant:IsA("AnimationConstraint") then
			motor = convertToMotor(descendant)
		end
		if motor and motor.Part1 then
			motors[motor.Part1.Name] = motor
			restC0[motor] = motor.C0
		end
	end
	return {
		Character = character,
		Root = (character:FindFirstChild("HumanoidRootPart") :: BasePart?) or character.PrimaryPart,
		Motors = motors,
		RestC0 = restC0,
		Bent = {},
		Scale = getBodyScale(character),
		Tracks = {},
		LastRootPosition = nil,
		MovingAmount = 0,
	}
end

local function fireMarkers(track: KeyframeClipTrack, clip: CompiledClip, fromTime: number, toTime: number)
	for _, marker in clip.Markers do
		if marker.Time > fromTime and marker.Time <= toTime then
			local signal = track._markerSignals[marker.Name]
			if signal then
				task.spawn(signal.Fire, signal)
			end
		end
	end
end

-- // Advances the track's clock. Returns false once a non-looping track passes its end.
local function advance(track: KeyframeClipTrack, dt: number): boolean
	local delta = dt * track.Speed
	local intro = track._intro
	if track._inIntro and intro then
		local previous = track.TimePosition
		track.TimePosition += delta
		fireMarkers(track, intro, previous, math.min(track.TimePosition, intro.Length))
		if track.TimePosition < intro.Length then
			return true
		end
		track._inIntro = false
		delta = track.TimePosition - intro.Length
		track.TimePosition = 0
		fireMarkers(track, track._clip, -1, 0) -- // The main clip's first-frame markers
	end

	local clip = track._clip
	local previous = track.TimePosition
	track.TimePosition += delta
	if track.Looped and clip.Length > 0 then
		while track.TimePosition > clip.Length do
			fireMarkers(track, clip, previous, clip.Length)
			track.TimePosition -= clip.Length
			previous = -1
		end
		fireMarkers(track, clip, previous, track.TimePosition)
		return true
	end
	fireMarkers(track, clip, previous, math.min(track.TimePosition, clip.Length))
	return track.TimePosition < clip.Length
end

local function updateMovingAmount(rig: RigState, dt: number)
	local root = rig.Root
	if not root or dt <= 0 then
		return
	end
	local position = root.Position
	local speed = 0
	if rig.LastRootPosition then
		local offset = position - rig.LastRootPosition
		speed = Vector3.new(offset.X, 0, offset.Z).Magnitude / dt
	end
	rig.LastRootPosition = position
	local target = math.clamp(speed / MOVING_FULL_SPEED, 0, 1)
	rig.MovingAmount += (target - rig.MovingAmount) * math.min(1, dt * MOVING_RESPONSE)
end

local function stepRig(rig: RigState, dt: number)
	updateMovingAmount(rig, dt)

	-- // Each touched joint's wanted pose, starting from the Animator's pose (Transform), layered by every track
	local wanted: { [Motor6D]: CFrame } = {}
	for _, track in rig.Tracks do
		local clip = if track._inIntro then track._intro else track._clip
		if not clip then
			continue
		end
		local fade = track._fade
		local letGoOfLowerBody = if track._lowerBodyWhileMoving then 0 else rig.MovingAmount
		for jointName, keys in clip.Joints do
			local motor = rig.Motors[jointName]
			if not motor then
				continue
			end
			local pose, weight = sampleJoint(keys, track.TimePosition)
			if LOWER_BODY_JOINTS[jointName] then
				weight *= 1 - letGoOfLowerBody
			elseif jointName == "UpperTorso" and letGoOfLowerBody > 0 then
				-- // Hips don't turn while moving; the waist keeps the clip's body turn
				local hipKeys = clip.Joints.LowerTorso
				if hipKeys then
					local hipPose = sampleJoint(hipKeys, track.TimePosition)
					pose = CFrame.identity:Lerp(hipPose.Rotation, letGoOfLowerBody) * pose
				end
			end
			weight = math.min(weight * fade, 1)
			if weight <= 0 then
				continue
			end
			local scaled = CFrame.new(pose.Position * rig.Scale) * pose.Rotation
			local base = wanted[motor] or motor.Transform
			wanted[motor] = base:Lerp(scaled, weight)
		end
	end

	for motor, pose in wanted do
		motor.C0 = rig.RestC0[motor] * pose * motor.Transform:Inverse()
		rig.Bent[motor] = true
	end
	-- // Joints no clip poses this frame return to rest
	for motor in rig.Bent do
		if not wanted[motor] then
			motor.C0 = rig.RestC0[motor]
			rig.Bent[motor] = nil
		end
	end
end

local function onPreSimulation(dt: number)
	for character, rig in rigs do
		if not character.Parent then
			rigs[character] = nil
			continue
		end

		for index = #rig.Tracks, 1, -1 do
			local track = rig.Tracks[index]
			track._fade = math.clamp(track._fade + track._fadeRate * dt, 0, 1)
			local running = advance(track, dt)
			if not running and not track._stopping then
				track:Stop(0) -- // Reached its end
			end
			if track._stopping and track._fade <= 0 then
				track.IsPlaying = false
				table.remove(rig.Tracks, index)
			end
		end

		stepRig(rig, dt)

		if #rig.Tracks == 0 then
			rigs[character] = nil -- // Joints returned to rest on this last step (keeps its Motor6Ds)
		end
	end

	if next(rigs) == nil and stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

local function ensureStepping()
	if not stepConnection then
		stepConnection = RunService.PreSimulation:Connect(onPreSimulation)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function KeyframeClipTrack.new(character: Model, clipName: string, options: Options?): KeyframeClipTrack
	local clip = findClip(clipName)
	local intro = if options and options.IntroClip then findClip(options.IntroClip) else nil
	local looped = if options and options.Looped ~= nil then options.Looped else clip.Looped

	local self = setmetatable({
		Name = clipName,
		Character = character,
		Looped = looped,
		IsPlaying = false,
		Length = clip.Length,
		TimePosition = 0,
		Speed = if options and options.Speed then options.Speed else 1,
		_intro = intro,
		_clip = clip,
		_inIntro = false,
		_fade = 0,
		_fadeRate = 0,
		_stopping = false,
		_lowerBodyWhileMoving = if options and options.LowerBodyWhileMoving ~= nil then options.LowerBodyWhileMoving else true,
		_markerSignals = {},
		_destroyed = false,
	}, KeyframeClipTrack)
	return self
end

function KeyframeClipTrack.Play(self: KeyframeClipTrack, fadeTime: number?, _weight: number?, speed: number?)
	if self._destroyed or not self.Character.Parent then
		return
	end
	local fade = fadeTime or 0.1

	local rig = rigs[self.Character]
	if not rig then
		rig = bindRig(self.Character)
		rigs[self.Character] = rig
	end

	-- // Restart from the beginning, on top of anything else playing
	local index = table.find(rig.Tracks, self)
	if index then
		table.remove(rig.Tracks, index)
	end
	table.insert(rig.Tracks, self)

	self.Speed = speed or self.Speed
	self.TimePosition = 0
	self._inIntro = self._intro ~= nil
	self._stopping = false
	self._fade = if fade > 0 then (if self.IsPlaying then self._fade else 0) else 1
	self._fadeRate = if fade > 0 then 1 / fade else 0
	self.IsPlaying = true
	fireMarkers(self, if self._inIntro then self._intro :: CompiledClip else self._clip, -1, 0)
	ensureStepping()
end

function KeyframeClipTrack.Stop(self: KeyframeClipTrack, fadeTime: number?)
	if not self.IsPlaying or self._stopping then
		return
	end
	local fade = fadeTime or 0.1
	self._stopping = true
	if fade > 0 then
		self._fadeRate = -1 / fade
	else
		self._fade = 0
		self._fadeRate = 0
	end
	-- // IsPlaying turns false (and the track leaves its character) when the fade-out finishes
end

function KeyframeClipTrack.AdjustSpeed(self: KeyframeClipTrack, speed: number)
	self.Speed = speed
end

function KeyframeClipTrack.GetMarkerReachedSignal(self: KeyframeClipTrack, markerName: string)
	local signal = self._markerSignals[markerName]
	if not signal then
		signal = Signal.new()
		self._markerSignals[markerName] = signal
	end
	return signal
end

function KeyframeClipTrack.Destroy(self: KeyframeClipTrack)
	if self._destroyed then
		return
	end
	self._destroyed = true
	local rig = rigs[self.Character]
	if rig then
		local index = table.find(rig.Tracks, self)
		if index then
			-- // Leaves on the next step, so its joints return to rest
			self._stopping = true
			self._fade = 0
			self._fadeRate = 0
		end
	end
	self.IsPlaying = false
	for _, signal in self._markerSignals do
		signal:Destroy()
	end
	table.clear(self._markerSignals)
end

-------------------------------------------------------------------------------
-- RETURN
-------------------------------------------------------------------------------

return KeyframeClipTrack
