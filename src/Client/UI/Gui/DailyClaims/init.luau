--[[
	DailyClaims

	Description:
	The Daily Rewards menu: a 7-day login streak (Shared/Referential/DailyRewards). Days 1-6 are small cards, day 7 the tall
	card on the right. Each card shows its day ("Today" for the claimable one), the reward (coin icon, or a render of the
	item / skin) and Claim / Claimed / Locked. Claiming asks the server (ClaimDailyReward). The calendar shows the current day.
	Opened from the Daily tile in MenuButtons (Y in Studio); in live servers it opens by itself when a reward is waiting.
	Looks: blank art in the style of the other new menus (ClientArt/Assets.DailyScreen; close button and green / grey
	buttons from the Quests menu), with every text drawn as instances (ClientArt/Kit). Laid out in the frame image's own
	pixels (CANVAS) and fitted to the screen by Kit.window.
]]

local DailyClaimsGui = {}
DailyClaimsGui.Type = "HUD"
DailyClaimsGui.Open = false
DailyClaimsGui.RequiresMouse = true -- // Frees the mouse in a locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Items = require(ReplicatedStorage.Shared.Referential.Items)
local DailyRewards = require(ReplicatedStorage.Shared.Referential.DailyRewards)
local Skins = require(ReplicatedStorage.Shared.Referential.Skins)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local UIController = require(ReplicatedStorage.Client.UI.UIController)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)
local ItemViewport = require(ReplicatedStorage.Client.UI.ItemViewport)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local Assets = require(ReplicatedStorage.Client.UI.ClientArt.Assets)

local Art = Assets.DailyScreen
local QuestArt = Assets.QuestsScreen -- // Close button, green / grey buttons

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Card = {
	DayLabel: TextLabel,
	Button: ImageButton,
	ButtonText: Frame,
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SECONDS_IN_DAY = 86400

-- // Layout in the frame art's pixels ({x, y, w, h})
local CANVAS = Vector2.new(1448, 900)
local TITLE = { 430, 40, 560, 88 } -- // On the ribbon
local TITLE_TEXT = "Daily Rewards"
local CLOSE = { 1262, 50, 112, 110 }
local CLOSE_ICON_INSET = 0.22
local CALENDAR = { 96, 14, 160, 160 } -- // Over the top-left corner
local CALENDAR_NUMBER = { 0.24, 0.43, 0.48, 0.42 } -- // Inside the calendar's blank page (scale)
local CALENDAR_INK = Color3.fromRGB(28, 34, 62)

-- // The card faces (their raised part) baked into the frame: days 1-6 left to right, top to bottom, then day 7
local SMALL = Vector2.new(220, 292)
local SMALL_X = { 205, 441, 677 }
local SMALL_Y = { 184, 504 }
local BIG = { 913, 184, 330, 612 }

-- // Inside a card, by card size
local CARD_LAYOUT = {
	Small = {
		Day = { 10, 12, 200, 40 },
		Preview = { 50, 56, 120, 106 },
		Reward = { 10, 166, 200, 42 },
		Button = { 16, 218, 188, 58 },
		TextSize = { Day = 30, Reward = 28, Button = 28 },
	},
	Big = {
		Day = { 15, 22, 300, 60 },
		Preview = { 40, 100, 250, 250 },
		Reward = { 15, 370, 300, 90 },
		Button = { 25, 496, 280, 86 },
		TextSize = { Day = 46, Reward = 40, Button = 44 },
	},
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local claimRemoteFunction = SimpleRemotes.getFunction("ClaimDailyReward")

local window: Kit.Window
local calendarNumber: TextLabel
local cards: { [number]: Card } = {}
local claiming = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function rect(r: { number }): (UDim2, UDim2)
	return UDim2.fromOffset(r[1], r[2]), UDim2.fromOffset(r[3], r[4])
end

-- // Cream lettering with a dark outline (Kit.label), wrapped and shrunk to fit its box
local function outlined(name: string, text: string, size: number, r: { number }, parent: Instance, zIndex: number?): Frame
	local label = Kit.label(text, size, { Name = name, ZIndex = zIndex or 2, Parent = parent })
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

-- // Dark brown lettering printed on the cream cards
local function printed(name: string, text: string, size: number, r: { number }, parent: Instance): TextLabel
	local label = Kit.create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = text,
		TextColor3 = Theme.Colors.Ink,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 3,
	}, {
		Kit.create("UITextSizeConstraint", { MaxTextSize = size }),
	})
	label.Position, label.Size = rect(r)
	label.Parent = parent
	return label
end

-- // Returns days claimed in the current cycle (0-7), the next claimable day, and whether it can be claimed now
local function getStreakState(playerData)
	local currentStreak = playerData.DailyRewards.Streak
	local lastClaim = playerData.DailyRewards.LastClaim
	local isClaimable = lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)

	-- // Server wraps back to day 1 after the final day is claimed
	local visualStreak = currentStreak
	if isClaimable and currentStreak >= DailyRewards.MaxStreakDays then
		visualStreak = 0
	end

	return visualStreak, visualStreak + 1, isClaimable
end

-- // The reward's text and what to show for it: a coin icon (Currency) or a model render (items, skins)
local function describeReward(reward): (string, string?, string?)
	if not reward then
		return "", nil, nil
	end
	if reward.Type == "Currency" then
		return tostring(reward.Value), `rbxassetid://{Icons.CurrencyIcon}`, nil
	elseif reward.Type == "Item" then
		local itemData = Items[reward.Value]
		return if itemData then itemData.Name or reward.Value else reward.Value, nil, itemData and itemData.Model
	elseif reward.Type == "Skin" then
		local skin = Skins[reward.Value]
		return if skin then `{skin.Name} Skin` else reward.Value, nil, skin and skin.Model
	end
	return "", nil, nil
end

-- // Day labels, buttons and the calendar from the player's streak
local function updateDayIndicators()
	local playerData = PlayerDataController.get()
	if not playerData then
		return
	end
	local visualStreak, nextVisualDay, isClaimable = getStreakState(playerData)

	-- // The current day: the claimable day, or the day already claimed today
	calendarNumber.Text = tostring(if isClaimable then nextVisualDay else math.max(visualStreak, 1))

	for dayNum, card in cards do
		local claimable = dayNum == nextVisualDay and isClaimable
		card.DayLabel.Text = if claimable then "Today" else `Day {dayNum}`
		card.Button.Image = if claimable then QuestArt.ButtonGreen else QuestArt.ButtonGrey
		Kit.setEnabled(card.Button, claimable and not claiming)
		Kit.setText(
			card.ButtonText,
			if dayNum <= visualStreak then "Claimed" elseif claimable and claiming then "..." elseif claimable then "Claim" else "Locked"
		)
	end
end

-- // Only currency is shown here; item and skin rewards are announced by ShopController / SkinController (ItemAcquired).
-- // An already-owned skin is converted to its FallbackCurrency.
local function notifyReward(claimedDay: number, convertedToCurrency: boolean)
	local reward = DailyRewards.Rewards[claimedDay]
	if reward and reward.Type == "Currency" then
		ItemAcquiredGui.acquiredCustomItem(Icons.CurrencyIcon, "Daily reward claimed!", `+{reward.Value} Currency`)
	elseif reward and reward.Type == "Skin" and convertedToCurrency then
		ItemAcquiredGui.acquiredCustomItem(
			Icons.CurrencyIcon,
			"Daily reward claimed!",
			`+{reward.FallbackCurrency} Currency (skin already owned)`
		)
	end
end

local function claim()
	if claiming then
		return
	end
	claiming = true
	updateDayIndicators()
	local success, claimedDay, convertedToCurrency = claimRemoteFunction:InvokeServer()
	claiming = false
	updateDayIndicators()
	if success and typeof(claimedDay) == "number" then
		notifyReward(claimedDay, convertedToCurrency == true)
	end
end

local function buildCard(dayNum: number, r: { number }, layout, root: Frame)
	local face = Kit.create("Frame", {
		Name = `Day{dayNum}`,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	face.Position, face.Size = rect(r)

	local dayLabel = printed("DayLabel", `Day {dayNum}`, layout.TextSize.Day, layout.Day, face)

	local rewardText, image, modelName = describeReward(DailyRewards.Rewards[dayNum])
	local preview = Kit.create("ImageLabel", {
		Name = "ItemImage",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
		Parent = face,
	})
	preview.Position, preview.Size = rect(layout.Preview)
	ItemViewport.setDisplay(preview, image, modelName)
	printed("Reward", rewardText, layout.TextSize.Reward, layout.Reward, face)

	local b = layout.Button
	local button = Kit.create("ImageButton", {
		Name = "Button",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = QuestArt.ButtonGrey,
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(b[1] + b[3] / 2, b[2] + b[4] / 2),
		Size = UDim2.fromOffset(b[3], b[4]),
		ZIndex = 3,
		Parent = face,
	})
	local buttonText = outlined("Label", "", layout.TextSize.Button, { b[3] * 0.08, b[4] * 0.12, b[3] * 0.84, b[4] * 0.76 }, button, 4)
	Kit.pressable(button)
	button.Activated:Connect(claim)

	cards[dayNum] = { DayLabel = dayLabel, Button = button, ButtonText = buttonText }
end

local function build()
	window = Kit.window(player:WaitForChild("PlayerGui"), "DailyClaims", Art.Window, CANVAS)
	local root = window.root

	outlined("Title", TITLE_TEXT, 64, TITLE, root, 2)

	-- // Calendar with the current day
	local calendar = Kit.create("ImageLabel", {
		Name = "Calendar",
		BackgroundTransparency = 1,
		Image = Art.Calendar,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
		Parent = root,
	})
	calendar.Position, calendar.Size = rect(CALENDAR)
	calendarNumber = Kit.create("TextLabel", {
		Name = "StreakNumber",
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = "1",
		TextColor3 = CALENDAR_INK,
		TextScaled = true,
		Position = UDim2.fromScale(CALENDAR_NUMBER[1], CALENDAR_NUMBER[2]),
		Size = UDim2.fromScale(CALENDAR_NUMBER[3], CALENDAR_NUMBER[4]),
		ZIndex = 4,
		Parent = calendar,
	})

	-- // Close button: the Quests menu's blank button + X icon
	local close = Kit.create("ImageButton", {
		Name = "Close",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = QuestArt.CloseBlank,
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
		Image = QuestArt.IconClose,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromScale(CLOSE_ICON_INSET, CLOSE_ICON_INSET),
		Size = UDim2.fromScale(1 - 2 * CLOSE_ICON_INSET, 1 - 2 * CLOSE_ICON_INSET),
		ZIndex = 4,
		Parent = close,
	})
	Kit.pressable(close)
	close.Activated:Connect(function()
		DailyClaimsGui.close()
	end)

	-- // Days 1-6 in the small cards, the last day in the tall one
	local dayNum = 0
	for _, y in SMALL_Y do
		for _, x in SMALL_X do
			dayNum += 1
			if dayNum < DailyRewards.MaxStreakDays then
				buildCard(dayNum, { x, y, SMALL.X, SMALL.Y }, CARD_LAYOUT.Small, root)
			end
		end
	end
	buildCard(DailyRewards.MaxStreakDays, BIG, CARD_LAYOUT.Big, root)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function DailyClaimsGui.open()
	UIController.closeOtherMenus("DailyClaims")
	updateDayIndicators()
	DailyClaimsGui.Open = true
	window.open()
end

function DailyClaimsGui.close()
	DailyClaimsGui.Open = false
	window.close()
end

function DailyClaimsGui.toggle()
	if DailyClaimsGui.Open then
		DailyClaimsGui.close()
	else
		DailyClaimsGui.open()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

-- // Built when required, so open / close work before start() (UIController.closeOtherMenus)
build()

function DailyClaimsGui.start()
	-- // The new Streak/LastClaim replicate after the remote returns, so refresh on arrival
	PlayerDataController.UpdatedTasks:Add(function(_, _, path)
		if path[1] == "DailyRewards" and DailyClaimsGui.Open then
			updateDayIndicators()
		end
	end)

	-- // Opened from the Daily tile in MenuButtons
	if RunService:IsStudio() then
		ContextActionService:BindAction("testopendailyclaimsmenu", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				DailyClaimsGui.toggle()
			end
		end, false, Enum.KeyCode.Y)
	else
		local playerData = PlayerDataController.get()
		local lastClaim = playerData.DailyRewards.LastClaim
		local isClaimable = lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)
		if isClaimable then
			DailyClaimsGui.open()
		end
	end
end

return DailyClaimsGui
