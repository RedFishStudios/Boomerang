-- Shop window: the limited egg banner with its countdown, four skin offers with Gift and Robux Buy buttons, and the
-- player's gem balance. Built from the art in the "Official Boomerang! UI" PDF (v2, page 5); the offer cards (names,
-- odds, prices, egg counts) are part of the painted art, so Shared.ShopData has to match it.
--
-- local shop = ShopScreen.mount(playerGui, { onBuy = function(offerIndex) ... end, onGift = ... })
-- shop.open()
-- shop.setGems(50)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Art = Assets.ShopScreen

local ShopScreen = {}

export type Callbacks = {
	onBuy: ((offerIndex: number) -> ())?,
	onGift: ((offerIndex: number) -> ())?,
}

export type Handle = Kit.Window & {
	setGems: (amount: number) -> (),
}

-- Mockup canvas and art rectangles {x, y, w, h}.
local CANVAS = Vector2.new(1714, 1140)
local CLOSE = { 1486, 90, 108, 104 }
local GEMS = { 1262, 95, 165, 78 } -- over the painted-out "50" in the blue gem pill
local TIMER = { 1228, 246, 270, 58 } -- over the painted-out countdown
-- Gift and Buy buttons, measured from the art (Gift ~22 px corners, Buy ~18 px).
local GIFT_X = { 559, 808, 1059, 1311 }
local GIFT_Y, GIFT_SIZE = 655, Vector2.new(197, 66)
local BUY_X = { 549, 799, 1051, 1302 }
local BUY_Y, BUY_SIZE = 731, Vector2.new(218, 75)

function ShopScreen.mount(parent: Instance, callbacks: Callbacks?): Handle
	local cb: Callbacks = callbacks or {}
	local window = Kit.window(parent, "ShopScreen", Art.Window, CANVAS)
	local root = window.root

	local gems = Kit.label("0", 60, { Name = "Gems", ZIndex = 2, Parent = root })
	gems.Position, gems.Size = Kit.rect(GEMS)
	local timer = Kit.label("", 40, { Name = "Timer", ZIndex = 2, Parent = root })
	timer.Position, timer.Size = Kit.rect(TIMER)

	for i = 1, #ShopData.Offers do
		Kit.overlayButton(root, "Gift" .. i, Art.Gift[i], { GIFT_X[i], GIFT_Y, GIFT_SIZE.X, GIFT_SIZE.Y }).Activated
			:Connect(function()
				if cb.onGift then
					cb.onGift(i)
				end
			end)
		Kit.overlayButton(root, "Buy" .. i, Art.Buy[i], { BUY_X[i], BUY_Y, BUY_SIZE.X, BUY_SIZE.Y }).Activated
			:Connect(function()
				if cb.onBuy then
					cb.onBuy(i)
				end
			end)
	end
	Kit.overlayButton(root, "Close", Art.Close, CLOSE).Activated:Connect(window.close)

	-- Countdown, ticking only while the window is open.
	local function tick()
		Kit.setText(timer, Kit.formatDuration(ShopData.Banner.endsAt - os.time()))
	end
	window.onOpen(function()
		tick()
		task.spawn(function()
			while window.isOpen() do
				task.wait(1)
				tick()
			end
		end)
	end)

	local handle = window :: Handle
	handle.setGems = function(amount: number)
		Kit.setText(gems, tostring(math.floor(amount)))
	end
	return handle
end

return ShopScreen
