--[[
	Inventory (T-075; was the Skins menu from T-072)

	Description:
	The Inventory menu, opened from the Skins button in the left lobby menu (MenuButtons).
	The tab column on the left (TABS) picks what the listing grid shows. A tab's content comes from the module
	with the same name in Tabs/ (shape: InventoryTab below); a tab without a module is shown but does nothing yet.
	Each listing is a button: clicking an owned item selects it (tabs may list only owned items, like Skins) (e.g. equips the skin). The equipped item's listing
	is green and the item is shown in the Detail panel on the right.
	Built from Inventory.rbxmx, InventoryListingTemplate.rbxmx and InventoryTabTemplate.rbxmx.
	The ICON image labels are empty placeholders until icon art exists.
]]

local InventoryGui = {}
InventoryGui.Type = "HUD"
InventoryGui.Open = false
InventoryGui.RequiresMouse = true -- // Clickable menu: frees the mouse in the locked camera (MouseUnlockController)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type InventoryItem = {
	Id: string,
	Name: string,
	Rarity: string?, -- // Shown under the name in the Detail panel
	Icon: string?, -- // Image for the ICON labels (nil = empty placeholder)
	Owned: boolean,
	Equipped: boolean,
}

export type InventoryTab = {
	Title: string, -- // Title on the plank while the tab is open
	getItems: () -> { InventoryItem }, -- // In display order
	selectItem: (itemId: string) -> (), -- // An owned listing was clicked (may yield)
	subscribe: (onChanged: () -> ()) -> (), -- // Called once; onChanged runs whenever the items change
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // The tab column, top to bottom. A tab's content is Tabs/<Id>; tabs without a module aren't set up yet.
local TABS = {
	{ Id = "Skins", Text = "Skins", Color = Color3.fromRGB(165, 95, 200) },
	{ Id = "Emotes", Text = "Emotes", Color = Color3.fromRGB(55, 170, 180) },
	{ Id = "Arrows", Text = "Arrows", Color = Color3.fromRGB(240, 165, 50) },
	{ Id = "Effects", Text = "Effects", Color = Color3.fromRGB(215, 70, 70) },
}
local DEFAULT_TAB = "Skins"
local INACTIVE_TAB_DARKEN = 0.25 -- // How much darker the tabs that aren't open are

-- // Listing colors (the listing frame art, listing.Art, is grayscale and tinted with ImageColor3)
local COLOR_OWNED = Color3.fromRGB(225, 170, 110)
local COLOR_EQUIPPED = Color3.fromRGB(130, 215, 80)
local COLOR_LOCKED = Color3.fromRGB(140, 140, 140)
local LOCKED_TEXT_TRANSPARENCY = 0.35

local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local HOVER_SCALE = 1.06
local HOVER_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local TabModules = script:WaitForChild("Tabs")

local InventoryScreenGui: ScreenGui = script:WaitForChild("Inventory")
local ListingTemplate = script:WaitForChild("InventoryListingTemplate")
local TabTemplate = script:WaitForChild("InventoryTabTemplate")
local Container: ImageLabel
local TitleLabel: TextLabel
local TabsFrame: Frame
local ListingsFrame: ScrollingFrame
local DetailPanel: ImageLabel
local containerGoalPosition: UDim2
local containerOffscreenPosition: UDim2
local activeTween: Tween?

local tabModules: { [string]: InventoryTab } = {}
local tabButtons: { [string]: ImageButton } = {}
local currentTabId: string? = nil
local listings: { GuiObject } = {}
local selectRequestPending = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Grows the button a little while hovered (through its UIScale, so it works inside layouts)
local function setupButtonHover(button: GuiButton)
	local uiScale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Parent = button
	local hoverTween: Tween?

	local function tweenTo(scale: number)
		if hoverTween then
			hoverTween:Cancel()
		end
		hoverTween = TweenService:Create(uiScale, HOVER_TWEEN_INFO, { Scale = scale })
		hoverTween:Play()
	end

	button.MouseEnter:Connect(function()
		tweenTo(HOVER_SCALE)
	end)
	button.MouseLeave:Connect(function()
		tweenTo(1)
	end)
end

local function setIcon(iconLabel: ImageLabel, icon: string?)
	iconLabel.Image = icon or ""
end

local function updateDetail(item: InventoryItem?)
	DetailPanel.ItemName.Text = if item then item.Name else ""
	DetailPanel.Rarity.Text = if item then item.Rarity or "" else ""
	DetailPanel.Status.Visible = item ~= nil
	setIcon(DetailPanel.ICON, if item then item.Icon else nil)
end

local function onListingClicked(itemId: string)
	local tab = currentTabId and tabModules[currentTabId]
	if selectRequestPending or not tab then
		return
	end

	selectRequestPending = true
	tab.selectItem(itemId)
	selectRequestPending = false
end

-- // Rebuilds the listing grid and the Detail panel from the open tab's items
local function refreshListings()
	for _, listing in listings do
		listing:Destroy()
	end
	table.clear(listings)

	local tab = currentTabId and tabModules[currentTabId]
	if not tab then
		updateDetail(nil)
		return
	end

	local equippedItem: InventoryItem? = nil
	for order, item in tab.getItems() do
		local listing = ListingTemplate:Clone()
		listing.Name = item.Id
		listing.LayoutOrder = order
		listing.ItemName.Text = item.Name
		setIcon(listing.ICON, item.Icon)

		if item.Equipped then
			listing.Art.ImageColor3 = COLOR_EQUIPPED
			equippedItem = item
		elseif item.Owned then
			listing.Art.ImageColor3 = COLOR_OWNED
		else
			listing.Art.ImageColor3 = COLOR_LOCKED
			listing.ItemName.TextTransparency = LOCKED_TEXT_TRANSPARENCY
			listing.AutoButtonColor = false
		end

		if item.Owned then
			listing.MouseButton1Click:Connect(function()
				onListingClicked(item.Id)
			end)
			setupButtonHover(listing)
		end

		listing.Parent = ListingsFrame
		table.insert(listings, listing)
	end

	updateDetail(equippedItem)
end

local function updateTabColors()
	for _, tabInfo in TABS do
		local button = tabButtons[tabInfo.Id]
		button.ImageColor3 = if tabInfo.Id == currentTabId
			then tabInfo.Color
			else tabInfo.Color:Lerp(Color3.new(0, 0, 0), INACTIVE_TAB_DARKEN)
	end
end

local function selectTab(tabId: string)
	local tab = tabModules[tabId]
	if not tab or currentTabId == tabId then
		return
	end

	currentTabId = tabId
	TitleLabel.Text = tab.Title
	ListingsFrame.CanvasPosition = Vector2.zero
	updateTabColors()
	refreshListings()
end

local function buildTabs()
	for order, tabInfo in TABS do
		local button = TabTemplate:Clone()
		button.Name = tabInfo.Id
		button.LayoutOrder = order
		button.Label.Text = tabInfo.Text
		button.Parent = TabsFrame
		tabButtons[tabInfo.Id] = button

		local moduleScript = TabModules:FindFirstChild(tabInfo.Id)
		if not moduleScript then
			continue -- // TODO: tab not set up yet
		end

		local tab = require(moduleScript) :: InventoryTab
		tabModules[tabInfo.Id] = tab
		tab.subscribe(function()
			if currentTabId == tabInfo.Id then
				refreshListings()
			end
		end)

		setupButtonHover(button)
		button.MouseButton1Click:Connect(function()
			selectTab(tabInfo.Id)
		end)
	end

	selectTab(DEFAULT_TAB)
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

function InventoryGui.open()
	InventoryGui.Open = true
	InventoryScreenGui.Enabled = true
	refreshListings()
	Container.Position = containerOffscreenPosition
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
	UIController.supercede("Inventory", "GamemodeHud")
end

function InventoryGui.close()
	InventoryGui.Open = false
	playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
	UIController.unSupercede("Inventory", "GamemodeHud")

	task.delay(0.4, function()
		if not InventoryGui.Open then
			InventoryScreenGui.Enabled = false
		end
	end)
end

function InventoryGui.toggle()
	if InventoryGui.Open then
		InventoryGui.close()
	else
		InventoryGui.open()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	InventoryScreenGui.Enabled = false
	InventoryScreenGui.Parent = player:WaitForChild("PlayerGui")

	Container = InventoryScreenGui:WaitForChild("Container")
	TitleLabel = Container:WaitForChild("Title")
	TabsFrame = Container:WaitForChild("Tabs")
	local content = Container:WaitForChild("Content")
	ListingsFrame = content:WaitForChild("Listings")
	DetailPanel = content:WaitForChild("Detail")

	containerGoalPosition = Container.Position
	containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)

	local exitButton = Container:WaitForChild("Exit")
	setupButtonHover(exitButton)
	exitButton.MouseButton1Click:Connect(InventoryGui.close)
end

function InventoryGui.start()
	buildTabs()
end

_init()

return InventoryGui
