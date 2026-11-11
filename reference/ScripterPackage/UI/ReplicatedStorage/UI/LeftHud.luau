-- Left-side HUD: coin counter, the Inventory / Shop / Index / Quests tiles, the AFK slide toggle and the Stats button.
-- Built from the art in the "Official Boomerang! UI" PDF (v2, page 2), laid out exactly as in the mockup.
-- Each tile is three stacked layers of the same size: the framed background, a large icon (its lower part runs behind
-- the ribbon), and the name ribbon with its label on top, so the ribbon always covers the icon and never the reverse.
--
-- local hud = LeftHud.mount(playerGui, {
-- 	onShop = function() ... end,
-- 	onAfkChanged = function(isAfk) ... end, -- fires when the player flips the toggle
-- })
-- hud.setCoins(30)
-- hud.setAfk(false) -- e.g. when the server clears AFK; does not fire onAfkChanged
-- hud.destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Theme = require(Shared:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local LeftHud = {}

export type Callbacks = {
	onInventory: (() -> ())?,
	onShop: (() -> ())?,
	onIndex: (() -> ())?,
	onQuests: (() -> ())?,
	onStats: (() -> ())?,
	onAfkChanged: ((isAfk: boolean) -> ())?,
}

export type Handle = {
	gui: ScreenGui,
	setCoins: (amount: number) -> (),
	setAfk: (isAfk: boolean) -> (),
	isAfk: () -> boolean,
	destroy: () -> (),
}

-- Everything below is in mockup pixels; a UIScale shrinks the canvas to screen size.
local CANVAS = Vector2.new(1011, 2150)
local SCREEN_WIDTH = 300 -- on-screen width of the HUD at the design viewport height
local DESIGN_VIEWPORT_HEIGHT = 1000
local MIN_SCALE, MAX_SCALE = 0.55, 1.1
local MAX_HEIGHT_SHARE = 0.94 -- the column never takes more than this share of the usable screen height

-- Art rectangles {x, y, w, h} (image size), measured from the mockup.
local COINS = { 23, 0, 930, 374 }
local COIN_TEXT = { 427, 95, 410, 215 } -- inside COINS, where the painted-out "30" sat (glyphs ~156 px tall)
local BUTTONS = {
	{ name = "Inventory", rect = { 16, 406, 484, 478 }, callback = "onInventory" },
	{ name = "Shop", rect = { 512, 406, 488, 478 }, callback = "onShop" },
	{ name = "Index", rect = { 16, 905, 484, 473 }, callback = "onIndex" },
	{ name = "Quests", rect = { 512, 905, 488, 473 }, callback = "onQuests" },
}

-- AFK slide toggle (from the AFK toggle mockups): red track with the knob on the left when off, green track with the
-- knob on the right when on. Parts below are in the toggle art's own pixels (1580 x 580) and scaled to AFK's width.
local AFK = { 0, 1388, 1011, 371 }
local AFK_ART = Vector2.new(1580, 580)
local AFK_HIT = { 55, 50, 1465, 495 } -- the wooden board only; the vines around it don't take clicks
local AFK_TRACK = { 208, 163, 600, 269 }
local AFK_KNOB_SIZE = 226
local AFK_KNOB_Y = 297 -- knob centre
local AFK_KNOB_X = { [false] = 345, [true] = 671 }
local AFK_SLIDE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Stats button (same frame, vines and size as AFK), directly beneath it. Art is 948 x 348 (AFK's proportions); the
-- hit rect is the wooden board, in that art's pixels.
local STATS = { 0, 1779, 1011, 371 }
local STATS_ART = Vector2.new(948, 348)
local STATS_HIT = { 30, 28, 888, 300 }

local function formatCoins(amount: number): string
	if amount >= 1e9 then
		return string.format("%.1fB", amount / 1e9)
	elseif amount >= 1e6 then
		return string.format("%.1fM", amount / 1e6)
	elseif amount >= 1e5 then
		return string.format("%.1fK", amount / 1e3)
	end
	return tostring(math.floor(amount))
end

function LeftHud.mount(parent: Instance, callbacks: Callbacks?): Handle
	local cb: { [string]: (() -> ())? } = (callbacks or {}) :: any
	local connections: { RBXScriptConnection } = {}

	local gui = Kit.create("ScreenGui", {
		Name = "LeftHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local root = Kit.create("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
		Parent = gui,
	})

	-- Coin counter.
	local coins = Kit.image("ImageLabel", Assets.LeftHud.Coins, COINS[1], COINS[2], COINS[3], COINS[4], {
		Name = "Coins",
		Parent = root,
	})
	local amount = Kit.label("0", 150, {
		Name = "Amount",
		Position = UDim2.fromOffset(COIN_TEXT[1], COIN_TEXT[2]),
		Size = UDim2.fromOffset(COIN_TEXT[3], COIN_TEXT[4]),
		Parent = coins,
	})
	for _, layer in amount:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	local amountPop = Kit.create("UIScale", { Parent = amount })

	-- Tiles. Anchored at their centers so hover/press scale in place.
	for _, spec in BUTTONS do
		local x, y, w, h = table.unpack(spec.rect)
		local art = (Assets.LeftHud :: any)[spec.name]
		local button = Kit.image("ImageButton", art.Bg, x + w / 2, y + h / 2, w, h, {
			Name = spec.name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = root,
		})
		-- Icon (already clipped to the coloured interior) above the background, ribbon + label above the icon.
		Kit.image("ImageLabel", art.Icon, 0, 0, w, h, { Name = "Icon", ZIndex = 2, Parent = button })
		Kit.image("ImageLabel", art.Ribbon, 0, 0, w, h, { Name = "Ribbon", ZIndex = 3, Parent = button })
		Kit.pressable(button)
		button.Activated:Connect(function()
			local fn = cb[spec.callback]
			if fn then
				fn()
			end
		end)
	end

	-- AFK slide toggle. A frame holds the art in its own pixels (scaled by a UIScale to AFK's width); a transparent
	-- button over the wooden board takes the clicks.
	local afk = false
	local k = AFK[3] / AFK_ART.X
	local afkToggle = Kit.create("Frame", {
		Name = "AfkToggle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(AFK[1] + AFK[3] / 2, AFK[2] + AFK[4] / 2),
		Size = UDim2.fromOffset(AFK_ART.X * k, AFK_ART.Y * k),
		Parent = root,
	})
	local art = Kit.create("Frame", {
		Name = "Art",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(AFK_ART.X, AFK_ART.Y),
		Parent = afkToggle,
	}, {
		Kit.create("UIScale", { Scale = k }),
	})
	local feedback = Kit.create("UIScale", { Parent = afkToggle })
	Kit.image("ImageLabel", Assets.LeftHud.AfkFrame, 0, 0, AFK_ART.X, AFK_ART.Y, { Name = "Frame", Parent = art })
	local trackOff = Kit.image("ImageLabel", Assets.LeftHud.AfkTrackOff, table.unpack(AFK_TRACK))
	trackOff.Name, trackOff.ZIndex, trackOff.Parent = "TrackOff", 2, art
	local trackOn = Kit.image("ImageLabel", Assets.LeftHud.AfkTrackOn, table.unpack(AFK_TRACK))
	trackOn.Name, trackOn.ZIndex, trackOn.ImageTransparency, trackOn.Parent = "TrackOn", 3, 1, art
	local knob =
		Kit.image("ImageLabel", Assets.LeftHud.AfkKnob, AFK_KNOB_X[false], AFK_KNOB_Y, AFK_KNOB_SIZE, AFK_KNOB_SIZE, {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 4,
			Parent = art,
		})
	local hit = Kit.create("TextButton", {
		Name = "Hit",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(AFK_HIT[1] * k, AFK_HIT[2] * k),
		Size = UDim2.fromOffset(AFK_HIT[3] * k, AFK_HIT[4] * k),
		ZIndex = 5,
		Parent = afkToggle,
	})

	local function showAfk(value: boolean, animate: boolean)
		afk = value
		local info = if animate then AFK_SLIDE else TweenInfo.new(0)
		TweenService:Create(knob, info, { Position = UDim2.fromOffset(AFK_KNOB_X[value], AFK_KNOB_Y) }):Play()
		TweenService:Create(trackOn, info, { ImageTransparency = if value then 0 else 1 }):Play()
	end

	-- Hover / press: the whole toggle grows a little and squashes when pressed.
	local hovering, pressing = false, false
	local function feedbackTo()
		local target = if pressing then Theme.Motion.Press elseif hovering then Theme.Motion.Hover else 1
		TweenService:Create(feedback, TweenInfo.new(Theme.Motion.Time), { Scale = target }):Play()
	end
	hit.MouseEnter:Connect(function()
		hovering = true
		feedbackTo()
	end)
	hit.MouseLeave:Connect(function()
		hovering, pressing = false, false
		feedbackTo()
	end)
	hit.MouseButton1Down:Connect(function()
		pressing = true
		feedbackTo()
	end)
	hit.MouseButton1Up:Connect(function()
		pressing = false
		feedbackTo()
	end)
	hit.Activated:Connect(function()
		showAfk(not afk, true)
		local fn = (callbacks or {} :: Callbacks).onAfkChanged
		if fn then
			fn(afk)
		end
	end)

	-- Stats button: the art scales to Stats' rect; a transparent button over the wooden board takes the clicks.
	local sk = STATS[3] / STATS_ART.X
	local stats = Kit.image(
		"ImageLabel",
		Assets.LeftHud.Stats,
		STATS[1] + STATS[3] / 2,
		STATS[2] + STATS[4] / 2,
		STATS_ART.X * sk,
		STATS_ART.Y * sk,
		{ Name = "Stats", AnchorPoint = Vector2.new(0.5, 0.5), Parent = root }
	)
	local statsHit = Kit.create("TextButton", {
		Name = "Hit",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(STATS_HIT[1] * sk, STATS_HIT[2] * sk),
		Size = UDim2.fromOffset(STATS_HIT[3] * sk, STATS_HIT[4] * sk),
		ZIndex = 2,
		Parent = stats,
	})
	local statsScale = Kit.create("UIScale", { Parent = stats })
	local statsHover, statsPress = false, false
	local function statsFeedback()
		local target = if statsPress then Theme.Motion.Press elseif statsHover then Theme.Motion.Hover else 1
		TweenService:Create(statsScale, TweenInfo.new(Theme.Motion.Time), { Scale = target }):Play()
	end
	statsHit.MouseEnter:Connect(function()
		statsHover = true
		statsFeedback()
	end)
	statsHit.MouseLeave:Connect(function()
		statsHover, statsPress = false, false
		statsFeedback()
	end)
	statsHit.MouseButton1Down:Connect(function()
		statsPress = true
		statsFeedback()
	end)
	statsHit.MouseButton1Up:Connect(function()
		statsPress = false
		statsFeedback()
	end)
	statsHit.Activated:Connect(function()
		local fn = cb.onStats
		if fn then
			fn()
		end
	end)

	-- Shrink the mockup-sized canvas to the screen, following viewport changes. The column keeps its design width,
	-- but shrinks further if it would be taller than the usable screen height (top bar and safe-area insets excluded).
	local scale = Kit.create("UIScale", { Parent = root })
	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			local fit = math.clamp(camera.ViewportSize.Y / DESIGN_VIEWPORT_HEIGHT, MIN_SCALE, MAX_SCALE)
			local usable = if gui.AbsoluteSize.Y > 1 then gui.AbsoluteSize.Y else camera.ViewportSize.Y
			scale.Scale = math.min(SCREEN_WIDTH / CANVAS.X * fit, usable * MAX_HEIGHT_SHARE / CANVAS.Y)
		end
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

	gui.Parent = parent
	rescale()

	local current: number? = nil
	local handle: Handle = {
		gui = gui,
		setCoins = function(value: number)
			if value == current then
				return
			end
			local first = current == nil
			current = value
			Kit.setText(amount, formatCoins(value))
			if not first then
				Kit.pop(amountPop)
			end
		end,
		setAfk = function(value: boolean)
			if value ~= afk then
				showAfk(value, true)
			end
		end,
		isAfk = function()
			return afk
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			gui:Destroy()
		end,
	}
	handle.setCoins(0)
	return handle
end

return LeftHud
