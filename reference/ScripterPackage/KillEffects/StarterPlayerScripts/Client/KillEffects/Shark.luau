-- "Shark Attack" kill effect, exactly 3 seconds.
--   0.00-0.30  A small dark disturbance and ripple under the player; they flinch and look down.
--   0.30-1.00  The shark rises fast from directly beneath, mouth wide open round the whole player.
--   1.00-1.25  The jaws close; the player (and accessories) is hidden only once the jaws cover them; cartoon glup at 1.22.
--   1.25-2.40  Brief pause, then the shark sinks back down through the opening with a tail wiggle and a small splash.
--   2.40-3.00  The last ripple fades and the opening closes completely.
--
-- The shark is the supplied 3D shark kit (Shared.SharkModel: its mesh, colours and jaw rig, built once and cloned).
-- It rises nose-up around the player with its open mouth centred on them (aligned from the mouth's measured frame);
-- its jaw opens fully below ground (0.15-0.42), stays open as it rises round them, and shuts fully (1.00-1.20).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local SharkModel = require(Shared:WaitForChild("SharkModel"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Rig = require(script.Parent:WaitForChild("Rig"))

local Art = Assets.KillFx

local END = 3.0
local OPEN = SharkModel.OPEN -- the kit's fully open jaw (43 degrees)
local GULP_AT = 1.22

-- The mouth, measured from the kit (scale 1). The player stands along the middle of the open mouth with their feet
-- FEET_GAP in from the hinge and room to spare before the lips; the cavity keeps WALL clear of each side.
local MOUTH = SharkModel.MOUTH
local FEET_GAP = 1.4 -- deep enough that the feet are in the wide part of the open mouth, not the thin hinge
local LIP_MARGIN = 0.92 -- share of the mouth's reach the player may use
local WALL = 0.35
-- The player is hidden once the closing jaw is this close to shut: the jaw then covers them from every side.
local HIDE_AT = 0.18 * OPEN

local SURPRISE = {
	RightShoulder = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, 0.45),
	LeftShoulder = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, -0.45),
	RightElbow = CFrame.Angles(0.35, 0, 0),
	LeftElbow = CFrame.Angles(0.35, 0, 0),
	Neck = CFrame.Angles(-0.4, 0, 0),
}

-- Build the shark in the background as soon as the client loads, so the first effect doesn't wait for it.
task.spawn(SharkModel.prepare)

local function flat(parent: Instance, texture: string, center: Vector3, color: Color3?): (Part, Decal)
	local p = Fx.part(parent, { Size = Vector3.new(0.1, 0.02, 0.1), Transparency = 1, CFrame = CFrame.new(center) })
	local d = Instance.new("Decal")
	d.Texture = texture
	d.Face = Enum.NormalId.Top
	if color then
		d.Color3 = color
	end
	d.Parent = p
	return p, d
end

return function(character: Model, parent: Instance)
	local frozen = Rig.freeze(character, parent)
	if not frozen then
		return
	end
	local t0 = os.clock()
	local model = frozen.model
	local height = math.max(frozen.topY - frozen.feetY, 0.1)
	local feetY = frozen.feetY

	-- Centre on the torso (arms, accessories and the flinch pose don't pull the alignment off-centre), and measure how
	-- far the player reaches from it, accessories included.
	local torso = frozen.root.Position
	local center = Vector3.new(torso.X, feetY, torso.Z)
	local radius = 0
	for _, part in frozen.parts do
		local flatPos = (part.Position - center) * Vector3.new(1, 0, 1)
		radius = math.max(radius, flatPos.Magnitude + math.max(part.Size.X, part.Size.Z) * 0.5)
	end

	-- Scale so the whole body fits inside the open mouth: tall enough (feet in from the hinge, head short of the lips)
	-- and wide enough (clear of the cavity walls). Bigger avatars get a bigger shark.
	local k = math.clamp(
		math.max(1, height / (MOUTH.Reach * LIP_MARGIN - FEET_GAP), (radius + 0.2) / (MOUTH.HalfWidth - WALL)),
		1,
		3
	)

	-- The cartoon "glup": created now (so it's loaded by the swallow) on its own emitter that outlives the effect
	-- model, and played exactly once by a timer just after the jaws shut (they close 1.00-1.20). A soft chomp lands as
	-- they meet.
	Fx.cue(parent, center + Vector3.new(0, height * 0.5, 0), Art.Gulp, 1.8, 0.8, t0, GULP_AT, 1.5, Art.GulpLeadIn)
	Fx.cue(parent, center, Art.Chomp, 0.35, 0.9, t0, 1.18, 1.5)

	local shark = SharkModel.get(k)
	if not shark then
		model:Destroy()
		return
	end
	local fx = shark.model
	fx.Parent = model

	-- Alignment, from the mouth's real frame with the jaw fully open: the middle of the open mouth points straight up
	-- along the player's body, the jaw side faces this viewer's camera, and the player's body centre sits on that
	-- middle line, FEET_GAP in from the hinge. The shark keeps this orientation while it rises around the player, so
	-- the mouth stays centred on them, and the jaw then closes over them.
	local camera = Workspace.CurrentCamera
	local toCamera = if camera then (camera.CFrame.Position - center) * Vector3.new(1, 0, 1) else Vector3.new(0, 0, 1)
	if toCamera.Magnitude < 0.01 then
		toCamera = Vector3.new(0, 0, 1)
	end
	toCamera = toCamera.Unit
	local mouth = SharkModel.mouthFrame(OPEN) -- shark frame, scale 1
	local up = Vector3.new(0, 1, 0)
	local world = CFrame.fromMatrix(Vector3.zero, up:Cross(toCamera), up, toCamera)
	local orient = world * mouth.Rotation:Inverse()
	-- The point of the shark (in its scaled frame) that goes on the player's body centre.
	local bodyMid = (FEET_GAP * k + height / 2)
	local anchor = CFrame.new(-(mouth.Position * k + mouth.UpVector * bodyMid))
	local bodyCenter = center + Vector3.new(0, height / 2, 0)

	local hole, holeDecal = flat(fx, Art.WaterHole, center + Vector3.new(0, 0.03, 0))
	local ripple, rippleDecal = flat(fx, Art.Ring, center + Vector3.new(0, 0.04, 0), Color3.fromRGB(200, 236, 255))
	local host = Fx.host(fx, CFrame.new(center + Vector3.new(0, 0.1, 0)), Vector3.new(3.8 * k, 0.2, 3.8 * k))
	local detail = Fx.detail(center)

	Fx.sound(host, Art.Rumble, 0.8, 1, t0, 0.9)
	Fx.at(t0, 0.36, function()
		Fx.sound(host, Art.SplashBig, 1.2, 1, t0, 2.6)
	end)
	Fx.at(t0, 1.85, function()
		Fx.sound(host, Art.SplashSmall, 0.9, 0.8, t0, 2.75)
	end)

	local spikes = Fx.emitter(host, {
		Texture = Art.Splash,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(35, 35),
		Speed = NumberRange.new(12),
		Acceleration = Vector3.new(0, -45, 0),
		Size = Fx.seq(0, 1.0 * k, 1, 0.55 * k),
		Transparency = Fx.seq(0, 0, 0.75, 0.1, 1, 1),
		Lifetime = NumberRange.new(0.45),
	})
	local drops = Fx.emitter(host, {
		Texture = Art.Droplet,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(50, 50),
		Speed = NumberRange.new(12),
		Acceleration = Vector3.new(0, -55, 0),
		Size = NumberSequence.new(0.38 * k),
		Transparency = Fx.seq(0, 0, 0.8, 0, 1, 1),
		Lifetime = NumberRange.new(0.55),
	})
	Fx.at(t0, 0.4, function()
		spikes:Emit(math.floor(10 * detail))
		drops:Emit(math.floor(14 * detail))
	end)
	Fx.at(t0, 1.85, function()
		spikes:Emit(math.floor(6 * detail))
		drops:Emit(math.floor(7 * detail))
	end)

	-- Rise: how far the mouth anchor is above the player's feet over time.
	local function rise(t: number): number
		if t < 0.3 then
			return -12 * k
		elseif t < 1.0 then
			return -12 * k * (1 - Fx.easeOut(Fx.span(t, 0.3, 1.0)))
		elseif t < 1.3 then
			return 0.7 * k * Fx.smooth(Fx.span(t, 1.0, 1.3))
		elseif t < 1.55 then
			return 0.7 * k + 0.05 * k * math.sin((t - 1.3) * 18)
		end
		return 0.7 * k + (-17 * k - 0.7 * k) * Fx.easeIn(Fx.span(t, 1.55, 2.4))
	end

	local hidden = false
	Fx.everyFrame(t0, END, function(t)
		-- Water opening and ripple.
		local d = 1.2 * k + 1.4 * k * Fx.smooth(Fx.span(t, 0, 0.3)) + 3.0 * k * Fx.easeOut(Fx.span(t, 0.3, 0.45))
		d *= 1 - Fx.smooth(Fx.span(t, 2.4, 2.95))
		hole.Size = Vector3.new(math.max(d, 0.05), 0.02, math.max(d, 0.05))
		holeDecal.Transparency = if d < 0.1 then 1 else 0
		local r, alpha
		if t < 2.4 then
			r, alpha = d * (1 + 0.4 * Fx.span(t, 0, 0.3)), 0.25 + 0.6 * Fx.span(t, 0, 0.3)
		else
			local u = Fx.span(t, 2.4, 2.95)
			r, alpha = 5.5 * k * (1 + 0.5 * u), 0.3 + 0.7 * u
		end
		ripple.Size = Vector3.new(math.max(r, 0.05), 0.02, math.max(r, 0.05))
		rippleDecal.Transparency = alpha

		-- Shark: the jaw opens fully while still below the ground (0.15-0.42), so it is wide open before the lips reach
		-- the player's feet; it rises around them, then the jaw shuts fully 1.00-1.20; a tail wiggle on the way down.
		local open = if t < 1.0
			then OPEN * Fx.easeOut(Fx.span(t, 0.15, 0.42))
			else OPEN * (1 - Fx.easeIn(Fx.span(t, 1.0, 1.2)))
		local wiggle = CFrame.new()
		if t > 1.55 then
			local u = Fx.span(t, 1.55, 2.4)
			wiggle = CFrame.Angles(0.2 * u, 0, 0.12 * math.sin((t - 1.55) * 15))
		end
		-- The rotation pivots on the player's body centre, so the alignment holds through the wiggle too.
		local base = CFrame.new(bodyCenter + Vector3.new(0, rise(t), 0)) * wiggle * orient
		SharkModel.place(shark, base * anchor, open)

		-- Player: flinch, carried up with the shark once inside, hidden only once swallowed: when the closing jaw is
		-- within HIDE_AT of shut and covers them.
		if not hidden then
			local flinch = Fx.easeOutBack(Fx.span(t, 0.05, 0.25))
			local lift = if t > 1.0 then math.max(0, rise(t)) else 0
			Rig.pose(frozen, SURPRISE, flinch, CFrame.new(0, lift, 0))
			if t > 1.0 and open <= HIDE_AT then
				hidden = true
				for _, part in frozen.parts do
					part.Transparency = 1
					for _, c in part:GetChildren() do
						if c:IsA("Decal") then
							c.Transparency = 1
						end
					end
				end
			end
		end
	end)

	Fx.at(t0, END, function()
		model:Destroy()
	end)
end
