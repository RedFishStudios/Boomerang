--@localscript
--!strict
-- TEMPORARY fan-trail test bench. Delete this whole folder (StarterPlayerScripts.Client.FanTrailTest) to remove it;
-- nothing else depends on it. It throws local, cosmetic clones of the working fan copies in
-- ReplicatedStorage.FanWeapons along boomerang paths and drives FanTrails exactly the way the real weapon code should:
-- Start() on release, Stop() when caught or landed, Reset() on teleport/reset.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FanTrails = require(Shared:WaitForChild("FanTrails"))
local Theme = require(Shared:WaitForChild("Theme"))

local player = Players.LocalPlayer
local fansFolder = ReplicatedStorage:WaitForChild("FanWeapons", 10)

local FAN_ORDER = { "BambooFan", "SunsetFan", "Surge", "SakuraFan", "MoonsongFan", "SunfireFan", "SunfireFan_01" }
local LABELS = {
	BambooFan = "Bamboo",
	SunsetFan = "Sunset Pop",
	Surge = "Tidal Surge",
	SakuraFan = "Sakura Drift",
	MoonsongFan = "Moonsong",
	SunfireFan = "Sunfire Phoenix",
	SunfireFan_01 = "Sunfire Phoenix (alt)",
}

local settings = {
	fan = "BambooFan",
	scale = 1, -- test size of the thrown clone (the working copies are never changed)
	speed = 1, -- 1 = normal throw, 1.8 = fast
	backdrop = "Map",
}

local fxRoot = Instance.new("Folder")
fxRoot.Name = "FanTrailTest"
fxRoot.Parent = Workspace

type Throw = {
	model: Model,
	part: BasePart,
	trail: any,
	span: number,
	baseRot: CFrame,
	phase: string,
	t: number,
	duration: number,
	from: Vector3,
	control: Vector3,
	target: Vector3?, -- nil = the hand (followed live)
	far: Vector3,
	returnControl: Vector3,
	offset: Vector3,
	spin: number,
	pos: Vector3,
	landY: number?,
	doneAt: number?,
}
local throws: { Throw } = {}
local lastThrow: Throw? = nil

local function character(): Model?
	return player.Character
end

local function handPosition(): Vector3
	local char = character()
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if hand then
		return hand.Position
	end
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else Vector3.new(0, 3, 0)
end

local function rootFrame(): CFrame
	local char = character()
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return CFrame.new(0, 3, 0)
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	return CFrame.lookAt(root.Position, root.Position + look)
end

local function groundY(): number
	local char = character()
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum then
		return root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	end
	return 0
end

-- A thrown copy: cloned from the working copy, anchored, no collisions or queries (purely visual).
local function cloneFan(name: string): (Model, BasePart, CFrame, number)
	local source = fansFolder and fansFolder:FindFirstChild(name)
	assert(source and source:IsA("Model"), "FanWeapons." .. name .. " is missing")
	local model = source:Clone()
	if settings.scale ~= 1 then
		model:ScaleTo(model:GetScale() * settings.scale)
	end
	local part: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = true
			if not part or d.Size.Magnitude > part.Size.Magnitude then
				part = d
			end
		end
	end
	assert(part, name .. " has no parts")
	-- Spin it flat like a boomerang: turn its thinnest axis to point up.
	local s = part.Size
	local baseRot = if s.Z <= s.X and s.Z <= s.Y
		then CFrame.Angles(math.rad(-90), 0, 0)
		elseif s.X <= s.Y then CFrame.Angles(0, 0, math.rad(90))
		else CFrame.new()
	local span = math.max(s.X, s.Y, s.Z)
	model.Parent = fxRoot
	return model, part, baseRot, span
end

local function bezier(a: Vector3, c: Vector3, b: Vector3, u: number): Vector3
	return a:Lerp(c, u):Lerp(c:Lerp(b, u), u)
end

local function throw(name: string, mode: string, yawOffset: number?, curveSign: number?)
	local model, part, baseRot, span = cloneFan(name)
	local frame = rootFrame() * CFrame.Angles(0, math.rad(yawOffset or 0), 0)
	local start = handPosition()
	local range = span * 5.5
	local sign = curveSign or 1
	local fwd, right = frame.LookVector, frame.RightVector
	local far = start + fwd * range
	local control, returnControl
	if mode == "Straight" then
		control = start + fwd * range * 0.5
		returnControl = control
	else
		control = start + fwd * range * 0.55 + right * range * 0.42 * sign
		returnControl = start + fwd * range * 0.55 - right * range * 0.42 * sign
	end
	local trail = FanTrails.new(part, FanTrails.StyleForFan[name], { Parent = fxRoot })
	local th: Throw = {
		model = model,
		part = part,
		trail = trail,
		span = span,
		baseRot = baseRot,
		phase = "out",
		t = 0,
		duration = 1.25 / settings.speed,
		from = start,
		control = control,
		far = far,
		returnControl = returnControl,
		offset = Vector3.zero,
		spin = 0,
		pos = start,
	}
	part.CFrame = CFrame.new(start) * baseRot
	trail:Start()
	table.insert(throws, th)
	lastThrow = th
	return th
end

local function recall(th: Throw?)
	if th and (th.phase == "out" or th.phase == "back") then
		local hand = handPosition()
		th.phase = "back"
		th.t = 0
		th.from = th.pos - th.offset
		local mid = th.from:Lerp(hand, 0.5)
		local side = (hand - th.from):Cross(Vector3.yAxis)
		th.returnControl = mid
			+ (if side.Magnitude > 1e-3 then side.Unit else Vector3.zero) * (hand - th.from).Magnitude * 0.25
		th.duration = math.clamp((hand - th.from).Magnitude / (th.span * 5.5) * 1.25, 0.35, 1.4) / settings.speed
	end
end

local function land(th: Throw?)
	if th and (th.phase == "out" or th.phase == "back") then
		th.phase = "land"
		th.t = 0
		th.landY = groundY() + 0.3
		th.trail:Stop() -- stopped: no new sections, the rest fades
	end
end

local function teleport(th: Throw?)
	if th and (th.phase == "out" or th.phase == "back") then
		local frame = rootFrame()
		th.offset += frame.RightVector * th.span * 4
		th.trail:Reset() -- teleported: clear at once, then carry on from the new spot
	end
end

local function finish(th: Throw)
	th.model:Destroy()
	th.phase = "done"
	th.doneAt = os.clock()
end

local function resetAll()
	for _, th in throws do
		th.model:Destroy()
		th.trail:Destroy()
	end
	table.clear(throws)
	lastThrow = nil
	fxRoot:ClearAllChildren()
end

RunService:BindToRenderStep("FanTrailTestFly", Enum.RenderPriority.Camera.Value + 5, function(dt)
	local i = 1
	while i <= #throws do
		local th = throws[i]
		if th.phase ~= "done" then
			th.t += dt
			th.spin += dt * math.pi * 2 * 3.2 * (if th.phase == "land" then math.max(1 - th.t / 0.4, 0) else 1)
			local pos
			if th.phase == "out" then
				local u = math.clamp(th.t / th.duration, 0, 1)
				local eased = 1 - (1 - u) ^ 1.8 -- slows towards the far point
				pos = bezier(th.from, th.control, th.far, eased)
				if u >= 1 then
					th.phase = "back"
					th.t = 0
					th.from = th.far
					th.duration *= 0.95
				end
			elseif th.phase == "back" then
				local u = math.clamp(th.t / th.duration, 0, 1)
				local eased = u ^ 1.5 -- speeds up coming home
				pos = bezier(th.from, th.returnControl, handPosition() - th.offset, eased)
				if u >= 1 then
					th.trail:Stop() -- caught: fade what's left
					finish(th)
				end
			elseif th.phase == "land" then
				local u = math.clamp(th.t / 0.35, 0, 1)
				pos = Vector3.new(th.pos.X, th.pos.Y + ((th.landY :: number) - th.pos.Y) * u * u, th.pos.Z) - th.offset
				if th.t > 1.6 then
					finish(th)
				end
			end
			if th.phase ~= "done" and pos then
				th.pos = pos + th.offset
				local tilt = if th.phase == "land" then CFrame.new() else CFrame.Angles(math.rad(8), 0, 0)
				th.part.CFrame = CFrame.new(th.pos) * tilt * CFrame.Angles(0, th.spin, 0) * th.baseRot
			end
			i += 1
		elseif not th.trail:IsBusy() then
			th.trail:Destroy()
			table.remove(throws, i)
		else
			i += 1
		end
	end
end)

-- Camera: the bench never touches it. The player's normal camera stays in charge (no overrides).

-- Backdrops ------------------------------------------------------------------------------------------------------
local savedLighting = {
	ClockTime = Lighting.ClockTime,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
}
local backdropPart: Part? = nil
local function setBackdrop(mode: string)
	settings.backdrop = mode
	if backdropPart then
		backdropPart:Destroy()
		backdropPart = nil
	end
	for k, v in savedLighting do
		(Lighting :: any)[k] = v
	end
	if mode == "Map" then
		return
	end
	local p = Instance.new("Part")
	p.Name = "FanTrailTestBackdrop"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.new(600, 0.2, 600)
	p.Material = Enum.Material.SmoothPlastic
	local frame = rootFrame()
	p.CFrame = CFrame.new(frame.Position.X, groundY() + 0.05, frame.Position.Z)
	if mode == "Light" then
		p.Color = Color3.fromRGB(236, 232, 218)
		Lighting.ClockTime = 14
	else
		p.Color = Color3.fromRGB(26, 30, 44)
		Lighting.ClockTime = 0.5
		Lighting.Brightness = 1
	end
	p.Parent = fxRoot.Parent
	backdropPart = p
end

-- UI -------------------------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "FanTrailTestGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 60)
panel.Size = UDim2.fromOffset(300, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Theme.Colors.WoodDark
panel.BackgroundTransparency = 0.1
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local pad = Instance.new("UIPadding")
for _, k in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
	(pad :: any)[k] = UDim.new(0, 8)
end
pad.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 5)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function label(text: string, size: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size or 18)
	l.FontFace = Theme.Font
	l.TextColor3 = Theme.Colors.Text
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.LayoutOrder = nextOrder()
	l.Parent = panel
	return l
end

local function row(): Frame
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, 26)
	r.LayoutOrder = nextOrder()
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 4)
	l.Parent = r
	r.Parent = panel
	return r
end

local buttons: { [string]: TextButton } = {}
local function button(parent: Instance, text: string, width: number, onClick: () -> (), key: string?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(width, -4, 1, 0)
	b.BackgroundColor3 = Theme.Colors.Wood
	b.FontFace = Theme.Font
	b.TextColor3 = Theme.Colors.Text
	b.TextScaled = true
	b.Text = text
	b.AutoButtonColor = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = b
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 3)
	p.PaddingBottom = UDim.new(0, 3)
	p.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = parent
	if key then
		buttons[key] = b
	end
	return b
end

local function highlight(prefix: string, chosen: string)
	for key, b in buttons do
		if key:sub(1, #prefix) == prefix then
			b.BackgroundColor3 = if key == prefix .. chosen then Theme.Colors.ButtonGreen else Theme.Colors.Wood
		end
	end
end

local title = label("FAN TRAIL TEST (temporary)", 22)
title.TextColor3 = Theme.Colors.Gold
local info = label("", 16)

local function refreshInfo()
	local source = fansFolder and fansFolder:FindFirstChild(settings.fan)
	if source and source:IsA("Model") then
		local span = FanTrails.measureSpan(source) * settings.scale
		local style = FanTrails.getStyle(FanTrails.StyleForFan[settings.fan])
		info.Text =
			string.format("%s: span %.1f studs, trail %.0f studs", LABELS[settings.fan], span, span * style.Length)
	else
		info.Text = "ReplicatedStorage.FanWeapons is missing"
	end
	highlight("fan:", settings.fan)
end

label("Fan and trail", 16)
for i = 1, #FAN_ORDER, 2 do
	local r = row()
	for j = i, math.min(i + 1, #FAN_ORDER) do
		local name = FAN_ORDER[j]
		button(r, LABELS[name], 0.5, function()
			settings.fan = name
			refreshInfo()
		end, "fan:" .. name)
	end
end

label("Throw", 16)
local r1 = row()
button(r1, "Curved throw", 0.5, function()
	throw(settings.fan, "Curved")
end)
button(r1, "Straight throw", 0.5, function()
	throw(settings.fan, "Straight")
end)
local r2 = row()
button(r2, "Recall", 0.34, function()
	recall(lastThrow)
end)
button(r2, "Stop / land", 0.33, function()
	land(lastThrow)
end)
button(r2, "Teleport", 0.33, function()
	teleport(lastThrow)
end)
local r3 = row()
button(r3, "Throw all six", 0.6, function()
	local six = { "BambooFan", "SunsetFan", "Surge", "SakuraFan", "MoonsongFan", "SunfireFan" }
	for k, name in six do
		throw(name, "Curved", -50 + (k - 1) * 20, if k % 2 == 0 then -1 else 1)
	end
end)
local resetButton = button(r3, "RESET", 0.4, resetAll)
resetButton.BackgroundColor3 = Color3.fromRGB(176, 66, 52)

label("Speed and size", 16)
local r4 = row()
button(r4, "Normal", 0.25, function()
	settings.speed = 1
	highlight("speed:", "1")
end, "speed:1")
button(r4, "Fast", 0.25, function()
	settings.speed = 1.8
	highlight("speed:", "1.8")
end, "speed:1.8")
for _, sc in { 1, 0.5, 0.3 } do
	button(r4, string.format("%gx", sc), 0.5 / 3, function()
		settings.scale = sc
		highlight("scale:", tostring(sc))
		refreshInfo()
	end, "scale:" .. tostring(sc))
end

label("Background", 16)
local r7 = row()
for _, mode in { "Map", "Light", "Dark" } do
	button(r7, mode, 1 / 3, function()
		setBackdrop(mode)
		highlight("bg:", mode)
	end, "bg:" .. mode)
end

refreshInfo()
highlight("speed:", "1")
highlight("scale:", "1")
highlight("bg:", "Map")

-- Automated checks from Studio tools (test-only): a BindableFunction on the test GUI.
-- control:Invoke("throw", fanName, "Curved"|"Straight"[, yaw, curveSign]) / "recall" / "land" / "teleport" / "reset" /
-- "backdrop", mode / "scale", n / "speed", n / "state"
local control = Instance.new("BindableFunction")
control.Name = "Control"
control.OnInvoke = function(cmd: string, a: any, b: any, c: any, d: any): any
	if cmd == "throw" then
		throw(a, b or "Curved", c, d)
	elseif cmd == "throwAll" then
		local six = { "BambooFan", "SunsetFan", "Surge", "SakuraFan", "MoonsongFan", "SunfireFan" }
		for k, name in six do
			throw(name, "Curved", -50 + (k - 1) * 20, if k % 2 == 0 then -1 else 1)
		end
	elseif cmd == "recall" then
		recall(lastThrow)
	elseif cmd == "land" then
		land(lastThrow)
	elseif cmd == "teleport" then
		teleport(lastThrow)
	elseif cmd == "reset" then
		resetAll()
	elseif cmd == "backdrop" then
		setBackdrop(a)
	elseif cmd == "scale" then
		settings.scale = a
	elseif cmd == "speed" then
		settings.speed = a
	elseif cmd == "state" then
		local out = {}
		for _, th in throws do
			table.insert(out, {
				phase = th.phase,
				pos = th.part.Position,
				span = th.span,
				points = #th.trail.points,
				headDist = th.trail.headDist,
				decos = #th.trail.decos,
				visibleLength = th.trail.visibleLength,
				headGap = th.trail.headGap,
				maxLen = th.trail.maxLen,
				style = th.trail.style.Name,
				fan = th.model.Name,
			})
		end
		return out
	end
	return true
end
control.Parent = gui
