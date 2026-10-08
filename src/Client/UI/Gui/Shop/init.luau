--[[
	Shop (T-076)

	Description:
	The Shop menu, opened from the Shop button in the left lobby menu (MenuButtons).
	The tab row at the top picks what the listing grid shows (tabs and their order: Shared/Referential/ShopItems).
	A tab's content comes from the module with the same name in Tabs/ (shape: ShopTab below); a tab without a module
	is selectable but opens blank (placeholder until the feature exists: Emotes, Arrows, Effects).
	The grid shows 3x2 listings at once. A tab with Scrollable = true scrolls past 6 listings; the others show at most 6.
	A listing's data comes from ShopListings (skins: the same system as the Inventory's Skins tab) and is tinted by
	rarity with RarityStyles. Models are shown with ItemViewport (Client/UI/ItemViewport).
	The balance plank at the bottom shows the player's Currency (EconomyController).
	Built entirely in code with CreateElement (no GUI instances stored under this script); the frame, tab, listing, balance
	and button art are image assets (Shared/Constants/Icons). The emoji beside the tab names are placeholders in their own
	labels (ICON_EmojiPlaceholder), ready to be replaced with images.
]]

local ShopGui = {}
ShopGui.Type = "HUD"
ShopGui.Open = false
ShopGui.RequiresMouse = true -- // Clickable menu: frees the mouse in the locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local ItemViewport = require(ReplicatedStorage.Client.UI.ItemViewport)
local ShopController = require(ReplicatedStorage.Client.Core.ShopController)
local EconomyController = require(ReplicatedStorage.Client.Core.EconomyController)
local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local MarketplaceLibrary = require(ReplicatedStorage.Shared.Library.MarketplaceLibrary)
local PolicyLibrary = require(ReplicatedStorage.Shared.Library.PolicyLibrary)
local CreateElement = require(ReplicatedStorage.Shared.Utils.CreateElement)
local ShopListings = require(script.ShopListings)
local RarityStyles = require(script.RarityStyles)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ShopTab = {
	Scrollable: boolean, -- // Whether the grid scrolls past 6 listings (false: only the first MaxListings are shown)
	MaxListings: number?, -- // Cap on the listings shown (the Featured tab shows 6)
	getListings: () -> { ShopItems.ShopListing }, -- // In display order
	subscribe: (onChanged: () -> ()) -> (), -- // Called once; onChanged runs whenever the listings or their ownership change
}

type ListingState = {
	Display: ShopListings.ListingDisplay,
	ShowRobux: boolean,
	ShowGift: boolean,
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

-- // Colors (the tab, listing and button art is grayscale and tinted with ImageColor3)
local TITLE_COLOR = Color3.fromRGB(92, 52, 20)
local OUTLINE_COLOR = Color3.fromRGB(45, 28, 12)
local PRICE_OUTLINE_COLOR = Color3.fromRGB(30, 45, 18)
local SELECTED_TAB_COLOR = Color3.fromRGB(190, 130, 255)
local UNSELECTED_TAB_COLOR = Color3.fromRGB(225, 160, 100)
local CURRENCY_BUTTON_COLOR = Color3.fromRGB(150, 255, 90)
local ROBUX_BUTTON_COLOR = Color3.fromRGB(110, 190, 255)
local GIFT_BUTTON_COLOR = Color3.fromRGB(200, 130, 255)
local OWNED_BUTTON_COLOR = Color3.fromRGB(150, 150, 150)
local OWNED_TEXT = "Owned"
local FREE_TEXT = "Free"

-- // Layout (all scales; the grid's pixel sizes are measured in layoutGrid)
local CONTAINER_ASPECT_RATIO = 1.5 -- // Shop frame art: 1536 x 1024
local GRID_COLUMNS = 3
local GRID_ROWS = 2 -- // Rows visible at once
local GRID_GAP_FRACTION = 0.012 -- // Gap between listings, as a fraction of the grid's width
local SCROLLBAR_FRACTION = 0.022 -- // Scroll bar thickness, as a fraction of the grid's width
local BUTTONS_SIZE = UDim2.fromScale(0.88, 0.215) -- // The price / gift / Robux row under a listing, in its listing
local BUTTON_GAP = 0.03 -- // Gap between the buttons under a listing, as a fraction of their row's width

-- // Gifting isn't implemented yet: the square gift button is built and positioned, but hidden until it does something
local GIFTING_ENABLED = false

local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local HOVER_SCALE = 1.06
local HOVER_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local ShopScreenGui: ScreenGui
local Container: ImageLabel
local TabsFrame: Frame
local ListingsFrame: ScrollingFrame
local GridLayout: UIGridLayout
local BalanceAmount: TextLabel
local containerGoalPosition: UDim2
local containerOffscreenPosition: UDim2
local activeTween: Tween?

local tabModules: { [string]: ShopTab } = {}
local tabButtons: { [string]: ImageButton } = {}
local tabOrder: { string } = {}
local currentTabId: string? = nil
local currentScrollable = false
local listingStates: { [GuiObject]: ListingState } = {}
local listingCount = 0
local giftFraction = 0.18 -- // Width of the square gift button relative to its row; measured in layoutGrid
local refreshId = 0 -- // Bumped on every refresh so stale async work (policy, Robux prices) can tell

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // CreateElement returns the instance and its destroyers; only the instance is wanted here
local function new(className: string, properties: { [string]: any }, children: { any }?): any
	local element = CreateElement(className, properties, children)
	return element
end

local function createStroke(color: Color3, thickness: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 0.08,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function createLabel(properties: { [string]: any }, children: { any }?): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextScaled = true,
		TextSize = 8,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}
	for property, value in properties do
		defaults[property] = value
	end
	return new("TextLabel", defaults, children)
end

-- // 1500 -> "1,500"
local function formatAmount(amount: number): string
	local text = tostring(math.floor(amount))
	local reversed = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (reversed:gsub("^,", ""))
end

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

local function updateBalance(balance: number?)
	BalanceAmount.Text = formatAmount(balance or EconomyController.getBalance())
end

-- // The title, close button, tab row, listing grid and balance plank
local function createGui(): ScreenGui
	local title = createLabel({
		Name = "Title",
		Text = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.068),
		Size = UDim2.fromScale(0.3, 0.1),
		TextColor3 = TITLE_COLOR,
	})

	local exit = new("ImageButton", {
		Name = "Exit",
		Image = `rbxassetid://{Icons.CloseButton}`,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.945, 0.1),
		Size = UDim2.fromScale(0.09, 0.13),
		ZIndex = 5,
		MouseButton1Click = function()
			ShopGui.close()
		end,
	}, {
		new("UIAspectRatioConstraint", {}),
		new("UIScale", {}),
	})
	setupButtonHover(exit)

	TabsFrame = new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.098, 0.13),
		Size = UDim2.fromScale(0.8, 0.08),
		ZIndex = 2,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.01, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	GridLayout = new("UIGridLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = GRID_COLUMNS,
		SortOrder = Enum.SortOrder.LayoutOrder,
		StartCorner = Enum.StartCorner.TopLeft,
	})

	ListingsFrame = new("ScrollingFrame", {
		Name = "Listings",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.101, 0.243),
		Size = UDim2.fromScale(0.824, 0.616),
		ZIndex = 2,
		ClipsDescendants = true,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Color3.fromRGB(122, 78, 42),
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- // The window shrinks by the bar's width while it's shown
		VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, { GridLayout })

	BalanceAmount = createLabel({
		Name = "Amount",
		Text = "0",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.34, 0.5),
		Size = UDim2.fromScale(0.52, 0.6),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { createStroke(OUTLINE_COLOR) })

	local balance = new("ImageLabel", {
		Name = "Balance",
		Image = `rbxassetid://{Icons.ShopBalanceFrame}`,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.892),
		Size = UDim2.fromScale(0.32, 0.098),
		ZIndex = 3,
	}, {
		new("ImageLabel", {
			Name = "CurrencyIcon",
			Image = `rbxassetid://{Icons.CurrencyIcon}`,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.1, 0.5),
			Size = UDim2.fromScale(0.2, 0.72),
			ZIndex = 4,
		}, { new("UIAspectRatioConstraint", {}) }),
		BalanceAmount,
	})

	Container = new("ImageLabel", {
		Name = "Container",
		Image = `rbxassetid://{Icons.ShopFrame}`,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.64, 0.88),
		ZIndex = 1,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = CONTAINER_ASPECT_RATIO }),
		title,
		exit,
		TabsFrame,
		ListingsFrame,
		balance,
	})

	return new("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true, -- // Covers the whole screen, top bar included...
		ScreenInsets = Enum.ScreenInsets.None, -- // ...and doesn't follow the device's safe areas
		Enabled = false,
	}, { Container })
end

local function createTabButton(tabId: string, order: number): ImageButton
	local tabInfo = ShopItems.Tabs[tabId]
	return new("ImageButton", {
		Name = tabId,
		LayoutOrder = order,
		Image = `rbxassetid://{Icons.ShopTabButton}`,
		ImageColor3 = UNSELECTED_TAB_COLOR,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(0.192, 1),
		ZIndex = 2,
	}, {
		new("UIScale", {}),
		-- // ICON PLACEHOLDER: an emoji in its own label (separate from the text). Replace this label with an ImageLabel
		-- // (Image = the tab's icon) once icon art exists.
		createLabel({
			Name = "ICON_EmojiPlaceholder",
			Text = tabInfo.Icon,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.07, 0.48),
			Size = UDim2.fromScale(0.2, 0.62),
		}, { new("UIAspectRatioConstraint", {}) }),
		createLabel({
			Name = "Label",
			Text = tabInfo.Name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.62, 0.5),
			Size = UDim2.fromScale(0.58, 0.5),
		}, { createStroke(OUTLINE_COLOR) }),
	})
end

-- // A price button: coin or Robux icon + amount on a tinted wide button
local function createPriceButton(name: string, order: number, color: Color3, iconImage: number): ImageButton
	return new("ImageButton", {
		Name = name,
		LayoutOrder = order,
		Image = `rbxassetid://{Icons.ShopWideButton}`,
		ImageColor3 = color,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(0.5, 1),
		ZIndex = 4,
	}, {
		new("UIScale", {}),
		new("ImageLabel", {
			Name = "Icon",
			Image = `rbxassetid://{iconImage}`,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.07, 0.5),
			Size = UDim2.fromScale(0.25, 0.7),
			ZIndex = 5,
		}, { new("UIAspectRatioConstraint", {}) }),
		createLabel({
			Name = "PriceText",
			Text = "0",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.66, 0.5),
			Size = UDim2.fromScale(0.58, 0.58),
			ZIndex = 5,
		}, { createStroke(PRICE_OUTLINE_COLOR) }),
	})
end

-- // One grid cell: name, rarity, the model, and the price / gift / Robux buttons. Its size comes from the GridLayout.
local function createListing(display: ShopListings.ListingDisplay, order: number): ImageLabel
	local style = RarityStyles.get(display.Rarity)

	local viewport = new("ViewportFrame", {
		Name = "Viewport",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.7, 0.4),
		ZIndex = 3,
	}, { new("UIAspectRatioConstraint", {}) })
	if display.ModelName then
		ItemViewport.renderTool(viewport, display.ModelName)
	end

	local giftButton = new("ImageButton", {
		Name = "Gift",
		LayoutOrder = 2,
		Image = `rbxassetid://{Icons.ShopSquareButton}`,
		ImageColor3 = GIFT_BUTTON_COLOR,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		ZIndex = 4,
	}, {
		new("UIScale", {}),
		new("ImageLabel", {
			Name = "Icon",
			Image = `rbxassetid://{Icons.GiftIcon}`,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			ZIndex = 5,
		}),
	})

	local buttons = new("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.715),
		Size = BUTTONS_SIZE,
		ZIndex = 3,
	}, {
		createPriceButton("Currency", 1, CURRENCY_BUTTON_COLOR, Icons.CurrencyIcon),
		giftButton,
		createPriceButton("Robux", 3, ROBUX_BUTTON_COLOR, Icons.RobuxIcon),
	})

	return new("ImageLabel", {
		Name = display.Id,
		LayoutOrder = order,
		Image = `rbxassetid://{Icons.ShopListingBase}`,
		ImageColor3 = style.Color, -- // RARITY: the frame is tinted by the item's rarity
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, {
		createLabel({
			Name = "ItemName",
			Text = display.Name,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.075),
			Size = UDim2.fromScale(0.74, 0.1),
		}, { createStroke(OUTLINE_COLOR) }),
		createLabel({
			Name = "Rarity",
			Text = display.Rarity,
			TextColor3 = style.TextColor,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.18),
			Size = UDim2.fromScale(0.5, 0.065),
		}, { createStroke(OUTLINE_COLOR) }),
		viewport,
		buttons,
	})
end

-- // Places the price / gift / Robux buttons of a listing side by side, filling the row (positions are scales)
local function layoutButtons(listing: GuiObject)
	local state = listingStates[listing]
	if not state then
		return
	end
	local buttons = listing.Buttons
	local currency = buttons.Currency
	local gift = buttons.Gift
	local robux = buttons.Robux

	gift.Visible = state.ShowGift
	robux.Visible = state.ShowRobux

	local wideCount = 1 + (if state.ShowRobux then 1 else 0)
	local itemCount = wideCount + (if state.ShowGift then 1 else 0)
	local giftWidth = if state.ShowGift then giftFraction else 0
	local wideWidth = (1 - giftWidth - BUTTON_GAP * (itemCount - 1)) / wideCount

	local x = 0
	currency.Position = UDim2.fromScale(x, 0)
	currency.Size = UDim2.fromScale(wideWidth, 1)
	x += wideWidth + BUTTON_GAP
	if state.ShowGift then
		gift.Position = UDim2.fromScale(x, 0)
		gift.Size = UDim2.fromScale(giftWidth, 1)
		x += giftWidth + BUTTON_GAP
	end
	if state.ShowRobux then
		robux.Position = UDim2.fromScale(x, 0)
		robux.Size = UDim2.fromScale(wideWidth, 1)
	end
end

-- // Sizes the 3x2 grid from the grid's measured size (the Container keeps a fixed aspect ratio, so this only changes
-- // when the screen does). A scroll bar, when the tab has more than 6 listings, takes its width out of the cells.
local function layoutGrid()
	local size = ListingsFrame.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end

	local scrolls = currentScrollable and listingCount > GRID_COLUMNS * GRID_ROWS
	local gap = math.max(1, math.floor(size.X * GRID_GAP_FRACTION))
	local scrollBar = if scrolls then math.max(4, math.floor(size.X * SCROLLBAR_FRACTION)) else 0
	local availableWidth = size.X - (if scrolls then scrollBar + gap else 0)

	local cellWidth = math.floor((availableWidth - gap * (GRID_COLUMNS - 1)) / GRID_COLUMNS)
	local cellHeight = math.floor((size.Y - gap * (GRID_ROWS - 1)) / GRID_ROWS)

	ListingsFrame.ScrollBarThickness = scrollBar
	ListingsFrame.ScrollingEnabled = scrolls
	GridLayout.CellPadding = UDim2.fromOffset(gap, gap)
	GridLayout.CellSize = UDim2.fromOffset(cellWidth, cellHeight)

	local newGiftFraction = (BUTTONS_SIZE.Y.Scale * cellHeight) / (BUTTONS_SIZE.X.Scale * cellWidth)
	if math.abs(newGiftFraction - giftFraction) > 0.001 then
		giftFraction = newGiftFraction
		for listing in listingStates do
			layoutButtons(listing)
		end
	end
end

local function setPriceButton(button: ImageButton, text: string, showIcon: boolean)
	button.PriceText.Text = text
	button.Icon.Visible = showIcon
	button.PriceText.Position = if showIcon then UDim2.fromScale(0.66, 0.5) else UDim2.fromScale(0.5, 0.5)
end

local function buildListing(display: ShopListings.ListingDisplay, order: number, thisRefreshId: number): GuiObject
	local listing = createListing(display, order)
	local buttons = listing.Buttons
	local currencyButton = buttons.Currency
	local robuxButton = buttons.Robux

	local state: ListingState = {
		Display = display,
		ShowRobux = display.ProductId ~= nil and not display.Owned,
		ShowGift = GIFTING_ENABLED and not display.Owned, -- // TODO: also check PolicyLibrary.isPaidItemTradingAllowed once gifting exists
	}
	listingStates[listing] = state

	-- // Currency price (the main button)
	if display.Owned then
		currencyButton.ImageColor3 = OWNED_BUTTON_COLOR
		setPriceButton(currencyButton, OWNED_TEXT, false)
	else
		setPriceButton(currencyButton, if display.Price <= 0 then FREE_TEXT else formatAmount(display.Price), display.Price > 0)
		setupButtonHover(currencyButton)
		currencyButton.MouseButton1Click:Connect(function()
			-- // The listing refreshes as Owned through the tab's subscribe once the purchase replicates
			ShopController.requestPurchaseItem(display.Id, display.Type)
		end)
	end

	-- // Robux price, when the listing has a developer product: "..." until the price loads, hidden if it can't be bought
	if state.ShowRobux then
		setPriceButton(robuxButton, "...", true)
		setupButtonHover(robuxButton)
		robuxButton.MouseButton1Click:Connect(function()
			ShopController.requestRobuxPurchaseItem(display.Id, display.Type)
		end)
		task.spawn(function()
			local productId = display.ProductId :: number
			local price = MarketplaceLibrary.getProductPrice(productId)
			if thisRefreshId ~= refreshId then
				return
			end
			if price and MarketplaceLibrary.playerCanPurchaseItem(player, productId) then
				robuxButton.PriceText.Text = formatAmount(price)
			else
				state.ShowRobux = false
				layoutButtons(listing)
			end
		end)
	end

	-- // Gift button: TODO wire up once gifting exists
	setupButtonHover(buttons.Gift)

	layoutButtons(listing)
	return listing
end

local function clearListings()
	for listing in listingStates do
		listing:Destroy()
	end
	table.clear(listingStates)
	listingCount = 0
end

-- // Rebuilds the grid from the open tab. A tab without a module (not set up yet) opens blank.
local function refreshListings()
	refreshId += 1
	local thisRefreshId = refreshId
	clearListings()
	ListingsFrame.CanvasPosition = Vector2.zero

	local tab = currentTabId and tabModules[currentTabId]
	currentScrollable = tab ~= nil and tab.Scrollable
	if not tab then
		layoutGrid()
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

	listingCount = #displays
	layoutGrid() -- // Before the listings exist, so the cell size is right for them
	for order, display in displays do
		buildListing(display, order, thisRefreshId).Parent = ListingsFrame
	end
	layoutGrid()
end

local function updateTabColors()
	for tabId, button in tabButtons do
		button.ImageColor3 = if tabId == currentTabId then SELECTED_TAB_COLOR else UNSELECTED_TAB_COLOR
	end
end

local function selectTab(tabId: string, force: boolean?)
	if not tabButtons[tabId] or (currentTabId == tabId and not force) then
		return
	end
	currentTabId = tabId
	updateTabColors()
	refreshListings()
end

local function getDefaultTabId(): string
	for _, tabId in tabOrder do
		if ShopItems.Tabs[tabId].AutoSelect then
			return tabId
		end
	end
	return tabOrder[1]
end

local function buildTabs()
	for tabId in ShopItems.Tabs do
		table.insert(tabOrder, tabId)
	end
	table.sort(tabOrder, function(a, b)
		return ShopItems.Tabs[a].Order < ShopItems.Tabs[b].Order
	end)

	local tabModules_ = script.Tabs
	for order, tabId in tabOrder do
		local button = createTabButton(tabId, order)
		button.Parent = TabsFrame
		tabButtons[tabId] = button

		-- // Every tab can be opened; one without a module (not set up yet) just shows blank content
		local moduleScript = tabModules_:FindFirstChild(tabId)
		if moduleScript then
			local tab = require(moduleScript) :: ShopTab
			tabModules[tabId] = tab
			tab.subscribe(function()
				if ShopGui.Open and currentTabId == tabId then
					refreshListings()
				end
			end)
		end

		setupButtonHover(button)
		button.MouseButton1Click:Connect(function()
			selectTab(tabId)
		end)
	end

	updateTabColors()
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

function ShopGui.open()
	ShopGui.Open = true
	ShopScreenGui.Enabled = true
	updateBalance()
	Container.Position = containerOffscreenPosition
	selectTab(getDefaultTabId(), true)
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
	UIController.supercede("Shop", "GamemodeHud")
end

function ShopGui.close()
	ShopGui.Open = false
	playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
	UIController.unSupercede("Shop", "GamemodeHud")

	task.delay(CONTAINER_TWEEN_INFO_OUT.Time, function()
		if not ShopGui.Open then
			ShopScreenGui.Enabled = false
			refreshId += 1 -- // Drop any async work still running for the listings
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
	ShopScreenGui = createGui()
	ShopScreenGui.Parent = player:WaitForChild("PlayerGui")

	containerGoalPosition = Container.Position
	containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)

	ListingsFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)

	EconomyController.CurrencyChangedTasks:Add(function(newBalance)
		updateBalance(newBalance)
	end)
end

function ShopGui.start()
	buildTabs()

	-- // Opened from the Shop button in MenuButtons; B is a Studio-only shortcut
	if RunService:IsStudio() then
		ContextActionService:BindAction("testopenshopmenu", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				ShopGui.toggle()
			end
		end, false, Enum.KeyCode.B)
	end
end

_init()

return ShopGui
