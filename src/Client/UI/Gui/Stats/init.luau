--[[
	Stats (T-074)

	Description:
	The Stats menu, opened from the Stats button in the left lobby menu (MenuButtons).
	Left: six cards with the player's main lifetime stats (time played, eliminations, defeats, games played,
	games won, throws). Right: a scrolling list of smaller stats (times each ability was used, times each pickup was collected).
	Built from Stats.rbxmx (DailyClaims' base frame and cards for now) and StatListingTemplate.rbxmx (placeholder row).
	Reads the replicated profile (PlayerDataController); the stats are written by LifetimeStatsService on the server.
]]

local StatsGui = {}
StatsGui.Type = "HUD"
StatsGui.Open = false
StatsGui.RequiresMouse = true -- // Clickable menu: frees the mouse in the locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SECONDS_IN_HOUR = 3600
local SECONDS_IN_MINUTE = 60

-- // Profile fields shown on the cards, keyed by card name in Stats.rbxmx
local CARD_FIELDS = {
	TimePlayed = "TimePlayed",
	Elims = "Elims",
	Defeats = "Defeats",
	RoundsPlayed = "RoundsPlayed",
	Wins = "Wins",
	Throws = "Throws",
}

local LISTING_ASPECT_RATIO = 7 -- // Row width / height
local ABILITY_ORDER_OFFSET = 0
local PICKUP_ORDER_OFFSET = 1000 -- // Pickups are listed after abilities

local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local AbilityLogics = ReplicatedStorage.Shared.Logics.AbilityLogics
local PickupLogics = ReplicatedStorage.Shared.Logics.PickupLogics

local StatsScreenGui: ScreenGui = script:WaitForChild("Stats")
local ListingTemplate: Frame = script:WaitForChild("StatListingTemplate")

local Container: GuiObject
local Cards: Frame
local Listings: ScrollingFrame
local containerGoalPosition: UDim2
local containerOffscreenPosition: UDim2
local activeTween: Tween?

-- // Rows on the right, keyed by "AbilityUses/<id>" or "PickupsAcquired/<id>"
local listingRows: { [string]: Frame } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted, count
	repeat
		formatted, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = formatted
	until count == 0
	return text
end

local function formatTimePlayed(seconds: number): string
	if seconds < SECONDS_IN_HOUR then
		return `{math.floor(seconds / SECONDS_IN_MINUTE)} Min`
	end
	local hours = math.floor(seconds / SECONDS_IN_HOUR)
	return `{formatNumber(hours)} {if hours == 1 then "Hour" else "Hours"}`
end

-- // "FireBoomerang" -> "Fire Boomerang"
local function toDisplayName(id: string): string
	return (id:gsub("(%l)(%u)", "%1 %2"))
end

-- // Ability ids and enabled pickup class ids, from their logic folders
local function getListedIds(): { { Field: string, Id: string, Offset: number } }
	local entries = {}
	for _, module in AbilityLogics:GetChildren() do
		if module:IsA("ModuleScript") then
			table.insert(entries, { Field = "AbilityUses", Id = module.Name, Offset = ABILITY_ORDER_OFFSET })
		end
	end
	for _, module in PickupLogics:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, logic = pcall(require, module)
			if ok and type(logic) == "table" and logic.Disabled then
				continue -- // Stub pickups can't be collected yet
			end
			table.insert(entries, { Field = "PickupsAcquired", Id = module.Name, Offset = PICKUP_ORDER_OFFSET })
		end
	end
	return entries
end

local function resizeListings()
	local rowHeight = math.floor(Listings.AbsoluteSize.X / LISTING_ASPECT_RATIO)
	for _, row in listingRows do
		row.Size = UDim2.new(1, 0, 0, rowHeight)
	end
end

local function buildListings()
	for _, entry in getListedIds() do
		local row = ListingTemplate:Clone()
		row.Name = `{entry.Field}_{entry.Id}`
		row.StatName.Text = toDisplayName(entry.Id)
		row:SetAttribute("Field", entry.Field)
		row:SetAttribute("Id", entry.Id)
		row:SetAttribute("OrderOffset", entry.Offset)
		row.Parent = Listings
		listingRows[`{entry.Field}/{entry.Id}`] = row
	end
	resizeListings()
end

local function updateStats()
	local data = PlayerDataController.get()
	if not data then
		return
	end

	for cardName, field in CARD_FIELDS do
		local card = Cards:FindFirstChild(cardName)
		local value = data[field] or 0
		if card then
			card.Value.Text = if field == "TimePlayed" then formatTimePlayed(value) else formatNumber(value)
		end
	end

	-- // Each group (abilities, then pickups) is sorted by count, most used first
	local sorted = {}
	for _, row in listingRows do
		local counts = data[row:GetAttribute("Field")] or {}
		local count = counts[row:GetAttribute("Id")] or 0
		row.Count.Text = formatNumber(count)
		table.insert(sorted, { Row = row, Count = count })
	end
	table.sort(sorted, function(a, b)
		local offsetA, offsetB = a.Row:GetAttribute("OrderOffset"), b.Row:GetAttribute("OrderOffset")
		if offsetA ~= offsetB then
			return offsetA < offsetB
		end
		if a.Count ~= b.Count then
			return a.Count > b.Count
		end
		return a.Row.Name < b.Row.Name
	end)
	for index, entry in sorted do
		entry.Row.LayoutOrder = index
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

function StatsGui.open()
	StatsGui.Open = true
	StatsScreenGui.Enabled = true
	updateStats()
	resizeListings()
	Container.Position = containerOffscreenPosition
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
	UIController.supercede("Stats", "GamemodeHud")
end

function StatsGui.close()
	StatsGui.Open = false
	playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
	UIController.unSupercede("Stats", "GamemodeHud")

	task.delay(CONTAINER_TWEEN_INFO_OUT.Time, function()
		if not StatsGui.Open then
			StatsScreenGui.Enabled = false
		end
	end)
end

function StatsGui.toggle()
	if StatsGui.Open then
		StatsGui.close()
	else
		StatsGui.open()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	StatsScreenGui.Enabled = false
	StatsScreenGui.Parent = player:WaitForChild("PlayerGui")

	Container = StatsScreenGui:WaitForChild("Container")
	local content = Container:WaitForChild("Content")
	Cards = content:WaitForChild("Cards")
	Listings = content:WaitForChild("Listings")

	containerGoalPosition = Container.Position
	containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)

	Container:WaitForChild("Exit").MouseButton1Click:Connect(StatsGui.close)
	Listings:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeListings)
end

function StatsGui.start()
	buildListings()

	-- // Keep the numbers current while the menu is open (e.g. time played is saved every minute)
	PlayerDataController.UpdatedTasks:Add(function()
		if StatsGui.Open then
			updateStats()
		end
	end)
end

_init()

return StatsGui
