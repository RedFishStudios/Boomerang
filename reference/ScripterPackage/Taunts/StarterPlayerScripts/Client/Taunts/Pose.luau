-- Keyframed R15 body animation written straight into the character's joints (Motor6D or AnimationConstraint
-- Transform), so taunts need no uploaded animation assets and play the same on every client.
--
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

-- Plays the animation; returns a function that stops it early. It also stops if the character is removed or dies.
function Pose.run(
	character: Model,
	duration: number,
	keys: Keys,
	extra: ((t: number) -> { [string]: CFrame })?,
	onDone: (() -> ())?
): () -> ()
	local joints = Pose.joints(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local t0 = os.clock()
	local connection: RBXScriptConnection
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		connection:Disconnect()
		if onDone then
			onDone()
		end
	end
	-- Stepped runs after the Animator has posed the joints, so writing Transform here overrides it for this frame.
	connection = RunService.Stepped:Connect(function()
		local t = os.clock() - t0
		if t >= duration or not character.Parent or (humanoid and humanoid.Health <= 0) then
			stop()
			return
		end
		local weight = smooth(t / BLEND_IN) * (1 - smooth((t - (duration - BLEND_OUT)) / BLEND_OUT))
		local add = if extra then extra(t) else nil
		for name, joint in joints do
			local track = keys[name]
			local offset = add and add[name]
			if track or offset then
				local target = (if track then Pose.sample(track, t) else CFrame.identity) * (offset or CFrame.identity)
				local j: any = joint
				j.Transform = (j.Transform :: CFrame):Lerp(target, weight)
			end
		end
	end)
	return stop
end

return Pose
