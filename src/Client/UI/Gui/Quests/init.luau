--[[
	Quests

	Description:
	The Quests menu, opened from the Quests button in the left lobby menu (MenuButtons). Laid out like the client's
	Quests art: a tab per quest pool (Daily, Weekly, Season), the open pool's reset countdown, and one card per quest
	(task, reward, progress bar, and a Claim / In-Progress / Claimed button), plus a small Reroll button on each card.
	Art: blank pieces made from the client's art (ClientArt/Assets.QuestsScreen): frame, card, tabs, timer pill, progress
	track, buttons. Every text, icon and picture is a Roblox instance on top, so nothing is painted into the images.
	The window is laid out in the frame image's own pixels (CANVAS) and fitted to the screen by the ClientArt Kit.
	Reads the replicated profile through QuestController; the server (QuestService) decides claims and rerolls.
]]

local QuestsGui = {}
QuestsGui.Type = "HUD"
QuestsGui.Open = false
QuestsGui.RequiresMouse = true -- // Frees the mouse in a locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local QuestController = require(ReplicatedStorage.Client.Core.QuestController)
local QuestLibrary = require(ReplicatedStorage.Shared.Library.QuestLibrary)
local RewardLibrary = require(ReplicatedStorage.Shared.Library.RewardLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).QuestsScreen

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Layout, in the frame image's pixels: {x, y, w, h}
local CANVAS = Vector2.new(1011, 568)
local TITLE = { 395, 16, 245, 54 } -- // Over the blank ribbon, right of the emblem
local CLOSE = { 871, 32, 64, 63 }
local CLOSE_ICON_INSET = 0.22 -- // X icon inset inside the close button
local TAB_RECTS = { { 106, 103, 189, 52 }, { 303, 103, 183, 52 }, { 494, 103, 185, 52 } }
local TAB_ICON = { 14, 8, 38, 38 } -- // Inside a tab
local TAB_TEXT = { 56, 6, 120, 42 }
local TIMER_PILL = { 732, 112, 162, 38 }
local TIMER_ICON = { 712, 104, 50, 50 }
local TIMER_TEXT = { 766, 114, 120, 34 }
local CARD_X = { 113, 379, 644 }
local CARD_Y = 170
local CARD_SIZE = Vector2.new(252, 307)
-- // Inside a card
local CARD_TITLE = { 14, 12, 224, 60 } -- // The quest's task, over the blue area
local CARD_REROLL = { 214, 112, 30, 30 } -- // Bottom-right corner of the blue area
local REWARD_LABEL = { 24, 158, 92, 26 }
local REWARD_ICON = { 128, 156, 30, 30 }
local REWARD_AMOUNT = { 160, 157, 80, 28 }
local PROGRESS_LABEL = { 13, 186, 226, 24 }
local TRACK = { 18, 212, 216, 24 }
local TRACK_INSET = 3 -- // Fill inset inside the track
local BUTTON = { 17, 244, 218, 50 }
local BUTTON_TEXT_INSET = { 0.1, 0.12 } -- // Text box inset inside a button (x, y)

local TEXT_SIZE = { Title = 40, Tab = 22, Timer = 20, CardTitle = 20, Label = 17, Amount = 18, Bar = 15, Button = 24 }
local FILL_COLOR = Color3.fromRGB(110, 196, 52)
local AMOUNT_COLOR = Color3.fromRGB(255, 214, 64)
local CARDS_PER_POOL = 3

-- // Tab icon per pool (pools without one show only their name)
local POOL_ICONS = {
	Daily = Art.IconClock,
	Weekly = Art.IconCalendar,
	Season = Art.IconSeason,
}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Card = {
	Frame: ImageLabel,
	Title: Frame,
	Amount: Frame,
	RewardIcon: ImageLabel,
	Fill: Frame,
	BarText: Frame,
	Button: ImageButton,
	ButtonText: Frame,
	Reroll: ImageButton,
}

type Tab = { PoolName: string, Button: ImageButton }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local window: Kit.Window
local tabs: { Tab } = {}
local cards: { Card } = {}
local timerText: Frame
local currentPool: string? = nil
local refreshQueued = false
local busySlot: string? = nil -- // "<pool>/<index>" while its claim or reroll request is pending

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function rect(r: { number }): (UDim2, UDim2)
	return UDim2.fromOffset(r[1], r[2]), UDim2.fromOffset(r[3], r[4])
end

local function image(name: string, imageId: string, r: { number }, parent: Instance, zIndex: number?): ImageLabel
	local label = Kit.create("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = imageId,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = zIndex or 2,
	})
	label.Position, label.Size = rect(r)
	label.Parent = parent
	return label
end

-- // Cream lettering with a dark outline (Kit.label), wrapped and shrunk to fit its box
local function outlined(name: string, text: string, size: number, r: { number }, parent: Instance, zIndex: number?): Frame
	local label = Kit.label(text, size, { Name = name, Parent = parent })
	label.Position, label.Size = rect(r)
	for _, layer in label:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextWrapped = true
			layer.TextScaled = true
			layer.ZIndex += (zIndex or 2) - 1
			Kit.create("UITextSizeConstraint", { MaxTextSize = size, Parent = layer })
		end
	end
	return label
end

-- // Dark brown lettering printed on the cream panel
local function printed(name: string, text: string, size: number, r: { number }, parent: Instance): TextLabel
	local label = Kit.create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = text,
		TextColor3 = Theme.Colors.Ink,
		TextSize = size,
		ZIndex = 3,
	})
	label.Position, label.Size = rect(r)
	label.Parent = parent
	return label
end

-- // Sends a claim or reroll request for a quest (one at a time), then redraws
local function requestForSlot(slotIndex: number, canRequest: (slot: QuestLibrary.QuestSlot) -> boolean, request: (poolName: string, slotIndex: number) -> boolean)
	local poolName = currentPool
	if busySlot or not poolName then
		return
	end
	local poolData = QuestController.getPoolData(poolName)
	local slot = poolData and poolData.Slots[slotIndex]
	if not slot or not canRequest(slot) then
		return
	end
	busySlot = `{poolName}/{slotIndex}`
	QuestsGui.refresh()
	task.spawn(function()
		request(poolName, slotIndex)
		busySlot = nil
		QuestsGui.refresh()
	end)
end

local function createCard(slotIndex: number, root: Frame): Card
	local frame = image(`Card{slotIndex}`, Art.Card, { CARD_X[slotIndex], CARD_Y, CARD_SIZE.X, CARD_SIZE.Y }, root, 2)
	frame.ScaleType = Enum.ScaleType.Stretch

	local title = outlined("Title", "", TEXT_SIZE.CardTitle, CARD_TITLE, frame, 3)
	printed("RewardLabel", "Reward:", TEXT_SIZE.Label, REWARD_LABEL, frame).TextXAlignment = Enum.TextXAlignment.Left
	local rewardIcon = image("RewardIcon", `rbxassetid://{Icons.CurrencyIcon}`, REWARD_ICON, frame, 3)
	local amount = outlined("Amount", "", TEXT_SIZE.Amount, REWARD_AMOUNT, frame, 3)
	for _, layer in amount:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextXAlignment = Enum.TextXAlignment.Left
			if layer.Name == "Text" then
				layer.TextColor3 = AMOUNT_COLOR
			end
		end
	end
	printed("ProgressLabel", "Progress", TEXT_SIZE.Label, PROGRESS_LABEL, frame)

	local track = image("Track", Art.ProgressTrack, TRACK, frame, 3)
	track.ScaleType = Enum.ScaleType.Stretch
	local fillArea = Kit.create("Frame", {
		Name = "FillArea",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(TRACK_INSET, TRACK_INSET),
		Size = UDim2.new(1, -2 * TRACK_INSET, 1, -2 * TRACK_INSET),
		ZIndex = 4,
		Parent = track,
	})
	local fill = Kit.create("Frame", {
		Name = "Fill",
		BackgroundColor3 = FILL_COLOR,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = fillArea,
	}, {
		Kit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Kit.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		}),
	})
	local barText = outlined("BarText", "", TEXT_SIZE.Bar, { 0, 0, TRACK[3], TRACK[4] }, track, 5)

	local button = Kit.create("ImageButton", {
		Name = "Button",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = Art.ButtonGrey,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	})
	button.Position, button.Size = rect(BUTTON)
	button.Parent = frame
	Kit.pressable(button)
	local buttonText = outlined("Label", "", TEXT_SIZE.Button, {
		BUTTON[3] * BUTTON_TEXT_INSET[1],
		BUTTON[4] * BUTTON_TEXT_INSET[2],
		BUTTON[3] * (1 - 2 * BUTTON_TEXT_INSET[1]),
		BUTTON[4] * (1 - 2 * BUTTON_TEXT_INSET[2]),
	}, button, 4)
	button.Activated:Connect(function()
		requestForSlot(slotIndex, QuestLibrary.isClaimable, QuestController.claim)
	end)

	local reroll = Kit.create("ImageButton", {
		Name = "Reroll",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = `rbxassetid://{Icons.QuestReroll}`,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	})
	reroll.Position, reroll.Size = rect(CARD_REROLL)
	reroll.Parent = frame
	Kit.pressable(reroll)
	reroll.Activated:Connect(function()
		requestForSlot(slotIndex, QuestLibrary.canReroll, QuestController.reroll)
	end)

	return {
		Frame = frame,
		Title = title,
		Amount = amount,
		RewardIcon = rewardIcon,
		Fill = fill,
		BarText = barText,
		Button = button,
		ButtonText = buttonText,
		Reroll = reroll,
	}
end

local function updateCard(card: Card, slotIndex: number, slot: QuestLibrary.QuestSlot?)
	local quest = slot and QuestLibrary.getQuest(slot.Id)
	card.Frame.Visible = quest ~= nil
	if not slot or not quest or not currentPool then
		return
	end

	local goal = quest.Objective.Goal
	local progress = math.min(slot.Progress, goal)
	Kit.setText(card.Title, QuestLibrary.getText(quest))
	TweenService:Create(card.Fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(if goal > 0 then progress / goal else 1, 1) }):Play()
	Kit.setText(card.BarText, `{progress} / {goal}`)

	local reward = QuestLibrary.getReward(quest)
	card.RewardIcon.Visible = reward.Type == "Currency"
	Kit.setText(card.Amount, if reward.Type == "Currency" then tostring(reward.Value) else RewardLibrary.getText(reward))

	local isBusy = busySlot == `{currentPool}/{slotIndex}`
	local canClaim = QuestLibrary.isClaimable(slot)
	card.Button.Image = if canClaim then Art.ButtonGreen else Art.ButtonGrey
	Kit.setEnabled(card.Button, canClaim and not isBusy)
	Kit.setText(
		card.ButtonText,
		if slot.Claimed then "Claimed!" elseif isBusy and canClaim then "..." elseif canClaim then "Claim" else "In-Progress"
	)

	-- // Reroll: hidden once the reward is claimed
	card.Reroll.Visible = QuestLibrary.canReroll(slot)
	Kit.setEnabled(card.Reroll, not isBusy)
	card.Reroll.ImageTransparency = if isBusy then 0.5 else 0
end

local function updateTimer()
	local pool = currentPool and QuestLibrary.getPool(currentPool)
	local now = os.time()
	local periodEnd = pool and QuestLibrary.getPeriodEnd(pool.ResetPeriod, now)
	Kit.setText(timerText, if periodEnd then Kit.formatDuration(periodEnd - now) else "")
end

local function selectPool(poolName: string)
	currentPool = poolName
	for _, tab in tabs do
		tab.Button.Image = if tab.PoolName == poolName then Art.TabOn else Art.TabOff
	end
	QuestsGui.refresh()
end

local function build()
	window = Kit.window(player:WaitForChild("PlayerGui"), "Quests", Art.Window, CANVAS)
	local root = window.root

	outlined("Title", "Quests", TEXT_SIZE.Title, TITLE, root, 2)

	-- // Close button: blank button + X icon
	local close = Kit.create("ImageButton", {
		Name = "Close",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = Art.CloseBlank,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CLOSE[1] + CLOSE[3] / 2, CLOSE[2] + CLOSE[4] / 2),
		Size = UDim2.fromOffset(CLOSE[3], CLOSE[4]),
		ZIndex = 3,
		Parent = root,
	})
	Kit.create("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = Art.IconClose,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromScale(CLOSE_ICON_INSET, CLOSE_ICON_INSET),
		Size = UDim2.fromScale(1 - 2 * CLOSE_ICON_INSET, 1 - 2 * CLOSE_ICON_INSET),
		ZIndex = 4,
		Parent = close,
	})
	Kit.pressable(close)
	close.Activated:Connect(function()
		QuestsGui.close()
	end)

	-- // One tab per pool, in pool order (first three)
	for index, poolName in QuestLibrary.getPoolNames() do
		local r = TAB_RECTS[index]
		if not r then
			break
		end
		local pool = QuestLibrary.getPool(poolName)
		local button = Kit.create("ImageButton", {
			Name = `Tab{poolName}`,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Image = Art.TabOff,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 2,
		})
		button.Position, button.Size = rect(r)
		button.Parent = root
		if POOL_ICONS[poolName] then
			image("Icon", POOL_ICONS[poolName], TAB_ICON, button, 3)
		end
		local label = (pool and pool.DisplayName or poolName):gsub(" Quests$", "")
		outlined("Label", label, TEXT_SIZE.Tab, if POOL_ICONS[poolName] then TAB_TEXT else { 6, 6, r[3] - 12, 42 }, button, 3)
		Kit.pressable(button)
		button.Activated:Connect(function()
			selectPool(poolName)
		end)
		table.insert(tabs, { PoolName = poolName, Button = button })
	end

	-- // Reset countdown of the open pool
	image("TimerPill", Art.TimerPill, TIMER_PILL, root, 2).ScaleType = Enum.ScaleType.Stretch
	image("TimerIcon", Art.IconClock, TIMER_ICON, root, 3)
	timerText = outlined("Timer", "", TEXT_SIZE.Timer, TIMER_TEXT, root, 3)

	for slotIndex = 1, CARDS_PER_POOL do
		cards[slotIndex] = createCard(slotIndex, root)
	end

	local firstPool = QuestLibrary.getPoolNames()[1]
	if firstPool then
		selectPool(firstPool)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function QuestsGui.refresh()
	if not currentPool then
		return
	end
	local poolData = QuestController.getPoolData(currentPool)
	local slots = (poolData and poolData.Slots) or {}
	for slotIndex, card in cards do
		updateCard(card, slotIndex, slots[slotIndex])
	end
	updateTimer()
end

function QuestsGui.open()
	QuestsGui.Open = true
	QuestsGui.refresh()
	window.open()
	UIController.supercede("Quests", "GamemodeHud")
	UIController.closeOtherMenus("Quests") -- // After superceding, so the closing menu doesn't restore the HUD
end

function QuestsGui.close()
	QuestsGui.Open = false
	window.close()
	UIController.unSupercede("Quests", "GamemodeHud")
end

function QuestsGui.toggle()
	if QuestsGui.Open then
		QuestsGui.close()
	else
		QuestsGui.open()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function QuestsGui.start()
	-- // Changes arrive together (e.g. new quests): refresh once on the next resumption cycle
	QuestController.QuestsChangedTasks:Add(function()
		if not QuestsGui.Open or refreshQueued then
			return
		end
		refreshQueued = true
		task.defer(function()
			refreshQueued = false
			QuestsGui.refresh()
		end)
	end)

	-- // Closes only when the player enters the arena, not on every arena player change; it can still be opened during a
	-- // round from its topbar button.
	local wasInArena = false
	GameStateLibrary.getGameStateData().LivingPlayersInArena:Subscribe(function(livingPlayers)
		local isInArena = table.find(livingPlayers or {}, player) ~= nil
		if isInArena and not wasInArena and QuestsGui.Open then
			QuestsGui.close()
		end
		wasInArena = isInArena
	end)

	-- // The countdown ticks while the menu is open
	task.spawn(function()
		while true do
			task.wait(1)
			if QuestsGui.Open then
				updateTimer()
			end
		end
	end)
end

build()

return QuestsGui
