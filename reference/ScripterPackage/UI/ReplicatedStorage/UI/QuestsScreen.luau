-- Quests window: Daily / Weekly / Season tabs, a reset countdown, and three quest cards with reward, progress bar and
-- an In-Progress / Claim / Claimed button. Built from the art in the "Official Boomerang! UI" PDF (v2, page 5). The
-- card pictures and reward icons are part of the painted art; titles, amounts and progress are live.
--
-- local quests = QuestsScreen.mount(playerGui, { onClaim = function(questId) ... end })
-- quests.open()
-- quests.setProgress("D2", 1, false) -- from the server's Quest_<id> / QuestClaimed_<id> attributes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local QuestData = require(Shared:WaitForChild("QuestData"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Art = Assets.QuestsScreen

local QuestsScreen = {}

export type Callbacks = {
	onClaim: ((questId: string) -> ())?,
}

export type Handle = Kit.Window & {
	setProgress: (questId: string, progress: number, claimed: boolean) -> (),
}

-- Mockup canvas and art rectangles {x, y, w, h}.
local CANVAS = Vector2.new(1714, 962)
local CLOSE = { 1476, 54, 108, 106 }
local TIMER = { 1312, 198, 200, 56 }
-- Tabs: each image is cropped to that tab's own outline (gold rim included, top corners rounded, flush with the
-- panel), so on/off images cover the baked tab exactly. `surface` is the coloured area inside the rim, where hover
-- and press feedback is drawn.
local TABS = {
	Daily = {
		on = Art.TabDailyOn,
		off = Art.TabDailyOff,
		rect = { 180, 175, 320, 88 },
		surface = { x = 13, y = 9, w = 301, h = 79, radius = 12, flatBottom = true },
	},
	Weekly = {
		on = Art.TabWeeklyOn,
		off = Art.TabWeeklyOff,
		rect = { 514, 175, 311, 88 },
		surface = { x = 8, y = 13, w = 295, h = 75, radius = 12, flatBottom = true },
	},
	Season = {
		on = Art.TabSeasonOn,
		off = Art.TabSeasonOff,
		rect = { 837, 175, 313, 88 },
		surface = { x = 8, y = 13, w = 297, h = 75, radius = 12, flatBottom = true },
	},
}

-- Per card (left to right).
local CARD_X = { 230, 680, 1130 }
local TITLE_Y, TITLE_SIZE = 302, Vector2.new(362, 64)
local AMOUNT_X = { 500, 935, 1395 }
local AMOUNT_Y, AMOUNT_SIZE = 548, Vector2.new(104, 62)
local BAR_X = { 220, 670, 1118 }
local BAR_Y, BAR_SIZE = 646, Vector2.new(376, 50)
local BAR_INSET = { 10, 6, 356, 38 } -- fill area inside the empty bar
-- Card button: a wide rectangle with ~12 px corners (measured: 364 x 80).
local BUTTON_X = { 226, 676, 1126 }
local BUTTON_Y, BUTTON_SIZE = 705, Vector2.new(364, 80)
local BUTTON_TEXT = { 40, 8, 284, 62 }
local BUTTON_SURFACE = { x = 4, y = 4, w = 356, h = 72, radius = 10 }

local FILL_COLOR = Color3.fromRGB(110, 196, 52)
local AMOUNT_COLOR = Color3.fromRGB(255, 214, 64)

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function QuestsScreen.mount(parent: Instance, callbacks: Callbacks?): Handle
	local cb: Callbacks = callbacks or {}
	local window = Kit.window(parent, "QuestsScreen", Art.Window, CANVAS)
	local root = window.root

	local progress: { [string]: number } = {}
	local claimed: { [string]: boolean } = {}
	local tab = QuestData.Tabs[1]

	local timer = Kit.label("", 40, { Name = "Timer", ZIndex = 2, Parent = root })
	timer.Position, timer.Size = Kit.rect(TIMER)

	type Card = { title: Frame, amount: Frame, fill: Frame, barText: Frame, button: ImageButton, buttonText: Frame }
	local cards: { Card } = {}
	for i = 1, 3 do
		local title = Kit.label("", 46, { Name = "Title" .. i, ZIndex = 2, Parent = root })
		title.Position, title.Size = Kit.rect({ CARD_X[i], TITLE_Y, TITLE_SIZE.X, TITLE_SIZE.Y })
		local amount = Kit.label("", 48, { Name = "Amount" .. i, ZIndex = 2, Parent = root })
		amount.Position, amount.Size = Kit.rect({ AMOUNT_X[i], AMOUNT_Y, AMOUNT_SIZE.X, AMOUNT_SIZE.Y })
		local amountText = amount:FindFirstChild("Text") :: TextLabel
		amountText.TextColor3 = AMOUNT_COLOR

		local bar = Kit.create("Frame", {
			Name = "Bar" .. i,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(BAR_X[i], BAR_Y),
			Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
			ZIndex = 2,
			Parent = root,
		})
		local track = Kit.create("Frame", {
			Name = "Track",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 2,
			Parent = bar,
		})
		track.Position, track.Size = Kit.rect(BAR_INSET)
		local fill = Kit.create("Frame", {
			Name = "Fill",
			BackgroundColor3 = FILL_COLOR,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			ZIndex = 2,
			Parent = track,
		}, {
			Kit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Kit.create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
			}),
		})
		local barText = Kit.label("", 34, { Name = "Text", ZIndex = 3, Parent = bar })

		local button = Kit.overlayButton(
			root,
			"Button" .. i,
			Art.ButtonGrey,
			{ BUTTON_X[i], BUTTON_Y, BUTTON_SIZE.X, BUTTON_SIZE.Y },
			{ style = "surface", surface = BUTTON_SURFACE }
		)
		local buttonText = Kit.label("", 60, { Name = "Label", ZIndex = 4, Parent = button })
		buttonText.Position, buttonText.Size = Kit.rect(BUTTON_TEXT)
		button.Activated:Connect(function()
			local quest = tab.quests[i]
			if quest and cb.onClaim and not claimed[quest.id] and (progress[quest.id] or 0) >= quest.goal then
				cb.onClaim(quest.id)
			end
		end)

		cards[i] = {
			title = title,
			amount = amount,
			fill = fill,
			barText = barText,
			button = button,
			buttonText = buttonText,
		}
	end

	local tabButtons: { [string]: ImageButton } = {}

	local function refresh()
		for id, button in tabButtons do
			button.Image = if id == tab.id then TABS[id].on else TABS[id].off
		end
		for i, card in cards do
			local quest = tab.quests[i]
			if not quest then
				continue
			end
			local value = math.min(progress[quest.id] or 0, quest.goal)
			local done = value >= quest.goal
			local isClaimed = claimed[quest.id] == true
			Kit.setText(card.title, quest.title)
			Kit.setText(card.amount, formatNumber(quest.reward.amount))
			Kit.setText(card.barText, `{formatNumber(value)}/{formatNumber(quest.goal)}`)
			TweenService:Create(card.fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(value / quest.goal, 1) })
				:Play()
			card.button.Image = if done and not isClaimed then Art.ButtonGreen else Art.ButtonGrey
			Kit.setEnabled(card.button, done and not isClaimed)
			Kit.setText(card.buttonText, if isClaimed then "Claimed!" elseif done then "Claim" else "In-Progress")
		end
	end

	for _, t in QuestData.Tabs do
		local spec = TABS[t.id]
		local button = Kit.overlayButton(root, "Tab" .. t.id, spec.off, spec.rect, {
			style = "surface",
			surface = spec.surface,
		})
		button.Activated:Connect(function()
			tab = t
			refresh()
		end)
		tabButtons[t.id] = button
	end
	Kit.overlayButton(root, "Close", Art.Close, CLOSE).Activated:Connect(window.close)

	-- Reset countdown for the open tab, ticking only while the window is open.
	local function tick()
		local _, ends = QuestData.period(tab.id, os.time())
		Kit.setText(timer, Kit.formatDuration(ends - os.time()))
	end
	window.onOpen(function()
		refresh()
		tick()
		task.spawn(function()
			while window.isOpen() do
				task.wait(1)
				tick()
			end
		end)
	end)

	local handle = window :: Handle
	handle.setProgress = function(questId: string, value: number, isClaimed: boolean)
		progress[questId] = value
		claimed[questId] = isClaimed
		if QuestData.tabOf[questId] == tab.id then
			refresh()
		end
	end
	refresh()
	return handle
end

return QuestsScreen
