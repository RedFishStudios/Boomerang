-- Shared building blocks for Boomerang! screens: instance builder, outlined text, press feedback.
-- Ported from the client's scripter package (reference/ScripterPackage/UI). Colors/fonts come from ClientArt/Theme,
-- art ids from ClientArt/Assets.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Kit = {}

-- Sets properties; Parent goes last so the instance is fully set up before it enters the tree.
local function assign(inst: Instance, props: { [string]: any }?)
	if not props then
		return
	end
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
end

-- Instance.new + children + properties. Parent is set last so the subtree is built off the DataModel.
function Kit.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	for _, child in children or {} do
		child.Parent = inst
	end
	assign(inst, props)
	return inst
end

-- Painted art at its native pixel size (callers scale the whole screen with a UIScale).
function Kit.image(
	className: string,
	image: string,
	x: number,
	y: number,
	w: number,
	h: number,
	props: { [string]: any }?
): any
	local inst = Kit.create(className, {
		BackgroundTransparency = 1,
		Image = image,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	})
	if inst:IsA("GuiButton") then
		inst.AutoButtonColor = false
	end
	assign(inst, props)
	return inst
end

-- Cream text with a dark outline and a drop shadow, matching the mockups' lettering.
-- Returns the container frame and the front label (set .Text on it via Kit.setText).
function Kit.label(text: string, textSize: number, props: { [string]: any }?): Frame
	local stroke = math.max(1.5, textSize / 16)
	local function layer(name: string, color: Color3, offset: number): TextLabel
		return Kit.create("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			FontFace = Theme.Font,
			Position = UDim2.fromOffset(0, offset),
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = color,
			TextSize = textSize,
			-- TextSize is capped at 100; bigger lettering fills its box instead.
			TextScaled = textSize > 100,
			ZIndex = if name == "Shadow" then 1 else 2,
		}, {
			Kit.create("UIStroke", {
				Color = if name == "Shadow" then Theme.Colors.Shadow else Theme.Colors.Outline,
				Thickness = stroke,
				LineJoinMode = Enum.LineJoinMode.Round,
			}),
		})
	end
	local frame = Kit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		layer("Shadow", Theme.Colors.Shadow, math.max(2, textSize / 24)),
		layer("Text", Theme.Colors.Text, 0),
	})
	assign(frame, props)
	return frame
end

function Kit.setText(label: Frame, text: string)
	for _, layer in label:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.Text = text
		end
	end
end

-- The coloured inner surface of a button, inside its frame/rim, in the button image's own pixels.
-- `flatBottom` is for tabs that sit flush on a panel (only the top corners are rounded).
export type Surface = { x: number, y: number, w: number, h: number, radius: number, flatBottom: boolean? }

export type PressOptions = {
	-- "scale" (default): the whole button grows on hover and squashes on press. For standalone buttons.
	-- "surface": a light/dark layer fitted to `surface` brightens on hover and darkens on press; the button keeps
	--            its size, so nothing spills over the gold rim or neighbouring tabs. For tabs and buttons in a row.
	style: ("scale" | "surface")?,
	surface: Surface?,
}

local function isEnabled(button: GuiButton): boolean
	return button.Active and button.Interactable
end

-- Hover / press feedback. A button that isn't Active or Interactable (e.g. an "In-Progress" quest button) shows no
-- feedback, and feedback clears as soon as it's disabled. Scale-style buttons should use AnchorPoint 0.5, 0.5.
function Kit.pressable(button: GuiButton, options: PressOptions?)
	local opts: PressOptions = options or {}
	local info = TweenInfo.new(Theme.Motion.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local hovering, pressing = false, false
	local apply: () -> ()

	if opts.style == "surface" then
		local s = assert(opts.surface, "surface style needs a surface rect")
		-- The holder clips at the surface's edges; for a flat bottom the rounded layer runs past the clip so only
		-- its top corners show.
		local holder = Kit.create("Frame", {
			Name = "Feedback",
			BackgroundTransparency = 1,
			ClipsDescendants = s.flatBottom == true,
			Position = UDim2.fromOffset(s.x, s.y),
			Size = UDim2.fromOffset(s.w, s.h),
			ZIndex = button.ZIndex + 1,
			Parent = button,
		})
		local layer = Kit.create("Frame", {
			Name = "Layer",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, if s.flatBottom then s.radius else 0),
			ZIndex = button.ZIndex + 1,
			Parent = holder,
		}, {
			Kit.create("UICorner", { CornerRadius = UDim.new(0, s.radius) }),
		})
		apply = function()
			local enabled = isEnabled(button)
			local color = if pressing and enabled then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
			local transparency = if not enabled then 1 elseif pressing then 0.82 elseif hovering then 0.8 else 1
			layer.BackgroundColor3 = color
			TweenService:Create(layer, info, { BackgroundTransparency = transparency }):Play()
		end
	else
		local scale = Kit.create("UIScale", { Parent = button })
		apply = function()
			local enabled = isEnabled(button)
			local value = if not enabled
				then 1
				elseif pressing then Theme.Motion.Press
				elseif hovering then Theme.Motion.Hover
				else 1
			TweenService:Create(scale, info, { Scale = value }):Play()
		end
	end

	button.MouseEnter:Connect(function()
		hovering = true
		apply()
	end)
	button.MouseLeave:Connect(function()
		hovering, pressing = false, false
		apply()
	end)
	button.MouseButton1Down:Connect(function()
		pressing = true
		apply()
	end)
	button.MouseButton1Up:Connect(function()
		pressing = false
		apply()
	end)
	button:GetPropertyChangedSignal("Active"):Connect(apply)
	button:GetPropertyChangedSignal("Interactable"):Connect(apply)
end

-- Turns a button on or off: off buttons don't take clicks or show hover/press feedback.
function Kit.setEnabled(button: GuiButton, enabled: boolean)
	button.Active = enabled
	button.Interactable = enabled
end

-- Quick scale bounce, e.g. when a counter changes.
function Kit.pop(scale: UIScale)
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function Kit.rect(r: { number }): (UDim2, UDim2)
	return UDim2.fromOffset(r[1], r[2]), UDim2.fromOffset(r[3], r[4])
end

-- Image button placed exactly over the same art baked into a window, centered so hover/press scale in place.
-- The image must be cropped tight to the button's visible shape: the button's rectangle is its clickable area.
function Kit.overlayButton(
	parent: Instance,
	name: string,
	image: string,
	r: { number },
	options: PressOptions?
): ImageButton
	local button = Kit.image("ImageButton", image, r[1] + r[3] / 2, r[2] + r[4] / 2, r[3], r[4], {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
		Parent = parent,
	})
	Kit.pressable(button, options)
	return button
end

export type Window = {
	gui: ScreenGui,
	root: Frame, -- mockup-sized canvas; place children in mockup pixels
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	onOpen: (fn: () -> ()) -> (), -- runs before each open (refresh contents here)
	connect: (connection: RBXScriptConnection) -> (), -- disconnected on destroy
	destroy: () -> (),
}

-- A centered popup window drawn from one painted image: fits the viewport, pops open, shrinks closed.
function Kit.window(parent: Instance, name: string, image: string, canvas: Vector2): Window
	local Workspace = game:GetService("Workspace")
	local connections: { RBXScriptConnection } = {}
	local openHooks: { () -> () } = {}
	local isOpen = false

	local gui = Kit.create("ScreenGui", {
		Name = name,
		DisplayOrder = 10,
		Enabled = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	-- Pop wraps Root so the open/close bounce doesn't fight the fit-to-screen scale.
	local pop = Kit.create("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local popScale = Kit.create("UIScale", { Parent = pop })
	local root = Kit.create("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(canvas.X, canvas.Y),
		Parent = pop,
	})
	local fitScale = Kit.create("UIScale", { Parent = root })
	Kit.image("ImageLabel", image, 0, 0, canvas.X, canvas.Y, { Name = "Window", Parent = root })

	-- Fit the whole canvas (decorations included: the art's canvas already contains the banner, vines and clouds) inside
	-- the ScreenGui's usable area, which excludes the top bar and device safe-area insets (notches), with a margin.
	local function rescale()
		local area = gui.AbsoluteSize
		if area.X < 1 or area.Y < 1 then
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			area = camera.ViewportSize
		end
		fitScale.Scale = math.min(area.X * 0.92 / canvas.X, area.Y * 0.92 / canvas.Y)
	end
	table.insert(connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale))
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale))
		end
		rescale()
	end
	table.insert(connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera))
	watchCamera()

	local window: Window
	window = {
		gui = gui,
		root = root,
		open = function()
			if isOpen then
				return
			end
			isOpen = true
			for _, fn in openHooks do
				fn()
			end
			gui.Enabled = true
			rescale()
			popScale.Scale = 0.85
			TweenService:Create(popScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end,
		close = function()
			if not isOpen then
				return
			end
			isOpen = false
			local tween =
				TweenService:Create(popScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Scale = 0.85,
				})
			tween.Completed:Connect(function()
				if not isOpen then
					gui.Enabled = false
				end
			end)
			tween:Play()
		end,
		isOpen = function()
			return isOpen
		end,
		onOpen = function(fn)
			table.insert(openHooks, fn)
		end,
		connect = function(connection)
			table.insert(connections, connection)
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			gui:Destroy()
		end,
	}
	gui.Parent = parent
	rescale()
	return window
end

-- "1d 02:03:04" / "02:03:04" countdown text.
function Kit.formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if d > 0 then
		return string.format("%dd %02d:%02d:%02d", d, h, m, s)
	end
	return string.format("%02d:%02d:%02d", h, m, s)
end

return Kit
