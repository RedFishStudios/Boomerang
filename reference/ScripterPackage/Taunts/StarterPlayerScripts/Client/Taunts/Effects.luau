-- Lightweight, reusable cosmetic effects for taunts, all owned by a session that cleans everything up.
--
-- local fx = Effects.session(character, parent, duration)
-- fx.every(function(t) ... end)        -- runs every frame with the taunt's time until the session ends
-- fx.add(instance) / fx.onEnd(fn)       -- destroyed / called when the session ends
-- Effects.text(fx, "EZ", style)         -- camera-facing lettering (BillboardGui)
-- Effects.puff(fx, at, velocity, ...)   -- a small soft cartoon puff that drifts, grows and fades
-- Effects.rays(fx, at, length)          -- a quick burst of golden shine rays
-- Effects.glint(fx, at, size)           -- a four-point sparkle that pops in and out
-- Effects.burst(fx, at, size)           -- a cartoon impact burst
-- Effects.eyes(fx, character)           -- returns setClosed(0..1); restores the face when the session ends
--
-- A session ends at `duration`, or as soon as the character dies or is removed - whichever comes first - and then
-- destroys every instance it was given, disconnects its frame updates and runs its onEnd callbacks (so props, text,
-- particles and face changes never outlive the taunt). Effects are anchored, non-colliding and unqueryable.

local RunService = game:GetService("RunService")

local Effects = {}

export type Session = {
	t0: number,
	alive: () -> boolean,
	add: (inst: Instance) -> Instance,
	every: (fn: (t: number) -> ()) -> (),
	onEnd: (fn: () -> ()) -> (),
	finish: () -> (),
}

function Effects.session(character: Model, parent: Instance, duration: number): Session
	local instances: { Instance } = {}
	local updaters: { (number) -> () } = {}
	local endings: { () -> () } = {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local t0 = os.clock()
	local done = false
	local connection: RBXScriptConnection
	local session: Session
	local function finish()
		if done then
			return
		end
		done = true
		connection:Disconnect()
		for _, fn in endings do
			task.spawn(fn)
		end
		for _, inst in instances do
			inst:Destroy()
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t >= duration or not character.Parent or (humanoid and humanoid.Health <= 0) then
			finish()
			return
		end
		for _, fn in updaters do
			fn(t)
		end
	end)
	session = {
		t0 = t0,
		alive = function()
			return not done
		end,
		add = function(inst: Instance): Instance
			if done then
				inst:Destroy()
			else
				if not inst.Parent then
					inst.Parent = parent
				end
				table.insert(instances, inst)
			end
			return inst
		end,
		every = function(fn)
			table.insert(updaters, fn)
		end,
		onEnd = function(fn)
			table.insert(endings, fn)
		end,
		finish = finish,
	}
	return session
end

local function holderPart(): Part
	local p = Instance.new("Part")
	p.Name = "TauntFx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	return p
end

export type Text = {
	holder: BasePart,
	place: (position: Vector3, size: number, fade: number) -> (), -- size in studs (height of the lettering box)
}

export type TextStyle = {
	color: Color3,
	stroke: Color3?,
	strokeThickness: number?,
	glow: Color3?, -- a soft halo of this colour behind the letters
	rotation: number?,
	widthRatio: number?, -- box width / height (default 1)
}

-- Bold rounded camera-facing lettering on its own anchored holder, readable from overhead and the side.
function Effects.text(session: Session, text: string, style: TextStyle): Text
	local holder = holderPart()
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Size = UDim2.fromScale(1, 1)
	gui.Parent = holder
	local labels: { TextLabel } = {}
	local strokes: { UIStroke } = {}
	local function layer(color: Color3, scale: number, z: number, isGlow: boolean)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(scale, scale)
		label.Text = text
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		label.TextColor3 = color
		label.Rotation = style.rotation or 0
		label.ZIndex = z
		label.Parent = gui
		if isGlow then
			label.TextTransparency = 0.72
		else
			local stroke = Instance.new("UIStroke")
			stroke.Color = style.stroke or Color3.new(1, 1, 1)
			stroke.Thickness = style.strokeThickness or 1.5
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Parent = label
			table.insert(strokes, stroke)
		end
		table.insert(labels, label)
	end
	if style.glow then
		layer(style.glow, 1.12, 1, true)
	end
	layer(style.color, 1, 2, false)
	session.add(holder)
	local ratio = style.widthRatio or 1
	return {
		holder = holder,
		place = function(position: Vector3, size: number, fade: number)
			holder.CFrame = CFrame.new(position)
			gui.Size = UDim2.fromScale(size * ratio, size)
			for i, label in labels do
				label.TextTransparency = if style.glow and i == 1 then 0.72 + 0.28 * fade else fade
			end
			for _, stroke in strokes do
				stroke.Transparency = fade
			end
		end,
	}
end

-- A soft cartoon puff: a white ball that drifts along `velocity`, grows from `size` to twice that and fades out over
-- `life` seconds, starting at session time `born`.
function Effects.puff(
	session: Session,
	at: Vector3,
	velocity: Vector3,
	size: number,
	life: number,
	born: number,
	color: Color3?
)
	local ball = holderPart()
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.SmoothPlastic
	ball.Color = color or Color3.fromRGB(250, 250, 255)
	ball.Size = Vector3.one * size
	ball.CFrame = CFrame.new(at)
	session.add(ball)
	session.every(function(t)
		local u = (t - born) / life
		if u < 0 or u > 1 then
			ball.Transparency = 1
			return
		end
		local ease = 1 - (1 - u) ^ 2
		ball.CFrame = CFrame.new(at + velocity * life * ease)
		ball.Size = Vector3.one * size * (1 + ease)
		ball.Transparency = 0.15 + 0.85 * u ^ 1.5
	end)
end

-- A quick burst of golden shine rays from `at`, in every direction (so it reads from above and the side), starting at
-- session time `born` and gone 0.5 s later.
function Effects.rays(session: Session, at: Vector3, length: number, born: number, thickness: number?, count: number?)
	local rays: { { part: BasePart, dir: Vector3 } } = {}
	local golden = 2.399963 -- golden angle, for evenly spread directions
	local COUNT = count or 14
	local THICK = thickness or 0.07
	for i = 0, COUNT - 1 do
		local y = 0.85 - 1.3 * (i / (COUNT - 1)) -- mostly level and upward
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * golden
		local dir = Vector3.new(math.cos(a) * r, y, math.sin(a) * r).Unit
		local ray = holderPart()
		ray.Material = Enum.Material.Neon
		ray.Color = if i % 2 == 0 then Color3.fromRGB(255, 214, 72) else Color3.fromRGB(255, 244, 170)
		session.add(ray)
		table.insert(rays, { part = ray, dir = dir })
	end
	session.every(function(t)
		local u = (t - born) / 0.5
		for _, ray in rays do
			if u < 0 or u > 1 then
				ray.part.Transparency = 1
			else
				local reach = length * (0.35 + 0.65 * (1 - (1 - u) ^ 3))
				local len = length * 0.45 * (1 - u * 0.6)
				local mid = at + ray.dir * (reach - len / 2)
				ray.part.Size = Vector3.new(THICK, THICK, len)
				ray.part.CFrame = CFrame.lookAt(mid, mid + ray.dir)
				ray.part.Transparency = 0.1 + 0.9 * u ^ 2
			end
		end
	end)
end

-- A four-point sparkle (two crossed thin bars, camera-facing) that pops in and out at `at` around session time `born`.
function Effects.glint(session: Session, at: () -> Vector3, size: number, born: number)
	local holder = holderPart()
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Size = UDim2.fromScale(size, size)
	gui.Parent = holder
	local bars: { Frame } = {}
	for i = 0, 1 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(0.14, 1)
		bar.Rotation = i * 90
		bar.BackgroundColor3 = Color3.fromRGB(255, 250, 210)
		bar.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = bar
		bar.Parent = gui
		table.insert(bars, bar)
	end
	session.add(holder)
	session.every(function(t)
		local u = (t - born) / 0.4
		local s = if u < 0 or u > 1 then 0 else math.sin(u * math.pi)
		holder.CFrame = CFrame.new(at())
		gui.Size = UDim2.fromScale(size * s, size * s)
		for _, bar in bars do
			bar.BackgroundTransparency = 1 - s
		end
	end)
end

-- A cartoon impact burst: a white flash with yellow spikes, camera-facing, 0.3 s from session time `born`.
function Effects.burst(session: Session, at: () -> Vector3, size: number, born: number)
	local holder = holderPart()
	local gui = Instance.new("BillboardGui")
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.Size = UDim2.fromScale(size, size)
	gui.Parent = holder
	local pieces: { GuiObject } = {}
	for i = 0, 7 do
		local spike = Instance.new("Frame")
		spike.AnchorPoint = Vector2.new(0.5, 1)
		spike.Position = UDim2.fromScale(0.5, 0.5)
		spike.Size = UDim2.fromScale(0.09, if i % 2 == 0 then 0.5 else 0.36)
		spike.Rotation = i * 45 + 22
		spike.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
		spike.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = spike
		spike.Parent = gui
		table.insert(pieces, spike)
	end
	local flash = Instance.new("Frame")
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.Position = UDim2.fromScale(0.5, 0.5)
	flash.Size = UDim2.fromScale(0.42, 0.42)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = flash
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 170, 40)
	stroke.Thickness = 2
	stroke.Parent = flash
	flash.ZIndex = 2
	flash.Parent = gui
	table.insert(pieces, flash)
	session.add(holder)
	session.every(function(t)
		local u = (t - born) / 0.3
		holder.CFrame = CFrame.new(at())
		if u < 0 or u > 1 then
			gui.Enabled = false
			return
		end
		gui.Enabled = true
		local grow = 0.55 + 0.45 * (1 - (1 - u) ^ 3)
		gui.Size = UDim2.fromScale(size * grow, size * grow)
		for _, piece in pieces do
			piece.BackgroundTransparency = u ^ 2
		end
		stroke.Transparency = u ^ 2
	end)
end

-- Closes the eyes. Dynamic heads use their own eyelids (FaceControls); classic decal faces get two skin-coloured
-- eyelids with a dark lash line drawn over the eyes (the head's own colour, so the skin tone and mouth stay as they
-- are). Returns setClosed(0..1). The face is restored when the session ends, however it ends.
function Effects.eyes(session: Session, character: Model): (amount: number) -> ()
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return function() end
	end
	local face = head:FindFirstChildOfClass("FaceControls")
	if face then
		local f: any = face
		local before = { left = f.LeftEyeClosed, right = f.RightEyeClosed }
		local amount = 0
		-- The Animator can also write face controls, so hold the value every frame while closed.
		local hold = RunService.Stepped:Connect(function()
			if amount > 0 then
				f.LeftEyeClosed = math.max(before.left, amount)
				f.RightEyeClosed = math.max(before.right, amount)
			end
		end)
		session.onEnd(function()
			hold:Disconnect()
			if face.Parent then
				f.LeftEyeClosed, f.RightEyeClosed = before.left, before.right
			end
		end)
		return function(a: number)
			amount = a
			if a <= 0 then
				f.LeftEyeClosed, f.RightEyeClosed = before.left, before.right
			end
		end
	end
	-- Classic face decal: draw closed eyelids over the front face.
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TauntClosedEyes"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.Adornee = head
	gui.Enabled = false
	for _, x in { 0.36, 0.64 } do
		local lid = Instance.new("Frame")
		lid.AnchorPoint = Vector2.new(0.5, 0.5)
		lid.Position = UDim2.fromScale(x, 0.4)
		lid.Size = UDim2.fromScale(0.2, 0.16)
		lid.BackgroundColor3 = head.Color
		lid.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = lid
		local lash = Instance.new("Frame")
		lash.AnchorPoint = Vector2.new(0.5, 0.5)
		lash.Position = UDim2.fromScale(0.5, 0.6)
		lash.Size = UDim2.fromScale(0.8, 0.14)
		lash.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
		lash.BorderSizePixel = 0
		local lashCorner = Instance.new("UICorner")
		lashCorner.CornerRadius = UDim.new(1, 0)
		lashCorner.Parent = lash
		lash.Parent = lid
		lid.Parent = gui
	end
	gui.Parent = head
	session.add(gui)
	return function(a: number)
		gui.Enabled = a > 0.5
	end
end

return Effects
