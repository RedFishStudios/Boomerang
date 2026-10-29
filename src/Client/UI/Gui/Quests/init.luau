--[[
	Quests (T-143)

	Description:
	The Quests menu, opened from the Quests button in the left lobby menu (MenuButtons). A vertical scrolling list: each
	quest pool in order (Daily, then Weekly) gets a header with its name and reset countdown, then one full-width card
	per quest: what to do, a progress bar, the reward and a Reroll button. The reward itself becomes a green button
	once the quest is finished: clicking it claims the reward. Reroll swaps that quest (in its place) for a new one.
	PLACEHOLDER LOOK: there's no quests art yet, so it borrows the Stats menu's frame and exit button and draws
	everything else as plain frames. The layout is a first draft to decide the real art from.
	Built entirely in code with CreateElement. Reads the replicated profile through QuestController; claiming asks the
	server (QuestService), which decides.
]]

local QuestsGui = {}
QuestsGui.Type = "HUD"
QuestsGui.Open = false
QuestsGui.RequiresMouse = true -- // Clickable menu: frees the mouse in the locked camera (MouseUnlockController)

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
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local CreateElement = require(ReplicatedStorage.Shared.Utils.CreateElement)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Look (placeholders until the quests art exists)
local TEXT_COLOR = Color3.fromRGB(92, 52, 20)
local CARD_COLOR = Color3.fromRGB(245, 225, 190)
local CARD_DONE_COLOR = Color3.fromRGB(215, 240, 190)
local BAR_BACK_COLOR = Color3.fromRGB(200, 170, 130)
local BAR_FILL_COLOR = Color3.fromRGB(110, 200, 90)
local CLAIM_COLOR = Color3.fromRGB(90, 190, 70)
local REROLL_COLOR = Color3.fromRGB(70, 140, 235)
local CLAIMED_TEXT_TRANSPARENCY = 0.4
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local CONTAINER_IMAGE = "rbxassetid://107079429198573" -- // Borrowed from the Stats menu (placeholder)
local EXIT_IMAGE = "rbxassetid://83841981001141"
local CONTAINER_ASPECT_RATIO = 1.46190941
local CARDS_PER_POOL = 3 -- // Card slots drawn per pool (a pool with more quests shows its first ones)
local CARD_ASPECT_RATIO = 6.5 -- // Card width / height (cards span the list's width)
local HEADER_ASPECT_RATIO = 13 -- // Pool header width / height
local LIST_PADDING_PIXELS = 6 -- // Gap between rows in the list
local SCROLLBAR_THICKNESS = 6

local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local SECONDS_IN_MINUTE = 60
local SECONDS_IN_HOUR = 3600
local SECONDS_IN_DAY = 86400

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Card = {
	Frame: Frame,
	Description: TextLabel,
	Fill: Frame,
	ProgressText: TextLabel,
	Reward: TextButton, -- // The reward; a green button while it can be claimed
	RewardText: TextLabel,
	RewardIcon: ImageLabel,
	Reroll: ImageButton,
}

type Section = {
	PoolName: string,
	Header: Frame,
	Timer: TextLabel,
	Cards: { Card },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local QuestsScreenGui: ScreenGui
local Container: GuiObject
local sections: { Section } = {}
local List: ScrollingFrame
local containerGoalPosition: UDim2
local containerOffscreenPosition: UDim2
local activeTween: Tween?
local refreshQueued = false
local busySlot: string? = nil -- // "<pool>/<index>" while its claim or reroll request is out

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // TextLabel with the menu's shared text look; [properties] override the defaults
local function createLabel(properties: { [string]: any }, children: { Instance }?)
	local merged = {
		BackgroundTransparency = 1,
		TextColor3 = TEXT_COLOR,
		TextScaled = true,
		FontFace = FONT,
		TextWrapped = true,
	}
	for property, value in properties do
		merged[property] = value
	end
	return CreateElement("TextLabel", merged, children)
end

local function formatTimeLeft(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= SECONDS_IN_DAY then
		local days = math.floor(seconds / SECONDS_IN_DAY)
		return `{days}d {math.floor((seconds % SECONDS_IN_DAY) / SECONDS_IN_HOUR)}h`
	elseif seconds >= SECONDS_IN_HOUR then
		return `{math.floor(seconds / SECONDS_IN_HOUR)}h {math.floor((seconds % SECONDS_IN_HOUR) / SECONDS_IN_MINUTE)}m`
	end
	return `{math.floor(seconds / SECONDS_IN_MINUTE)}m {seconds % SECONDS_IN_MINUTE}s`
end

-- // Sends a claim or reroll request for one quest (one request at a time), then redraws
local function requestForSlot(poolName: string, slotIndex: number, canRequest: (slot: QuestLibrary.QuestSlot) -> boolean, request: (poolName: string, slotIndex: number) -> boolean)
	if busySlot then
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

local function onRewardClicked(poolName: string, slotIndex: number)
	requestForSlot(poolName, slotIndex, QuestLibrary.isClaimable, QuestController.claim)
end

local function onRerollClicked(poolName: string, slotIndex: number)
	requestForSlot(poolName, slotIndex, QuestLibrary.canReroll, QuestController.reroll)
end

local function createCard(poolName: string, slotIndex: number): Card
	local description = createLabel({
		Name = "Description",
		Position = UDim2.fromScale(0.03, 0.1),
		Size = UDim2.fromScale(0.6, 0.4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})

	local fill = CreateElement("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = BAR_FILL_COLOR,
		BorderSizePixel = 0,
	}, { CreateElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

	local progressText = createLabel({
		Name = "ProgressText",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		ZIndex = 2,
		Text = "0 / 0",
		TextColor3 = Color3.new(1, 1, 1),
	}, { CreateElement("UIStroke", { Color = TEXT_COLOR, Thickness = 1.5 }) })

	local bar = CreateElement("Frame", {
		Name = "ProgressBar",
		Position = UDim2.fromScale(0.03, 0.58),
		Size = UDim2.fromScale(0.6, 0.3),
		BackgroundColor3 = BAR_BACK_COLOR,
		BorderSizePixel = 0,
	}, {
		CreateElement("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		fill,
		progressText,
	})

	local rewardIcon = CreateElement("ImageLabel", {
		Name = "RewardIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.08, 0.5),
		Size = UDim2.fromScale(0.3, 0.75),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{Icons.CurrencyIcon}`,
		ScaleType = Enum.ScaleType.Fit,
	})

	local rewardText = createLabel({
		Name = "RewardText",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.4, 0.5),
		Size = UDim2.fromScale(0.55, 0.7),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})

	-- // The reward: a plain label until the quest is finished, then a green button that claims it
	local reward = CreateElement("TextButton", {
		Name = "Reward",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.855, 0.5),
		Size = UDim2.fromScale(0.2, 0.62),
		BackgroundColor3 = CLAIM_COLOR,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		MouseButton1Click = function()
			onRewardClicked(poolName, slotIndex)
		end,
	}, {
		CreateElement("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
		CreateElement("UIStroke", { Name = "Stroke", Color = TEXT_COLOR, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Enabled = false }),
		rewardIcon,
		rewardText,
	})

	local reroll = CreateElement("ImageButton", {
		Name = "Reroll",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.975, 0.5),
		Size = UDim2.fromScale(0.1, 0.62),
		BackgroundColor3 = REROLL_COLOR,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Image = `rbxassetid://{Icons.QuestReroll}`,
		ScaleType = Enum.ScaleType.Fit,
		MouseButton1Click = function()
			onRerollClicked(poolName, slotIndex)
		end,
	}, {
		CreateElement("UIAspectRatioConstraint", {}),
		CreateElement("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
		CreateElement("UIStroke", { Color = TEXT_COLOR, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		CreateElement("UIPadding", {
			PaddingTop = UDim.new(0.15, 0),
			PaddingBottom = UDim.new(0.15, 0),
			PaddingLeft = UDim.new(0.15, 0),
			PaddingRight = UDim.new(0.15, 0),
		}),
	})

	local frame = CreateElement("Frame", {
		Name = `{poolName}Quest{slotIndex}`,
		Size = UDim2.new(1, 0, 0, 40), -- // Height is set by resizeList
		BackgroundColor3 = CARD_COLOR,
		BorderSizePixel = 0,
	}, {
		CreateElement("UICorner", { CornerRadius = UDim.new(0.15, 0) }),
		CreateElement("UIStroke", { Color = TEXT_COLOR, Thickness = 2 }),
		description,
		bar,
		reward,
		reroll,
	})

	return {
		Frame = frame,
		Description = description,
		Fill = fill,
		ProgressText = progressText,
		Reward = reward,
		RewardText = rewardText,
		RewardIcon = rewardIcon,
		Reroll = reroll,
	}
end

-- // A pool's header row and its cards, laid out in the list from `order` (headers and cards share the list's LayoutOrder)
local function createSection(poolName: string, order: number): Section
	local pool = QuestLibrary.getPool(poolName)
	local cards: { Card } = {}

	local title = createLabel({
		Name = "Title",
		Size = UDim2.fromScale(0.6, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if pool then pool.DisplayName else poolName,
	})
	local timer = createLabel({
		Name = "Timer",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.38, 0.75),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})
	local header = CreateElement("Frame", {
		Name = `{poolName}Header`,
		LayoutOrder = order * 100,
		Size = UDim2.new(1, 0, 0, 20), -- // Height is set by resizeList
		BackgroundTransparency = 1,
	}, { title, timer })
	header.Parent = List

	for slotIndex = 1, CARDS_PER_POOL do
		local card = createCard(poolName, slotIndex)
		card.Frame.LayoutOrder = order * 100 + slotIndex
		card.Frame.Parent = List
		cards[slotIndex] = card
	end

	return { PoolName = poolName, Header = header, Timer = timer, Cards = cards }
end

-- // Rows have pixel heights (a scrolling list can't size them by scale): kept in proportion to the list's width
local function resizeList()
	local width = List.AbsoluteSize.X - SCROLLBAR_THICKNESS * 2
	for _, section in sections do
		section.Header.Size = UDim2.new(1, 0, 0, math.floor(width / HEADER_ASPECT_RATIO))
		for _, card in section.Cards do
			card.Frame.Size = UDim2.new(1, 0, 0, math.floor(width / CARD_ASPECT_RATIO))
		end
	end
end

local function createGui(): ScreenGui
	-- // The parchment inside the brick border of the (borrowed) frame image, as in the Stats menu
	List = CreateElement("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromScale(0.118, 0.24),
		Size = UDim2.fromScale(0.765, 0.548),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = SCROLLBAR_THICKNESS,
		ScrollBarImageColor3 = TEXT_COLOR,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, {
		CreateElement("UIListLayout", {
			Padding = UDim.new(0, LIST_PADDING_PIXELS),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		CreateElement("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, SCROLLBAR_THICKNESS * 2),
		}),
	})
	for order, poolName in QuestLibrary.getPoolNames() do
		table.insert(sections, createSection(poolName, order))
	end

	local title = createLabel({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.128),
		Size = UDim2.fromScale(0.36, 0.095),
		ZIndex = 2,
		Text = "QUESTS",
		TextColor3 = Color3.new(1, 1, 1),
	}, { CreateElement("UIStroke", { Color = TEXT_COLOR, Thickness = 3 }) })

	local exit = CreateElement("ImageButton", {
		Name = "Exit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.955, 0.1),
		Size = UDim2.fromScale(0.085, 0.085),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Image = EXIT_IMAGE,
		MouseButton1Click = function()
			QuestsGui.close()
		end,
	}, { CreateElement("UIAspectRatioConstraint", {}) })

	Container = CreateElement("ImageLabel", {
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.85),
		BackgroundTransparency = 1,
		Image = CONTAINER_IMAGE,
		ScaleType = Enum.ScaleType.Fit,
	}, {
		CreateElement("UIAspectRatioConstraint", { AspectRatio = CONTAINER_ASPECT_RATIO }),
		title,
		exit,
		List,
	})

	return CreateElement("ScreenGui", {
		Name = "Quests",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, { Container })
end

local function updateCard(card: Card, poolName: string, slotIndex: number, slot: QuestLibrary.QuestSlot?)
	local quest = slot and QuestLibrary.getQuest(slot.Id)
	card.Frame.Visible = quest ~= nil
	if not slot or not quest then
		return
	end

	local goal = quest.Objective.Goal
	local progress = math.min(slot.Progress, goal)
	card.Description.Text = QuestLibrary.getText(quest)
	card.Fill.Size = UDim2.fromScale(if goal > 0 then progress / goal else 1, 1)
	card.Fill.Visible = progress > 0
	card.ProgressText.Text = `{progress} / {goal}`

	local reward = QuestLibrary.getReward(quest)
	local isComplete = progress >= goal
	local isBusy = busySlot == `{poolName}/{slotIndex}`
	local canClaim = QuestLibrary.isClaimable(slot)
	card.Frame.BackgroundColor3 = if isComplete then CARD_DONE_COLOR else CARD_COLOR

	-- // Reward: green button only while it can be claimed
	card.Reward.Active = canClaim and not isBusy
	card.Reward.BackgroundTransparency = if canClaim then 0 else 1
	card.Reward.AutoButtonColor = canClaim
	local stroke = card.Reward:FindFirstChild("Stroke")
	if stroke then
		(stroke :: UIStroke).Enabled = canClaim
	end
	card.RewardIcon.Visible = reward.Type == "Currency" and not slot.Claimed
	card.RewardText.Text = if slot.Claimed then "Claimed" elseif isBusy and canClaim then "..." else RewardLibrary.getText(reward)
	card.RewardText.TextColor3 = if canClaim then Color3.new(1, 1, 1) else TEXT_COLOR
	card.RewardText.TextTransparency = if slot.Claimed then CLAIMED_TEXT_TRANSPARENCY else 0

	-- // Reroll: not for a quest whose reward was already claimed
	card.Reroll.Visible = QuestLibrary.canReroll(slot)
	card.Reroll.Active = not isBusy
	card.Reroll.ImageTransparency = if isBusy then 0.5 else 0
end

local function updateTimers()
	local now = os.time()
	for _, section in sections do
		local pool = QuestLibrary.getPool(section.PoolName)
		local periodEnd = pool and QuestLibrary.getPeriodEnd(pool.ResetPeriod, now)
		section.Timer.Text = if periodEnd then `New in {formatTimeLeft(periodEnd - now)}` else ""
	end
end

local function playContainerTween(tweenInfo: TweenInfo, goalPosition: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(Container, tweenInfo, { Position = goalPosition })
	activeTween:Play()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function QuestsGui.refresh()
	for _, section in sections do
		local poolData = QuestController.getPoolData(section.PoolName)
		local slots = (poolData and poolData.Slots) or {}
		for slotIndex, card in section.Cards do
			updateCard(card, section.PoolName, slotIndex, slots[slotIndex])
		end
	end
	updateTimers()
end

function QuestsGui.open()
	QuestsGui.Open = true
	QuestsScreenGui.Enabled = true
	QuestsGui.refresh()
	resizeList()
	Container.Position = containerOffscreenPosition
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
	UIController.supercede("Quests", "GamemodeHud")
end

function QuestsGui.close()
	QuestsGui.Open = false
	playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
	UIController.unSupercede("Quests", "GamemodeHud")

	task.delay(CONTAINER_TWEEN_INFO_OUT.Time, function()
		if not QuestsGui.Open then
			QuestsScreenGui.Enabled = false
		end
	end)
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

local function _init()
	QuestsScreenGui = createGui()
	QuestsScreenGui.Parent = player:WaitForChild("PlayerGui")

	containerGoalPosition = Container.Position
	containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)

	List:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeList)
end

function QuestsGui.start()
	-- // Many changes arrive together (e.g. new quests): refresh once, on the next resumption cycle
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

	-- // A lobby menu: it closes when the player goes into the arena (the lobby buttons hide then too)
	GameStateLibrary.getGameStateData().LivingPlayersInArena:Subscribe(function(livingPlayers)
		if QuestsGui.Open and table.find(livingPlayers or {}, player) then
			QuestsGui.close()
		end
	end)

	-- // Reset countdowns tick while the menu is open
	task.spawn(function()
		while true do
			task.wait(1)
			if QuestsGui.Open then
				updateTimers()
			end
		end
	end)
end

_init()

return QuestsGui
