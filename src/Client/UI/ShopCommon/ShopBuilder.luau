--[[
	ShopBuilder

	Description:
	Builds a shop menu: ShopBuilder.create(config) returns a Gui module for UIController. Used by the Weapons Shop and
	Cosmetics Shop (Client/UI/Gui), which differ only in config: name, title, tabs and grid columns.
	The tab row picks what the listing grid shows (config.Tabs, in order). A tab's content is its Tab module (shape:
	ShopTab below); a tab without one is selectable but opens blank.
	Listing data comes from ShopListings; the rarity name is colored with RarityStyles. Models are shown with ItemViewport.
	The pill right of the tabs shows the player's Currency (EconomyController).
	Looks: the same blank art as the Quests menu (ClientArt/Assets.QuestsScreen: window, tabs, cards, buttons), with every
	text and icon drawn as instances (ClientArt/Kit). The window is laid out in the frame image's own pixels (CANVAS) and
	fitted to the screen by Kit.window. Gifting isn't built: there is no Gift button (Sol, 2026-11-12).
]]

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local ItemViewport = require(ReplicatedStorage.Client.UI.ItemViewport)
local ShopController = require(ReplicatedStorage.Client.Core.ShopController)
local EconomyController = require(ReplicatedStorage.Client.Core.EconomyController)
local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local MarketplaceLibrary = require(ReplicatedStorage.Shared.Library.MarketplaceLibrary)
local PolicyLibrary = require(ReplicatedStorage.Shared.Library.PolicyLibrary)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).QuestsScreen
local ShopListings = require(script.Parent.ShopListings)
local RarityStyles = require(script.Parent.RarityStyles)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ShopTab = {
	Scrollable: boolean, -- // Whether the grid scrolls past one screen of listings (false: only the first MaxListings are shown)
	MaxListings: number?, -- // Cap on the listings shown
	getListings: () -> { ShopItems.ShopListing }, -- // In display order
	subscribe: (onChanged: () -> ()) -> (), -- // Called once; onChanged runs when the listings or their ownership change
}

export type ShopTabDefinition = {
	Id: string,
	Name: string,
	IconImage: string?, -- // Image shown left of the name (e.g. a ClientArt icon); none: the name fills the tab
	AutoSelect: boolean?, -- // Whether this tab is selected when the gui opens
	Tab: ShopTab?, -- // Its content; nil opens blank
}

export type ShopLayout = {
	HideTabs: boolean?, -- // No tab row (single-tab shop); the first / AutoSelect tab is shown
	GridColumns: number?, -- // Cards per row (default 4); fewer columns make bigger cards
}

export type ShopConfig = {
	Name: string, -- // Gui name (UIController id), e.g. "WeaponsShop"
	Title: string, -- // Shown on the ribbon
	Tabs: { ShopTabDefinition }, -- // In display order (up to 4)
	TestKey: Enum.KeyCode?, -- // Studio-only shortcut that toggles the shop
	Layout: ShopLayout?,
}

type Listing = {
	Frame: Frame,
	Display: ShopListings.ListingDisplay,
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Window layout in the Quests frame art's pixels ({x, y, w, h}), as in the Quests menu
local CANVAS = Vector2.new(1011, 568)
local TITLE = { 395, 16, 245, 54 } -- // Over the blank ribbon, right of the emblem
local CLOSE = { 871, 32, 64, 63 }
local CLOSE_ICON_INSET = 0.22
local TABS_ORIGIN = Vector2.new(106, 103) -- // Top-left of the first tab
local TAB_SIZE = Vector2.new(150, 52)
local TAB_GAP = 6
local TAB_ICON = { 10, 8, 36, 36 } -- // Inside a tab
local TAB_TEXT = { 48, 6, 96, 42 }
local TAB_TEXT_NO_ICON = { 8, 6, 134, 42 }
local BALANCE_PILL = { 732, 112, 162, 38 }
local BALANCE_ICON = { 714, 106, 48, 48 }
local BALANCE_TEXT = { 766, 114, 120, 34 }
local LISTINGS = { 108, 166, 796, 322 } -- // The card grid (scrolls vertically)
local CARD_GAP = 10
local SCROLLBAR = 8
local DEFAULT_GRID_COLUMNS = 4

-- // A card is drawn at the quest card's size (CARD) and scaled to its grid cell; rects are in those pixels
local CARD = Vector2.new(252, 307)
local CARD_NAME = { 10, 8, 232, 36 } -- // Top of the blue picture area
local CARD_VIEWPORT = { 30, 42, 192, 106 }
local CARD_RARITY = { 14, 158, 224, 32 } -- // Top of the cream panel
local BUTTON_SINGLE = { 18, 214, 216, 56 } -- // One price button, centred in the cream panel
local BUTTON_TOP = { 18, 192, 216, 50 } -- // Currency, when there is also a Robux price
local BUTTON_BOTTOM = { 18, 246, 216, 50 } -- // Robux
local BUTTON_ICON = { 14, 9, 32, 32 } -- // Coin / Robux icon inside a 216 x 50 button (scaled with it)
local BUTTON_TEXT_ICON = { 50, 6, 152, 38 }
local BUTTON_TEXT_PLAIN = { 14, 6, 188, 38 }

local TEXT_SIZE = { Title = 40, Tab = 22, Balance = 20, Name = 22, Rarity = 20, Button = 26 }
local ROBUX_TINT = Color3.fromRGB(110, 190, 255) -- // Tints the grey button art blue
local OWNED_TEXT = "Owned"
local FREE_TEXT = "Free"

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

-- // Cream lettering with a dark outline (Kit.label), shrunk to fit its box
local function outlined(name: string, text: string, size: number, r: { number }, parent: Instance, zIndex: number?): Frame
	-- // The container takes the same ZIndex: with sibling layering it would otherwise draw under what it sits on
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

local function setTextColor(label: Frame, color: Color3)
	local front = label:FindFirstChild("Text") :: TextLabel?
	if front then
		front.TextColor3 = color
	end
end

-- // 1500 -> "1,500"
local function formatAmount(amount: number): string
	local text = tostring(math.floor(amount))
	local reversed = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (reversed:gsub("^,", ""))
end

-- // A price button: blank button art, an optional coin / Robux icon, and its text. Returns the button and its label.
local function createPriceButton(name: string, r: { number }, parent: Instance): (ImageButton, Frame)
	local button = Kit.create("ImageButton", {
		Name = name,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = Art.ButtonGreen,
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(r[1] + r[3] / 2, r[2] + r[4] / 2),
		Size = UDim2.fromOffset(r[3], r[4]),
		ZIndex = 3,
		Parent = parent,
	})
	-- // Contents are laid out for a 216 x 50 button and scaled to this one
	local inner = Kit.create("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(216, 50),
		ZIndex = 3,
		Parent = button,
	}, {
		Kit.create("UIScale", { Scale = r[4] / 50 }),
	})
	image("Icon", "", BUTTON_ICON, inner, 4)
	local label = outlined("Label", "", TEXT_SIZE.Button, BUTTON_TEXT_ICON, inner, 4)
	Kit.pressable(button)
	return button, label
end

local function setPriceButton(button: ImageButton, label: Frame, text: string, iconImage: string?)
	local icon = button.Inner.Icon :: ImageLabel
	icon.Image = iconImage or ""
	icon.Visible = iconImage ~= nil
	label.Position, label.Size = rect(if iconImage then BUTTON_TEXT_ICON else BUTTON_TEXT_PLAIN)
	Kit.setText(label, text)
end

local function placeButton(button: ImageButton, r: { number })
	button.Position = UDim2.fromOffset(r[1] + r[3] / 2, r[2] + r[4] / 2)
	button.Size = UDim2.fromOffset(r[3], r[4])
	local scale = button.Inner:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = r[4] / 50
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

local ShopBuilder = {}

function ShopBuilder.create(config: ShopConfig)
	local ShopGui = {}
	ShopGui.Type = "HUD"
	ShopGui.Open = false
	ShopGui.RequiresMouse = true -- // Frees the mouse in a locked camera (MouseUnlockController)

	-------------------------------------------------------------------------------
	-- PRIVATE VARIABLES
	-------------------------------------------------------------------------------

	local player = Players.LocalPlayer
	local layout: ShopLayout = config.Layout or {}
	local columns = layout.GridColumns or DEFAULT_GRID_COLUMNS
	local crateAssetsFolder = ReplicatedStorage.Shared:WaitForChild("Assets"):FindFirstChild("Crates")
	local purchaseInFlight: { [string]: boolean } = {} -- // One purchase at a time per crate (prevents double charges)

	-- // Card size in the grid: the columns fill the grid's width (minus the scroll bar), keeping the card's shape
	local cellWidth = math.floor((LISTINGS[3] - SCROLLBAR - CARD_GAP * columns) / columns)
	local cellScale = cellWidth / CARD.X
	local cellHeight = math.floor(CARD.Y * cellScale)

	local window: Kit.Window
	local listingsFrame: ScrollingFrame
	local balanceText: Frame

	local tabModules: { [string]: ShopTab } = {}
	local tabDefinitions: { [string]: ShopTabDefinition } = {}
	local tabButtons: { [string]: ImageButton } = {}
	local tabOrder: { string } = {}
	local currentTabId: string? = nil
	local listings: { Listing } = {}
	local refreshId = 0 -- // Bumped on every refresh so stale async work (policy, Robux prices) can detect it

	-------------------------------------------------------------------------------
	-- PRIVATE FUNCTIONS
	-------------------------------------------------------------------------------

	local function updateBalance(balance: number?)
		Kit.setText(balanceText, formatAmount(balance or EconomyController.getBalance()))
	end

	local function showPreview(viewport: ViewportFrame, display: ShopListings.ListingDisplay)
		if display.ModelName then
			ItemViewport.renderTool(viewport, display.ModelName)
		elseif display.IconGlyph then
			-- // IMAGE PLACEHOLDER (charge up effects): a label until the item has a GUI image (ChargeUpEffects.Icon)
			ItemViewport.setImagePlaceholder(viewport, display.IconImage, display.IconGlyph)
		elseif display.EmoteAnimationId then
			-- // Emotes: the EmotesRig playing the emote
			ItemViewport.renderEmote(viewport, display.EmoteAnimationId)
		elseif display.CrateModelName then
			-- // Crates: the crate model from Shared/Assets/Crates
			local crateModel = crateAssetsFolder and crateAssetsFolder:FindFirstChild(display.CrateModelName)
			if crateModel and crateModel:IsA("Model") then
				ItemViewport.renderModel(viewport, crateModel, display.CrateViewportRotation)
			else
				warn(`ShopBuilder: crate model {display.CrateModelName} not found in Shared.Assets.Crates`)
			end
		end
	end

	local function onCurrencyClicked(display: ShopListings.ListingDisplay)
		if display.Type == "Crate" then
			-- // One at a time; ShopController / SkinController show the result popup
			if purchaseInFlight[display.Id] then
				return
			end
			purchaseInFlight[display.Id] = true
			task.spawn(function()
				local bought = ShopController.requestPurchaseCrate(display.Id)
				purchaseInFlight[display.Id] = nil
				if bought and ShopGui.Open then
					ShopGui.close() -- // The crate waits next to the player to be clicked open
				end
			end)
			return
		end
		-- // The listing refreshes as Owned through the tab's subscribe once the purchase replicates
		ShopController.requestPurchaseItem(display.Id, display.Type)
	end

	-- // One grid cell: name and preview on the blue area, rarity and price buttons on the cream panel
	local function buildListing(display: ShopListings.ListingDisplay, order: number, thisRefreshId: number): Frame
		local style = RarityStyles.get(display.Rarity)
		local cell = Kit.create("Frame", {
			Name = display.Id,
			BackgroundTransparency = 1,
			LayoutOrder = order,
		})
		local card = image("Card", Art.Card, { 0, 0, CARD.X, CARD.Y }, cell, 2)
		card.ScaleType = Enum.ScaleType.Stretch
		Kit.create("UIScale", { Scale = cellScale, Parent = card })

		outlined("ItemName", display.Name, TEXT_SIZE.Name, CARD_NAME, card, 3)
		local viewport = Kit.create("ViewportFrame", {
			Name = "Viewport",
			BackgroundTransparency = 1,
			ZIndex = 3,
		})
		viewport.Position, viewport.Size = rect(CARD_VIEWPORT)
		viewport.Parent = card
		showPreview(viewport, display)

		local rarity = outlined("Rarity", display.Subtitle or display.Rarity, TEXT_SIZE.Rarity, CARD_RARITY, card, 3)
		if not display.Subtitle then
			setTextColor(rarity, style.TextColor) -- // RARITY: the rarity name takes its color
		end

		-- // Currency price (the main button); grey "Owned" once owned
		local showRobux = display.ProductId ~= nil and not display.Owned
		local currencyButton, currencyLabel =
			createPriceButton("Currency", if showRobux then BUTTON_TOP else BUTTON_SINGLE, card)
		if display.Owned then
			currencyButton.Image = Art.ButtonGrey
			Kit.setEnabled(currencyButton, false)
			setPriceButton(currencyButton, currencyLabel, OWNED_TEXT, nil)
		else
			local free = display.Price <= 0
			setPriceButton(
				currencyButton,
				currencyLabel,
				if free then FREE_TEXT else formatAmount(display.Price),
				if free then nil else `rbxassetid://{Icons.CurrencyIcon}`
			)
			currencyButton.Activated:Connect(function()
				onCurrencyClicked(display)
			end)
		end

		-- // Robux price, when the listing has a developer product: "..." until the price loads, hidden if it can't be bought
		if showRobux then
			local robuxButton, robuxLabel = createPriceButton("Robux", BUTTON_BOTTOM, card)
			robuxButton.Image = Art.ButtonGrey
			robuxButton.ImageColor3 = ROBUX_TINT
			setPriceButton(robuxButton, robuxLabel, "...", `rbxassetid://{Icons.RobuxIcon}`)
			robuxButton.Activated:Connect(function()
				ShopController.requestRobuxPurchaseItem(display.Id, display.Type)
			end)
			task.spawn(function()
				local productId = display.ProductId :: number
				local price = MarketplaceLibrary.getProductPrice(productId)
				if thisRefreshId ~= refreshId then
					return
				end
				if price and MarketplaceLibrary.playerCanPurchaseItem(player, productId) then
					Kit.setText(robuxLabel, formatAmount(price))
				else
					robuxButton:Destroy()
					placeButton(currencyButton, BUTTON_SINGLE)
				end
			end)
		end

		return cell
	end

	local function clearListings()
		for _, listing in listings do
			listing.Frame:Destroy()
		end
		table.clear(listings)
	end

	-- // Rebuilds the grid from the open tab. A tab without content opens blank.
	local function refreshListings()
		refreshId += 1
		local thisRefreshId = refreshId
		clearListings()
		listingsFrame.CanvasPosition = Vector2.zero

		local tab = currentTabId and tabModules[currentTabId]
		listingsFrame.ScrollingEnabled = tab ~= nil and tab.Scrollable
		if not tab then
			return
		end

		local displays: { ShopListings.ListingDisplay } = {}
		for _, shopListing in tab.getListings() do
			if tab.MaxListings and #displays >= tab.MaxListings then
				break
			end
			local display = ShopListings.getDisplay(shopListing)
			if not display then
				continue
			end
			-- // Regional law restrictions (may yield)
			if display.IsPaidRandomItem and PolicyLibrary.arePaidRandomItemsRestricted(player) then
				continue
			end
			if thisRefreshId ~= refreshId then
				return -- // Another refresh started while this one waited
			end
			table.insert(displays, display)
		end

		for order, display in displays do
			local frame = buildListing(display, order, thisRefreshId)
			frame.Parent = listingsFrame
			table.insert(listings, { Frame = frame, Display = display })
		end
	end

	local function updateTabArt()
		for tabId, button in tabButtons do
			button.Image = if tabId == currentTabId then Art.TabOn else Art.TabOff
		end
	end

	local function selectTab(tabId: string, force: boolean?)
		if not tabButtons[tabId] or (currentTabId == tabId and not force) then
			return
		end
		currentTabId = tabId
		updateTabArt()
		refreshListings()
	end

	local function getDefaultTabId(): string
		for _, tabId in tabOrder do
			if tabDefinitions[tabId].AutoSelect then
				return tabId
			end
		end
		return tabOrder[1]
	end

	local function buildTab(definition: ShopTabDefinition, index: number, root: Frame)
		local x = TABS_ORIGIN.X + (index - 1) * (TAB_SIZE.X + TAB_GAP)
		local button = Kit.create("ImageButton", {
			Name = `Tab{definition.Id}`,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Image = Art.TabOff,
			ScaleType = Enum.ScaleType.Stretch,
			Position = UDim2.fromOffset(x, TABS_ORIGIN.Y),
			Size = UDim2.fromOffset(TAB_SIZE.X, TAB_SIZE.Y),
			Visible = not layout.HideTabs,
			ZIndex = 2,
			Parent = root,
		})
		if definition.IconImage then
			image("Icon", definition.IconImage, TAB_ICON, button, 3)
		end
		outlined("Label", definition.Name, TEXT_SIZE.Tab, if definition.IconImage then TAB_TEXT else TAB_TEXT_NO_ICON, button, 3)
		Kit.pressable(button)
		button.Activated:Connect(function()
			selectTab(definition.Id)
		end)
		tabButtons[definition.Id] = button

		-- // Every tab can be opened; one without content shows blank
		local tab = definition.Tab
		if tab then
			tabModules[definition.Id] = tab
			tab.subscribe(function()
				if ShopGui.Open and currentTabId == definition.Id then
					refreshListings()
				end
			end)
		end
	end

	local function build()
		window = Kit.window(player:WaitForChild("PlayerGui"), config.Name, Art.Window, CANVAS)
		local root = window.root

		outlined("Title", config.Title, TEXT_SIZE.Title, TITLE, root, 2)

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
			ShopGui.close()
		end)

		-- // Currency balance, right of the tabs
		image("BalancePill", Art.TimerPill, BALANCE_PILL, root, 2).ScaleType = Enum.ScaleType.Stretch
		image("BalanceIcon", `rbxassetid://{Icons.CurrencyIcon}`, BALANCE_ICON, root, 3)
		balanceText = outlined("Balance", "0", TEXT_SIZE.Balance, BALANCE_TEXT, root, 3)

		listingsFrame = Kit.create("ScrollingFrame", {
			Name = "Listings",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
			ClipsDescendants = true,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = SCROLLBAR,
			ScrollBarImageColor3 = Theme.Colors.WoodDark,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
			Parent = root,
		}, {
			Kit.create("UIGridLayout", {
				CellSize = UDim2.fromOffset(cellWidth, cellHeight),
				CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
				FillDirection = Enum.FillDirection.Horizontal,
				FillDirectionMaxCells = columns,
				SortOrder = Enum.SortOrder.LayoutOrder,
				StartCorner = Enum.StartCorner.TopLeft,
			}),
		})
		listingsFrame.Position, listingsFrame.Size = rect(LISTINGS)
	end

	-- // In start(): the tab modules subscribe to controllers that must be initialised first
	local function buildTabs()
		for index, definition in config.Tabs do
			table.insert(tabOrder, definition.Id)
			tabDefinitions[definition.Id] = definition
			buildTab(definition, index, window.root)
		end
		updateTabArt()
	end

	-------------------------------------------------------------------------------
	-- PUBLIC FUNCTIONS
	-------------------------------------------------------------------------------

	function ShopGui.open()
		ShopGui.Open = true
		updateBalance()
		selectTab(getDefaultTabId(), true)
		window.open()
		UIController.supercede(config.Name, "GamemodeHud")
		UIController.closeOtherMenus(config.Name) -- // After superceding, so the closing menu doesn't restore the HUD
	end

	function ShopGui.close()
		ShopGui.Open = false
		window.close()
		UIController.unSupercede(config.Name, "GamemodeHud")
		refreshId += 1 -- // Invalidates async listing work still running

		-- // Frees the viewports once the window has shrunk away
		task.delay(0.15, function()
			if not ShopGui.Open then
				clearListings()
			end
		end)
	end

	function ShopGui.toggle()
		if ShopGui.Open then
			ShopGui.close()
		else
			ShopGui.open()
		end
	end

	-------------------------------------------------------------------------------
	-- CORE FUNCTIONS
	-------------------------------------------------------------------------------

	local function _init()
		build()
		EconomyController.CurrencyChangedTasks:Add(function(newBalance)
			updateBalance(newBalance)
		end)
	end

	function ShopGui.start()
		buildTabs()

		-- // Opened from the Shop buttons in MenuButtons; the test key is a Studio-only shortcut
		if RunService:IsStudio() and config.TestKey then
			ContextActionService:BindAction("testopen" .. config.Name, function(_, inputState)
				if inputState == Enum.UserInputState.Begin then
					ShopGui.toggle()
				end
			end, false, config.TestKey)
		end
	end

	_init()

	return ShopGui
end

return ShopBuilder
