--[[
	Inventory

	Description:
	The Inventory menu, opened from the Inventory tile in the left lobby menu (MenuButtons). The Index tile opens the
	same menu as the Index (toggleIndex): every item on sale, owned or not; unowned ones are grey and can be looked at.
	The tab column (TABS) picks what the listing grid shows. A tab's content comes from the module with the same name
	in Tabs/ (shape: InventoryTab below); a tab without a module is shown but inert.
	Clicking an owned item's listing selects it and shows it in the Detail panel, which shows "Equipped" or an Equip
	button. The equipped item is selected when the menu opens; its card is the green "equipped" card with a check badge.
	Looks: the client's art and layout (ClientArt/Assets.InventoryScreen), applied over the .rbxmx files when the menu
	loads (applyClientArt). Models are shown with ItemViewport. Built from Inventory.rbxmx, InventoryListingTemplate.rbxmx and
	InventoryTabTemplate.rbxmx (their old images and the tab ICON labels are replaced or hidden).
]]

local InventoryGui = {}
InventoryGui.Type = "HUD"
InventoryGui.Open = false
InventoryGui.RequiresMouse = true -- // Frees the mouse in a locked camera (MouseUnlockController)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local ItemViewport = require(ReplicatedStorage.Client.UI.ItemViewport)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).InventoryScreen

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type InventoryItem = {
	Id: string,
	Name: string,
	Rarity: string?, -- // Shown under the name in the Detail panel
	ModelName: string?, -- // Model in Shared/Assets/Tools shown in the viewports (posed by its Tools entry)
	IconImage: number?, -- // Instead of a model (charge up effects): GUI image asset id
	IconGlyph: string?, -- // Instead of a model (charge up effects): placeholder label while there is no image
	EmoteAnimationId: string?, -- // Instead of a model (emotes): animation asset id played by the EmotesRig
	Owned: boolean,
	Equipped: boolean,
}

export type InventoryTab = {
	Title: string, -- // Title on the plank while the tab is open
	getItems: (includeUnowned: boolean?) -> { InventoryItem }, -- // In display order. includeUnowned (Index): also every item on sale the player doesn't own (Owned = false)
	equipItem: (itemId: string) -> (), -- // Equip button clicked for an owned item (may yield)
	subscribe: (onChanged: () -> ()) -> (), -- // Called once; onChanged runs when the items change
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // The tab column, top to bottom. A tab's content is Tabs/<Id>; tabs without a module are inert.
-- // Image: the tab's art (ClientArt); its label is drawn over the art's empty lower part
local TABS = {
	{ Id = "Skins", Text = "Weapons", Image = Art.TabWeapons },
	{ Id = "Emotes", Text = "Emotes", Image = Art.TabEmotes },
	{ Id = "Arrows", Text = "Charges", Image = Art.TabCharges }, -- // Charge up effects (module id is "Arrows")
	{ Id = "Strikes", Text = "Strikes", Image = Art.TabStrikes }, -- // Elimination cosmetics
	{ Id = "Taunts", Text = "Taunts", Image = Art.TabTaunts }, -- // Taunts (played after a round)
}
local DEFAULT_TAB = "Skins"
local TAB_DIM = Color3.fromRGB(150, 150, 150) -- // Tint on tabs that aren't open

-- // Listing card art by state; unowned items (Index) use the normal card, dimmed
local LOCKED_TINT = Color3.fromRGB(120, 110, 105)
local LOCKED_TEXT_TRANSPARENCY = 0.35

-- // The client's layout, as fractions of the window art (its mockup canvas is 1714 x 1140): {x, y, w, h}
local CANVAS = Vector2.new(1714, 1140)
local LAYOUT = {
	Close = { 1478, 80, 124, 120 },
	Title = { 640, 60, 570, 104 }, -- // Over the ribbon, right of the star
	Tabs = { 103, 207, 182, 754 }, -- // The tab column (5 tabs)
	Listings = { 318, 253, 735, 732 }, -- // Card grid
	Detail = { 1068, 254, 466, 712 }, -- // Right-hand panel
}
local TAB_HEIGHT, TAB_GAP = 0.188, 0.015 -- // Fractions of the tab column (5 tabs + 4 gaps = 1)
local CARD = Vector2.new(233, 324) -- // Card art size; the grid has 3 columns
local CARD_GAP = Vector2.new(12, 14)
local CARD_ART = { 22, 42, 190, 200 } -- // Item preview inside a card
local CARD_NAME = { 10, 244, 213, 52 }
local CARD_CHECK = { 160, -4, 74, 74 } -- // Equipped badge over the card's top-right corner
-- // Inside the Detail panel (canvas pixels, minus the panel's position)
local DETAIL_NAME = { 24, 18, 422, 72 }
local DETAIL_RARITY = { 24, 88, 422, 54 }
local DETAIL_PREVIEW = { 62, 161, 325, 385 }
local DETAIL_BUTTON = { 37, 541, 395, 135 } -- // Equip / Equipped
local TEXT_COLOR = Color3.fromRGB(252, 243, 224)
local TEXT_OUTLINE = Color3.fromRGB(70, 44, 28)

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
local listings: { [string]: GuiObject } = {}
local currentItems: { InventoryItem } = {}
local selectedItemId: string? = nil
local detailItemId: string? = nil -- // Item whose model the Detail viewport shows
local equipRequestPending = false
local indexMode = false -- // Index (the Index tile): every item, owned or not; unowned ones can be looked at but not equipped

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Cream lettering with a dark brown outline, like the client's art
local function styleText(label: TextLabel)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = TEXT_COLOR
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = TEXT_OUTLINE
	end
end

-- // Places a GUI object at a rect given in pixels of `space` ({w, h} of its parent's art). Centre-anchored, so hover
-- // scaling grows it in place
local function place(object: GuiObject, rect: { number }, space: Vector2)
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = UDim2.fromScale((rect[1] + rect[3] / 2) / space.X, (rect[2] + rect[4] / 2) / space.Y)
	object.Size = UDim2.fromScale(rect[3] / space.X, rect[4] / space.Y)
end

-- // Restyles the window and templates (built for the old art) with the client's art and layout
local function applyClientArt(content: Frame)
	Container.Image = Art.Window
	local aspect = Container:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect.AspectRatio = CANVAS.X / CANVAS.Y
	end

	local exit = Container:WaitForChild("Exit") :: ImageButton
	exit.Image = Art.Close
	place(exit, LAYOUT.Close, CANVAS)
	place(TitleLabel, LAYOUT.Title, CANVAS)
	styleText(TitleLabel)

	place(TabsFrame, LAYOUT.Tabs, CANVAS)
	local tabLayout = TabsFrame:FindFirstChildOfClass("UIListLayout")
	if tabLayout then
		tabLayout.Padding = UDim.new(TAB_GAP, 0)
	end

	-- // The listings and the detail panel are placed on the whole window
	content.Position = UDim2.fromScale(0, 0)
	content.Size = UDim2.fromScale(1, 1)
	place(ListingsFrame, LAYOUT.Listings, CANVAS)
	local grid = ListingsFrame:FindFirstChildOfClass("UIGridLayout")
	if grid then
		local width, height = LAYOUT.Listings[3], LAYOUT.Listings[4]
		grid.CellSize = UDim2.fromScale(CARD.X / width, CARD.Y / height)
		grid.CellPadding = UDim2.fromScale(CARD_GAP.X / width, CARD_GAP.Y / height)
		local cellAspect = grid:FindFirstChildOfClass("UIAspectRatioConstraint")
		if cellAspect then
			cellAspect.AspectRatio = CARD.X / CARD.Y
		end
	end

	local detailSize = Vector2.new(LAYOUT.Detail[3], LAYOUT.Detail[4])
	place(DetailPanel, LAYOUT.Detail, CANVAS)
	DetailPanel.Art.Visible = false -- // The window art has the panel painted in
	place(DetailPanel.ItemName, DETAIL_NAME, detailSize)
	place(DetailPanel.Rarity, DETAIL_RARITY, detailSize)
	place(DetailPanel.Viewport, DETAIL_PREVIEW, detailSize)
	styleText(DetailPanel.ItemName)
	styleText(DetailPanel.Rarity)
	local equip = DetailPanel.Equip :: ImageButton
	equip.Image = Art.Equip
	place(equip, DETAIL_BUTTON, detailSize)
	local equipAspect = equip:FindFirstChildOfClass("UIAspectRatioConstraint")
	if equipAspect then
		equipAspect.AspectRatio = DETAIL_BUTTON[3] / DETAIL_BUTTON[4]
	end
	styleText(equip.Label)
	-- // "Equipped": the grey button art behind the status text
	local status = DetailPanel.Status :: TextLabel
	place(status, DETAIL_BUTTON, detailSize)
	styleText(status)
	local statusArt = Instance.new("ImageLabel")
	statusArt.Name = "StatusArt"
	statusArt.BackgroundTransparency = 1
	statusArt.Image = Art.Equipped
	statusArt.Size = UDim2.fromScale(1, 1)
	statusArt.ZIndex = status.ZIndex - 1
	statusArt.Parent = status

	-- // Listing cards: the card art fills the cell; preview, name and the equipped badge on top
	local cardArt = ListingTemplate.Art :: ImageLabel
	cardArt.Image = Art.CardNormal
	cardArt.Position = UDim2.fromScale(0, 0)
	cardArt.Size = UDim2.fromScale(1, 1)
	place(ListingTemplate.Viewport, CARD_ART, CARD)
	place(ListingTemplate.ItemName, CARD_NAME, CARD)
	styleText(ListingTemplate.ItemName)
	local check = Instance.new("ImageLabel")
	check.Name = "Check"
	check.BackgroundTransparency = 1
	check.Image = Art.Check
	check.Visible = false
	check.ZIndex = cardArt.ZIndex + 5
	place(check, CARD_CHECK, CARD)
	check.Parent = ListingTemplate
end

-- // Grows the button while hovered (through its UIScale, so it works inside layouts)
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

local function findItem(itemId: string?): InventoryItem?
	for _, item in currentItems do
		if item.Id == itemId then
			return item
		end
	end
	return nil
end

local function getEquippedItem(): InventoryItem?
	for _, item in currentItems do
		if item.Equipped then
			return item
		end
	end
	return nil
end

-- // Shows an item as a model render, an image / placeholder label (charge up effects), or the EmotesRig playing the
-- // emote (emotes)
local function showItem(viewport: ViewportFrame, item: InventoryItem?)
	if item and item.ModelName then
		ItemViewport.setImagePlaceholder(viewport) -- // Removes a leftover placeholder from the previous item
		ItemViewport.renderTool(viewport, item.ModelName)
	elseif item and item.IconGlyph then
		ItemViewport.setImagePlaceholder(viewport, item.IconImage, item.IconGlyph)
	elseif item and item.EmoteAnimationId then
		ItemViewport.setImagePlaceholder(viewport)
		ItemViewport.renderEmote(viewport, item.EmoteAnimationId)
	else
		ItemViewport.setImagePlaceholder(viewport)
		ItemViewport.clear(viewport)
	end
end

local function updateDetail()
	local item = findItem(selectedItemId)
	DetailPanel.ItemName.Text = if item then item.Name else ""
	DetailPanel.Rarity.Text = if item then item.Rarity or "" else ""
	DetailPanel.Status.Visible = item ~= nil and item.Equipped
	DetailPanel.Equip.Visible = item ~= nil and item.Owned and not item.Equipped

	local itemId = item and item.Id
	if itemId ~= detailItemId then
		detailItemId = itemId
		showItem(DetailPanel.Viewport, item)
	end
end

-- // Listing colors and the Detail panel, from the current items and selection
local function updateSelection()
	if not findItem(selectedItemId) then
		local equippedItem = getEquippedItem()
		selectedItemId = equippedItem and equippedItem.Id
	end

	for _, item in currentItems do
		local listing = listings[item.Id]
		local art = listing.Art :: ImageLabel
		art.Image = if item.Equipped
			then Art.CardEquipped
			elseif item.Id == selectedItemId then Art.CardSelected
			else Art.CardNormal
		art.ImageColor3 = if item.Owned or item.Id == selectedItemId then Color3.new(1, 1, 1) else LOCKED_TINT
		listing.Check.Visible = item.Equipped
	end

	updateDetail()
end

local function onListingClicked(itemId: string)
	selectedItemId = itemId
	updateSelection()
end

local function onEquipClicked()
	local tab = currentTabId and tabModules[currentTabId]
	local item = findItem(selectedItemId)
	if equipRequestPending or not tab or not item or not item.Owned or item.Equipped then
		return
	end

	equipRequestPending = true
	tab.equipItem(item.Id)
	equipRequestPending = false
end

-- // Rebuilds the listing grid from the open tab's items (keeps the selection if it still exists)
local function refreshListings()
	for _, listing in listings do
		listing:Destroy()
	end
	table.clear(listings)

	local tab = currentTabId and tabModules[currentTabId]
	currentItems = if tab then tab.getItems(indexMode) else {}
	detailItemId = nil -- // Forces a Detail model redraw; the item data may have changed

	for order, item in currentItems do
		local listing = ListingTemplate:Clone()
		listing.Name = item.Id
		listing.LayoutOrder = order
		listing.ItemName.Text = item.Name
		showItem(listing.Viewport, item)

		if item.Owned or indexMode then
			listing.MouseButton1Click:Connect(function()
				onListingClicked(item.Id)
			end)
			setupButtonHover(listing)
		end
		if not item.Owned then
			listing.ItemName.TextTransparency = LOCKED_TEXT_TRANSPARENCY
		end

		listing.Parent = ListingsFrame
		listings[item.Id] = listing
	end

	updateSelection()
end

local function updateTabColors()
	for _, tabInfo in TABS do
		local button = tabButtons[tabInfo.Id]
		button.ImageColor3 = if tabInfo.Id == currentTabId then Color3.new(1, 1, 1) else TAB_DIM
	end
end

local function selectTab(tabId: string)
	local tab = tabModules[tabId]
	if not tab or currentTabId == tabId then
		return
	end

	currentTabId = tabId
	selectedItemId = nil -- // Starts on the tab's equipped item
	TitleLabel.Text = if indexMode then "Index" else tab.Title
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
		-- // The art has its icon painted in: the template's ICON label isn't used
		button.Image = tabInfo.Image
		button.ScaleType = Enum.ScaleType.Fit
		button.Size = UDim2.fromScale(1, TAB_HEIGHT)
		button.ICON.Visible = false
		styleText(button.Label)
		button.Parent = TabsFrame
		tabButtons[tabInfo.Id] = button

		local moduleScript = TabModules:FindFirstChild(tabInfo.Id)
		if not moduleScript then
			continue -- // Tab has no module
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

-- // Switches between the Inventory (owned items) and the Index (every item), keeping the open tab
local function setIndexMode(value: boolean)
	indexMode = value
	local tab = currentTabId and tabModules[currentTabId]
	if tab then
		TitleLabel.Text = if indexMode then "Index" else tab.Title
	end
	selectedItemId = nil -- // Starts on the equipped item
	refreshListings()
end

-- // Opens the Inventory showing the player's items
function InventoryGui.open()
	InventoryGui.Open = true
	InventoryScreenGui.Enabled = true
	setIndexMode(false)
	Container.Position = containerOffscreenPosition
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
	UIController.supercede("Inventory", "GamemodeHud")
	UIController.closeOtherMenus("Inventory") -- // After superceding, so the closing menu doesn't restore the HUD
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
	if InventoryGui.Open and indexMode then
		setIndexMode(false) -- // The Index is open: show the Inventory instead
	elseif InventoryGui.Open then
		InventoryGui.close()
	else
		InventoryGui.open()
	end
end

-- // The Index (the Index tile in the lobby menu): the same menu showing every item, owned or not
function InventoryGui.toggleIndex()
	if InventoryGui.Open and not indexMode then
		setIndexMode(true) -- // The Inventory is open: show the Index instead
	elseif InventoryGui.Open then
		InventoryGui.close()
	else
		InventoryGui.open()
		setIndexMode(true)
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
	applyClientArt(content)

	containerGoalPosition = Container.Position
	containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)

	local exitButton = Container:WaitForChild("Exit")
	setupButtonHover(exitButton)
	exitButton.MouseButton1Click:Connect(InventoryGui.close)

	local equipButton = DetailPanel:WaitForChild("Equip")
	setupButtonHover(equipButton)
	equipButton.MouseButton1Click:Connect(onEquipClicked)
end

function InventoryGui.start()
	buildTabs()
end

_init()

return InventoryGui
