--[[
	BotAnimator -- bot / NPC animation

	Animates a bot's client-rendered avatar from a replicated "pose" attribute on the server rig root
	(Standing / Running / FreeFall / ...), mapped to the Animate animation folders. BotService sets the
	pose every step.

	Plain helper (not a *Controller / *Screen / *Library), so the client bootstrap does not require or
	init it. BotController owns one instance per rendered bot.

	The pose/blend logic mirrors CharacterRenderController's player path.
]]

local BotAnimator = {}
BotAnimator.__index = BotAnimator

-------------------------------------------------------------------------------
-- CONSTANTS (same mapping/blend as CharacterRenderController)
-------------------------------------------------------------------------------

local POSE_TO_ANIMATION_NAME = {
	Standing = "idle",
	Running = "walk",
	Jumping = "jump",
	FreeFall = "fall",
	Climbing = "climb",
	Seated = "sit",
	Swimming = "swim",
	SwimIdle = "swimidle",
}
local LOOPED_POSE_ANIMATIONS = {
	idle = true, walk = true, run = true, fall = true, climb = true,
	sit = true, swim = true, swimidle = true, toolnone = true,
}
local POSE_TRANSITION_TIME = 0.2
-- // R15 walk/run blend, matching the Animate's getRunWalkBlendWeights
local NORMALIZED_WALK_SPEED = 0.5
local NORMALIZED_RUN_SPEED = 1
local HUMANOID_HIP_HEIGHT = 2
local R15_WALK_SPEED_SCALE = 16

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type BotAnimator = typeof(setmetatable(
	{} :: {
		Humanoid: Humanoid,
		Animator: Animator,
		Animate: Instance, -- // holds the animation folders ("walk", "idle", "fall", ...)
		Tracks: { [string]: AnimationTrack },
		Active: { [string]: true },
	},
	BotAnimator
))

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

-- // Builds an animator for a cloned avatar. Returns nil if the clone lacks a Humanoid, Animator or Animate container.
function BotAnimator.new(visual: Model): BotAnimator?
	local humanoid = visual:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animate = visual:FindFirstChild("Animate")
	if not (humanoid and animator and animate) then
		return nil
	end

	-- // Disabled so the clone's Animate script doesn't fight the manual pose driving; kept for its animation folders
	if animate:IsA("LocalScript") then
		(animate :: LocalScript).Disabled = true
	end

	return setmetatable({
		Humanoid = humanoid,
		Animator = animator,
		Animate = animate,
		Tracks = {},
		Active = {},
	}, BotAnimator)
end

-------------------------------------------------------------------------------
-- PRIVATE
-------------------------------------------------------------------------------

-- // Loads (once) the track for an Animate folder such as "walk"; picks the highest-Weight variant
local function getPoseTrack(self: BotAnimator, animationName: string): AnimationTrack?
	local track = self.Tracks[animationName]
	if track then
		return track
	end
	local folder = self.Animate:FindFirstChild(animationName)
	if not folder then
		return nil
	end
	local bestAnimation: Animation? = nil
	local bestWeight = -math.huge
	for _, child in pairs(folder:GetChildren()) do
		if child:IsA("Animation") then
			local weightValue = child:FindFirstChild("Weight")
			local weight = if weightValue and weightValue:IsA("NumberValue") then weightValue.Value else 1
			if weight > bestWeight then
				bestAnimation = child
				bestWeight = weight
			end
		end
	end
	if not bestAnimation then
		return nil
	end
	track = self.Animator:LoadAnimation(bestAnimation)
	track.Looped = LOOPED_POSE_ANIMATIONS[animationName] == true
	track.Priority = if animationName == "toolnone" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Core
	self.Tracks[animationName] = track
	return track
end

local function getRenderedHeightScale(self: BotAnimator): number
	local hipHeight = self.Humanoid.HipHeight
	local dampening = self.Animate:FindFirstChild("ScaleDampeningPercent")
	if dampening and dampening:IsA("NumberValue") then
		return 1 + (hipHeight - HUMANOID_HIP_HEIGHT) * dampening.Value / HUMANOID_HIP_HEIGHT
	end
	return hipHeight / HUMANOID_HIP_HEIGHT
end

-------------------------------------------------------------------------------
-- PUBLIC
-------------------------------------------------------------------------------

-- // Called every frame with the replicated pose and root velocity (for the walk/run blend)
function BotAnimator.update(self: BotAnimator, pose: string?, velocity: Vector3?)
	pose = pose or "Standing"

	local wanted: { [string]: true } = {}
	local animationName = if pose:sub(1, 6) == "EMOTE_" then pose:sub(7) else POSE_TO_ANIMATION_NAME[pose]
	if animationName then
		wanted[animationName] = true
	end
	if pose == "Running" then
		wanted.run = true
	end

	-- // Stop unwanted tracks (unknown poses like "Dead" stop everything)
	for name, track in pairs(self.Tracks) do
		if not wanted[name] and track.IsPlaying then
			track:Stop(POSE_TRANSITION_TIME)
		end
	end

	-- // Start wanted tracks; restart looped tracks stopped externally
	for name in pairs(wanted) do
		local track = getPoseTrack(self, name)
		if track and not track.IsPlaying and (not self.Active[name] or track.Looped) then
			track:Play(POSE_TRANSITION_TIME)
		end
	end

	if pose == "Running" then
		local v = velocity or Vector3.zero
		local horizontalSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
		local runSpeed = (horizontalSpeed / R15_WALK_SPEED_SCALE) * 1.25 / getRenderedHeightScale(self)
		local walkWeight, runWeight, timeWarp = 0.0001, 0.0001, 1
		if runSpeed <= NORMALIZED_WALK_SPEED then
			walkWeight = 1
			timeWarp = runSpeed / NORMALIZED_WALK_SPEED
		elseif runSpeed < NORMALIZED_RUN_SPEED then
			local fadeInRun = (runSpeed - NORMALIZED_WALK_SPEED) / (NORMALIZED_RUN_SPEED - NORMALIZED_WALK_SPEED)
			walkWeight = 1 - fadeInRun
			runWeight = fadeInRun
		else
			timeWarp = runSpeed / NORMALIZED_RUN_SPEED
			runWeight = 1
		end
		local walkTrack = self.Tracks.walk
		local runTrack = self.Tracks.run
		if walkTrack then
			walkTrack:AdjustWeight(walkWeight)
			walkTrack:AdjustSpeed(timeWarp)
		end
		if runTrack then
			runTrack:AdjustWeight(runWeight)
			runTrack:AdjustSpeed(timeWarp)
		end
	end

	self.Active = wanted
end

function BotAnimator.destroy(self: BotAnimator)
	for _, track in pairs(self.Tracks) do
		track:Stop()
		track:Destroy()
	end
	table.clear(self.Tracks)
	table.clear(self.Active)
end

return BotAnimator
