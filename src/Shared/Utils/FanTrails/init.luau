--!strict
-- FanTrails: short cosmetic wake trails for thrown fans (Boomerang!). Client-only, no collisions, no hitbox changes.
-- Ported from the client's scripter package (reference/ScripterPackage/Trails). Which skin uses which style is the
-- skin's `TrailStyle` in Shared/Referential/Skins; Boomerang.luau drives it.
--
--   local FanTrails = require(path.to.FanTrails)
--   local trail = FanTrails.new(fanPart, "Bamboo")
--   trail:Start()     -- the fan leaves the hand (outward flight; keeps going on the return)
--   trail:Stop()      -- caught / landed / stopped: no new sections, the rest fades out
--   trail:Reset()     -- teleported / reset: clear everything at once (keeps emitting if it was)
--   trail:Destroy()   -- remove it for good
--
-- How it works: the trail records the path the fan's centre actually travelled (not the spinning part's attachments,
-- so the ribbon never spirals), keeps only the last `Length` fan spans of it (oldest sections are dropped every
-- frame, however fast the throw), and draws the style's ribbon layers along it as camera-facing beams (Ribbon.luau).
-- Decorations (leaves, petals, foam, feathers, embers...) are spawned every `Spacing` spans of travel, stay where
-- they were dropped (they don't move with the fan), drift, fade, and are removed once they fall out of the wake.
-- All sizes are fractions of the fan's tip-to-tip span, so one style fits any fan size. Settings: Styles/<Name>.luau.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ribbon = require(script:WaitForChild("Ribbon"))
local Decor = require(script:WaitForChild("Decor"))
if RunService:IsClient() then
	Decor.prepare() -- builds the bamboo leaf mesh in the background
end
local StylesFolder = script:WaitForChild("Styles")

local FanTrails = {}

FanTrails.StyleNames = { "Bamboo", "SunsetPop", "TidalSurge", "SakuraDrift", "Moonsong", "SunfirePhoenix" }

export type Options = {
	Span: number?, -- the fan's tip-to-tip length in studs (measured from the part if omitted)
	Parent: Instance?, -- where the effect objects go (default: Workspace.FanTrailsFx)
	WidthScale: number?, -- multiply the style's ribbon width (tuning)
}

local styleCache: { [string]: any } = {}
function FanTrails.getStyle(name: string): any
	local style = styleCache[name]
	if not style then
		local module = StylesFolder:FindFirstChild(name)
		assert(module and module:IsA("ModuleScript"), "FanTrails: no style called " .. tostring(name))
		style = require(module) :: any
		styleCache[name] = style
	end
	return style
end

-- The part whose centre the trail follows: the part itself, or a model's largest part.
local function resolvePart(weapon: Instance): BasePart
	if weapon:IsA("BasePart") then
		return weapon
	end
	local best: BasePart? = nil
	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") and (not best or d.Size.Magnitude > best.Size.Magnitude) then
			best = d
		end
	end
	assert(best, "FanTrails: the weapon has no parts")
	return best
end

local function measureSpan(weapon: Instance): number
	if weapon:IsA("Model") then
		local size = weapon:GetExtentsSize()
		return math.max(size.X, size.Y, size.Z)
	end
	local p = resolvePart(weapon)
	return math.max(p.Size.X, p.Size.Y, p.Size.Z)
end
FanTrails.measureSpan = measureSpan

local function fxFolder(): Instance
	local f = Workspace:FindFirstChild("FanTrailsFx")
	if not f then
		f = Instance.new("Folder")
		f.Name = "FanTrailsFx"
		f.Parent = Workspace
	end
	return f :: Instance
end

type Point = { pos: Vector3, dist: number, time: number }
type Deco = {
	def: any,
	shape: Decor.Shape,
	born: number,
	life: number,
	emitDist: number,
	pos0: Vector3,
	vel: Vector3,
	accel: Vector3,
	rot0: CFrame,
	spinAxis: Vector3,
	spin: number,
	size: number,
	dir: Vector3,
	wake: number?, -- how far back along the wake it is (0 = at the fan, 1 = at the tail)
	broke: boolean?,
}

local Trail = {}
Trail.__index = Trail

export type Trail = typeof(setmetatable(
	{} :: {
		style: any,
		part: BasePart,
		span: number,
		width: number,
		maxLen: number,
		spacing: number,
		folder: Folder,
		renderer: Ribbon.Renderer,
		points: { Point },
		headPos: Vector3,
		headDist: number,
		dir: Vector3,
		emitting: boolean,
		fadeStart: number?,
		decos: { Deco },
		alive: { [string]: number },
		nextEmit: { [string]: number },
		spawned: number,
		rng: Random,
		destroyed: boolean,
		time: number, -- the clock of the latest update (os.clock)
		visibleLength: number, -- how long the drawn ribbon is now (studs, along the path)
		headGap: number, -- distance from the fan to the start of the ribbon (0 while flying)
	},
	Trail
))

local active: { [any]: boolean } = {}
local bound = false

local function now(): number
	return os.clock()
end

function FanTrails.new(weapon: Instance, styleName: string, options: Options?): Trail
	assert(RunService:IsClient(), "FanTrails runs on the client (it's cosmetic)")
	local opts = options or {}
	local style = FanTrails.getStyle(styleName)
	local part = resolvePart(weapon)
	local span = opts.Span or measureSpan(weapon)
	local folder = Instance.new("Folder")
	folder.Name = "FanTrail_" .. style.Name
	folder.Parent = opts.Parent or fxFolder()
	local self = setmetatable({
		style = style,
		part = part,
		span = span,
		width = style.Width * span * (opts.WidthScale or 1),
		maxLen = style.Length * span,
		spacing = style.SegmentSpacing * span,
		folder = folder,
		renderer = Ribbon.new(folder, #style.Layers, span),
		points = {},
		headPos = part.Position,
		headDist = 0,
		dir = part.CFrame.LookVector,
		emitting = false,
		fadeStart = nil,
		decos = {},
		alive = {},
		nextEmit = {},
		spawned = 0,
		rng = Random.new(),
		destroyed = false,
		time = now(),
		visibleLength = 0,
		headGap = 0,
	}, Trail)
	active[self] = true
	FanTrails._bind()
	return self
end

-- Begin (or resume) the wake from the fan's current position.
function Trail.Start(self: Trail)
	if self.destroyed then
		return
	end
	if not self.emitting then
		self.emitting = true
		self.fadeStart = nil
		if #self.points > 0 and (self.part.Position - self.headPos).Magnitude > self.span then
			self:_clearPath() -- don't join an old faded wake to a new throw
		end
		for _, def in self.style.Particles do
			self.nextEmit[def.Name] = self.headDist + def.Spacing * self.span * (def.FirstAt or 0.35)
		end
	end
end

-- Stop adding sections (caught, landed, stopped); what's left shrinks and fades over FadeTime.
function Trail.Stop(self: Trail)
	if self.emitting then
		self.emitting = false
		self.fadeStart = self.time
	end
end

-- Clear the ribbon and every decoration immediately (reset, teleport). Keeps emitting if it was.
function Trail.Reset(self: Trail)
	self:_clearPath()
	for _, d in self.decos do
		d.shape.destroy()
	end
	table.clear(self.decos)
	table.clear(self.alive)
	Ribbon.hide(self.renderer)
	if not self.emitting then
		self.fadeStart = nil
	end
end

-- Follow a different part (e.g. a new clone of the fan for the next throw).
function Trail.SetWeapon(self: Trail, weapon: Instance)
	self.part = resolvePart(weapon)
	self.headPos = self.part.Position
end

function Trail.IsBusy(self: Trail): boolean
	return self.emitting or #self.points > 0 or #self.decos > 0
end

function Trail.Destroy(self: Trail)
	if self.destroyed then
		return
	end
	self.destroyed = true
	active[self] = nil
	self.folder:Destroy()
end

function Trail._clearPath(self: Trail)
	table.clear(self.points)
	self.headPos = self.part.Position
end

-- A point on the visible ribbon at f (0 = the fan, 1 = the full length behind it).
local function sample(chain: { Ribbon.PathPoint }, f: number): Vector3?
	if #chain == 0 then
		return nil
	end
	for i = 2, #chain do
		local a, b = chain[i - 1], chain[i]
		if f <= b.f then
			local u = if b.f > a.f then (f - a.f) / (b.f - a.f) else 0
			return a.pos:Lerp(b.pos, u)
		end
	end
	return chain[#chain].pos
end

function Trail._spawn(
	self: Trail,
	def: any,
	pos: Vector3,
	emitDist: number,
	chain: { Ribbon.PathPoint },
	cameraPos: Vector3
)
	local count = self.alive[def.Name] or 0
	if count >= def.MaxAlive then
		return
	end
	local rng = self.rng
	local dir = self.dir
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local side = if flat.Magnitude > 1e-3 then flat.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
	local sign = if rng:NextNumber() < 0.5 then -1 else 1
	local at = pos - dir * (def.BackOffset or 0.15) * self.span
	if def.At then
		at = sample(chain, def.At) or at
	end
	if def.Edge then
		-- on the ribbon's outline, as seen from the camera
		local f = def.EdgeRange and rng:NextNumber(def.EdgeRange[1], def.EdgeRange[2]) or rng:NextNumber(0.08, 0.45)
		local p = sample(chain, f)
		if p then
			local edge = dir:Cross((cameraPos - p).Unit)
			edge = if edge.Magnitude > 1e-3 then edge.Unit else side
			at = p + edge * sign * self.width * 0.45 * (1 - f) ^ 0.7
			side = edge
		end
	end
	at += side * sign * rng:NextNumber(0, def.Spread or 0.3) * self.width
	-- a little towards the camera, so it sits in front of the ribbon rather than half inside it
	at += (cameraPos - at).Unit * (def.Lift or 0.1) * self.span
	local colors = def.Colors
	local color = colors[(self.spawned % #colors) + 1]
	self.spawned += 1
	local shape = (Decor :: any)[def.Shape](self.folder, color) :: Decor.Shape
	local size = def.Size * self.span * (1 + rng:NextNumber(-1, 1) * (def.SizeJitter or 0.15))
	local yaw = math.atan2(-flat.X, -flat.Z)
	local rot0 = CFrame.Angles(0, yaw + rng:NextNumber(-0.6, 0.6), 0)
		* CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
	local axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-1, 1))
	local deco: Deco = {
		def = def,
		shape = shape,
		born = self.time,
		life = def.Lifetime * (1 + rng:NextNumber(-0.15, 0.15)),
		emitDist = emitDist,
		pos0 = at,
		vel = side * sign * (def.Drift or 0) * self.span - Vector3.yAxis * (def.Fall or 0) * self.span,
		accel = -Vector3.yAxis * (def.Gravity or 0) * self.span,
		rot0 = rot0,
		spinAxis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis,
		spin = math.rad(def.Spin or 0) * (if rng:NextNumber() < 0.5 then -1 else 1),
		size = size,
		dir = dir,
	}
	self.alive[def.Name] = count + 1
	table.insert(self.decos, deco)
	self:_poseDeco(deco, deco.born)
end

-- Where a decoration is and how it looks at time `t` (by its Motion). Returns false once it's finished.
function Trail._poseDeco(self: Trail, d: Deco, t: number): boolean
	local def = d.def
	local age = t - d.born
	local u = age / d.life
	local pos = d.pos0 + d.vel * age + d.accel * (0.5 * age * age)
	local rot = d.rot0 * CFrame.fromAxisAngle(d.spinAxis, d.spin * age)
	local scale, alpha = 1, 0
	local pop = math.clamp(age / 0.14, 0, 1)
	pop = 1 - (1 - pop) ^ 3
	local motion = def.Motion
	if motion == "Glint" then
		-- flash up, then twinkle out
		scale = if u < 0.3 then 0.3 + 0.85 * (u / 0.3) else 1.15 - 0.55 * ((u - 0.3) / 0.7)
		alpha = math.clamp((u - 0.45) / 0.55, 0, 1)
		rot = CFrame.Angles(0, d.spin * age, 0)
	elseif motion == "Curl" then
		-- rises, curls over backwards, then breaks into droplets
		local breakAt = def.BreakAt or 0.65
		local k = math.clamp(u / breakAt, 0, 1)
		if d.shape.pose then
			d.shape.pose(k)
		end
		local flat = Vector3.new(d.dir.X, 0, d.dir.Z)
		flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
		-- -Z faces the way the fan went and the curl lies flat (turned onto its side), so from overhead it reads as a
		-- crest curling back along the wake
		rot = CFrame.lookAt(Vector3.zero, flat) * CFrame.Angles(0, 0, math.rad(90))
		scale = 0.55 + 0.45 * pop + 0.15 * k
		if u >= breakAt then
			alpha = math.clamp((u - breakAt) / (1 - breakAt), 0, 1)
			scale *= 1 + 0.25 * alpha
			if not d.broke then
				d.broke = true
				local drops = def.BreakInto and self:_def(def.BreakInto)
				if drops then
					for i = 1, def.BreakCount or 3 do
						local back = flat * (0.1 + 0.05 * i) * self.span
						self:_spawnDrop(drops, pos - back + Vector3.yAxis * d.size * 0.3, flat)
					end
				end
			end
		end
	elseif motion == "Drop" then
		local v = d.vel + d.accel * age
		rot = if v.Magnitude > 1e-3 then CFrame.lookAt(Vector3.zero, -v) else d.rot0
		scale = 1 - 0.3 * u
		alpha = math.clamp((u - 0.4) / 0.6, 0, 1)
	elseif motion == "Ember" then
		scale = (1 - u) ^ 0.8
		alpha = math.clamp((u - 0.6) / 0.4, 0, 1)
	elseif motion == "Dissolve" then
		scale = 0.6 + 0.4 * pop + 0.25 * u
		alpha = if u < 0.35 then 0 else (u - 0.35) / 0.65
	elseif motion == "Fleck" then
		-- foam lying flat on the water: pops in, shrinks a little, fades
		rot = CFrame.Angles(0, d.spin * 0.2 + d.spinAxis.X * 3, 0)
		scale = pop * (1 - 0.3 * u)
		alpha = math.clamp((u - 0.4) / 0.6, 0, 1)
	elseif motion == "Float" then
		-- a glowing orb: hangs in the air with a soft pulse, then fades
		rot = CFrame.new()
		scale = pop * (1 + 0.08 * math.sin(age * 5 + d.spinAxis.X * 4))
		alpha = math.clamp((u - 0.5) / 0.5, 0, 1)
	elseif motion == "Flutter" then
		-- face kept mostly towards the sky (readable from overhead), turning slowly and rocking gently
		local tilt = math.rad(def.Tilt or 25)
		local phase = d.spinAxis.X * 6
		rot = d.rot0
			* CFrame.Angles(0, d.spin * age, 0)
			* CFrame.Angles(math.sin(age * 2.4 + phase) * tilt, 0, math.cos(age * 1.9 + phase) * tilt * 0.8)
		scale = pop
		alpha = math.clamp((u - 0.55) / 0.45, 0, 1)
	else -- "Tumble": slow turn while drifting out and down
		scale = pop
		alpha = math.clamp((u - 0.55) / 0.45, 0, 1)
	end
	-- Fade out over the last 30% of the wake, gone exactly at its end (however fast the fan is going).
	local wake = d.wake or 0
	alpha = math.max(alpha, math.clamp((wake - 0.7) / 0.3, 0, 1))
	d.shape.place(CFrame.new(pos) * rot, d.size * scale)
	d.shape.fade(alpha)
	return u < 1 and wake < 1
end

function Trail._def(self: Trail, name: string): any
	for _, def in self.style.Particles do
		if def.Name == name then
			return def
		end
	end
	return nil
end

-- A droplet thrown off a breaking foam curl: out sideways, up a little, then falling.
function Trail._spawnDrop(self: Trail, def: any, pos: Vector3, flat: Vector3)
	local count = self.alive[def.Name] or 0
	if count >= def.MaxAlive then
		return
	end
	local rng = self.rng
	local side = flat:Cross(Vector3.yAxis) * (if rng:NextNumber() < 0.5 then -1 else 1)
	local shape = (Decor :: any)[def.Shape](self.folder, def.Colors[1]) :: Decor.Shape
	local deco: Deco = {
		def = def,
		shape = shape,
		born = self.time,
		life = def.Lifetime,
		emitDist = self.headDist,
		pos0 = pos,
		vel = (side * rng:NextNumber(0.3, 0.7) - flat * 0.2 + Vector3.yAxis * rng:NextNumber(0.2, 0.5)) * self.span,
		accel = -Vector3.yAxis * (def.Gravity or 2) * self.span,
		rot0 = CFrame.new(),
		spinAxis = Vector3.xAxis,
		spin = 0,
		size = def.Size * self.span,
		dir = flat,
	}
	self.alive[def.Name] = count + 1
	table.insert(self.decos, deco)
end

function Trail._update(self: Trail, t: number, cameraPos: Vector3)
	self.time = t
	local style = self.style
	local part = self.part
	if self.emitting and not part.Parent then
		self:Stop()
	end
	local prevPos, prevDist = self.headPos, self.headDist
	if self.emitting then
		local pos = part.Position
		local step = (pos - self.headPos).Magnitude
		if #self.points > 0 and step > style.TeleportDistance * self.span then
			-- A jump (teleport/reset): never draw a straight line across it.
			self:Reset()
			prevPos = pos
			step = 0
		end
		if #self.points == 0 then
			self.headPos = pos
			table.insert(self.points, { pos = pos, dist = self.headDist, time = t })
		elseif step > 0 then
			self.dir = (pos - self.headPos).Unit
			self.headDist += step
			self.headPos = pos
			local last = self.points[#self.points]
			if self.headDist - last.dist >= self.spacing then
				table.insert(self.points, { pos = pos, dist = self.headDist, time = t })
			end
		end
	end

	-- Length now: the full wake, shrinking away after Stop.
	local len, fade = self.maxLen, 0
	if not self.emitting and self.fadeStart then
		local k = math.clamp((t - self.fadeStart) / style.FadeTime, 0, 1)
		len *= 1 - k
		fade = k * 0.6
	end
	-- Drop the oldest sections beyond the length limit or older than Lifetime.
	local points = self.points
	while #points >= 2 and self.headDist - points[2].dist >= len do
		table.remove(points, 1)
	end
	while #points >= 1 and t - points[1].time > style.Lifetime do
		table.remove(points, 1)
	end
	if not self.emitting and len <= 1e-3 then
		table.clear(points)
	end

	-- The visible path: from the fan back along the recorded points, cut exactly at the length limit.
	local chain: { Ribbon.PathPoint } = {}
	if #points > 0 then
		table.insert(chain, { pos = self.headPos, dist = self.headDist, f = 0 })
		local prev = chain[1]
		for i = #points, 1, -1 do
			local p = points[i]
			local d = self.headDist - p.dist
			if d > 1e-3 then
				if d >= len then
					local pd = self.headDist - prev.dist
					local u = if d > pd then (len - pd) / (d - pd) else 1
					local cut = prev.pos:Lerp(p.pos, u)
					table.insert(chain, { pos = cut, dist = self.headDist - len, f = len / self.maxLen })
					break
				end
				local cp = { pos = p.pos, dist = p.dist, f = d / self.maxLen }
				table.insert(chain, cp)
				prev = cp
			end
		end
	end
	self.visibleLength = if #chain >= 2 then self.headDist - chain[#chain].dist else 0
	self.headGap = if #chain >= 1 then (chain[1].pos - part.Position).Magnitude else 0
	if #chain >= 2 then
		Ribbon.draw(self.renderer, style.Layers, chain, style, self.width, self.span, t, cameraPos, fade)
	else
		Ribbon.hide(self.renderer)
	end

	-- New decorations every Spacing spans of travel, placed where the fan was at that distance.
	if self.emitting and self.headDist > prevDist then
		for _, def in style.Particles do
			if not def.BreakOnly then
				local nextAt = self.nextEmit[def.Name] or (self.headDist + def.Spacing * self.span)
				local guard = 0
				while nextAt <= self.headDist and guard < 3 do
					guard += 1
					local u = (nextAt - prevDist) / (self.headDist - prevDist)
					self:_spawn(def, prevPos:Lerp(self.headPos, math.clamp(u, 0, 1)), nextAt, chain, cameraPos)
					nextAt += def.Spacing * self.span * self.rng:NextNumber(0.85, 1.15)
				end
				if nextAt <= self.headDist then
					nextAt = self.headDist + def.Spacing * self.span * 0.5
				end
				self.nextEmit[def.Name] = nextAt
			end
		end
	end

	-- Animate decorations; each fades as it nears the end of the short wake.
	local i = 1
	while i <= #self.decos do
		local d = self.decos[i]
		d.wake = if len > 1e-3 then (self.headDist - d.emitDist) / len else 1
		if self:_poseDeco(d, t) then
			i += 1
		else
			d.shape.destroy()
			self.alive[d.def.Name] = math.max((self.alive[d.def.Name] or 1) - 1, 0)
			table.remove(self.decos, i)
		end
	end
end

function FanTrails._bind()
	if bound then
		return
	end
	bound = true
	-- After the camera, so the trail starts exactly at the fan's position for this frame (no gap).
	RunService:BindToRenderStep("FanTrails", Enum.RenderPriority.Camera.Value + 10, function()
		local camera = Workspace.CurrentCamera
		local cameraPos = if camera then camera.CFrame.Position else Vector3.new(0, 100, 0)
		local t = now()
		for trail in active do
			if not trail.destroyed then
				trail:_update(t, cameraPos)
			end
		end
	end)
end

-- Remove every trail (e.g. when leaving a test).
function FanTrails.destroyAll()
	for trail in active do
		trail:Destroy()
	end
end

return FanTrails
