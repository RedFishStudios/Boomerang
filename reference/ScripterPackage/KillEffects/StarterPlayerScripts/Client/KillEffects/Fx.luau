-- Small helpers shared by the kill effects: timed steps, per-frame animation, tweens, sounds and particle emitters.
-- Every effect is authored as functions of effect time, so it plays out the same way on every death.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

-- Slow-motion for reviewing an effect (e.g. 6 = six times slower). Scales timed steps, frame animation and tweens;
-- particle lifetimes stay real-time.
Fx.timeScale = 1

-- Runs fn at effect time `seconds` (t0 = os.clock() when the effect started).
function Fx.at(t0: number, seconds: number, fn: () -> ())
	task.delay(math.max(0, t0 + seconds * Fx.timeScale - os.clock()), fn)
end

-- Effect time in seconds since t0.
function Fx.now(t0: number): number
	return (os.clock() - t0) / Fx.timeScale
end

-- Calls fn(t) every frame from now until effect time `untilSeconds`, then once more with t = untilSeconds.
function Fx.everyFrame(t0: number, untilSeconds: number, fn: (t: number) -> ()): RBXScriptConnection
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = Fx.now(t0)
		if t >= untilSeconds then
			connection:Disconnect()
			fn(untilSeconds)
			return
		end
		fn(t)
	end)
	return connection
end

function Fx.tween(
	inst: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(seconds * Fx.timeScale, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- Plays a sound now. If `fadeOutAt` is given (effect time), it fades to silence by `fadeOutAt + 0.15`, so tails never
-- run past the end of the effect.
function Fx.sound(parent: Instance, id: string, volume: number, speed: number?, t0: number?, fadeOutAt: number?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 20
	sound.RollOffMaxDistance = 160
	sound.Parent = parent
	sound:Play()
	if t0 and fadeOutAt then
		Fx.at(t0, fadeOutAt, function()
			Fx.tween(sound, 0.15, { Volume = 0 }, Enum.EasingStyle.Linear)
		end)
	end
	return sound
end

-- A one-shot sound that is created (and starts loading) now but plays later, exactly once, at effect time `at`.
-- It lives on its own emitter part under `parent`, independent of any model the effect destroys, and that emitter is
-- removed when the sound finishes (or after `maxLife` seconds). Each call is independent, so overlapping effects
-- never share or cut off each other's sound. Returns the Sound (for tests).
function Fx.cue(
	parent: Instance,
	position: Vector3,
	id: string,
	volume: number,
	speed: number,
	t0: number,
	at: number,
	maxLife: number,
	skip: number? -- seconds of lead-in silence to skip when it plays
): Sound
	local emitter = Instance.new("Part")
	emitter.Name = "FxAudio"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.CFrame = CFrame.new(position)
	emitter.Parent = parent
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 30 -- full volume within normal gameplay camera distance
	sound.RollOffMaxDistance = 200
	sound.Parent = emitter
	local played = false
	Fx.at(t0, at, function()
		if played or not sound.Parent then
			return
		end
		played = true
		sound.TimePosition = skip or 0
		sound:Play()
		sound.Ended:Once(function()
			emitter:Destroy()
		end)
	end)
	task.delay(at * Fx.timeScale + maxLife, function()
		if emitter.Parent then
			emitter:Destroy()
		end
	end)
	return sound
end

-- Preloads every sound id in `ids` (call once at startup so the first effect's sounds are ready).
function Fx.preloadSounds(ids: { string })
	local sounds = {}
	for _, id in ids do
		local s = Instance.new("Sound")
		s.SoundId = id
		table.insert(sounds, s)
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(sounds)
		end)
		for _, s in sounds do
			s:Destroy()
		end
	end)
end

-- An invisible anchored host part (for attachments, lights, sounds, emitters).
function Fx.host(parent: Instance, cframe: CFrame, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = "FxHost"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size or Vector3.new(1, 1, 1)
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- A plain anchored, non-colliding part for effect geometry.
function Fx.part(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A ParticleEmitter with every random range collapsed to fixed values unless a range is given explicitly.
function Fx.emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.SpreadAngle = Vector2.zero
	e.Rotation = NumberRange.new(0)
	e.RotSpeed = NumberRange.new(0)
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

function Fx.seq(...: number): NumberSequence
	local args = { ... }
	local points = {}
	for i = 1, #args, 2 do
		table.insert(points, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(points)
end

function Fx.colors(...: any): ColorSequence
	local args = { ... }
	local points = {}
	for i = 1, #args, 2 do
		table.insert(points, ColorSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return ColorSequence.new(points)
end

-- How much secondary detail (embers, smoke, dust, splash particles) to spawn: 1 normally, 0.5 for effects far from
-- the camera or on low graphics settings. The main shapes (shark, blossoms, main flames) are never reduced.
function Fx.detail(position: Vector3): number
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > 90 then
		return 0.5
	end
	local ok, quality = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if ok and quality > 0 and quality <= 4 then -- 0 = Automatic
		return 0.5
	end
	return 1
end

-- Easing helpers on 0..1.
function Fx.clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function Fx.smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function Fx.easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

function Fx.easeIn(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * x
end

function Fx.easeOutBack(x: number): number
	x = math.clamp(x, 0, 1)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- Progress of t through [a, b] as 0..1.
function Fx.span(t: number, a: number, b: number): number
	return math.clamp((t - a) / (b - a), 0, 1)
end

-- Preload every kill-effect sound when the client starts, so even the first effect's sounds (like the gulp) are ready.
if RunService:IsClient() then
	local Assets = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Assets"))
	local SOUNDS = {
		"Swoosh",
		"FireSwoosh",
		"FireRoar",
		"StoneGrind",
		"StoneClunk",
		"StoneCrumble",
		"FireCrackle",
		"AshCollapse",
		"AirySwoosh",
		"Gulp",
		"Chomp",
		"Rumble",
		"SplashBig",
		"SplashSmall",
	}
	local ids = {}
	for _, key in SOUNDS do
		table.insert(ids, Assets.KillFx[key])
	end
	Fx.preloadSounds(ids)
end

return Fx
