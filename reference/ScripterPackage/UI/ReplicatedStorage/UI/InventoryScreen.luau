-- Inventory window: Skins / Taunts / Arrows / Kill Effects tabs, a grid of item cards, and a detail panel. Built from
-- the "Your Skins" art in the "Official Boomerang! UI" PDF (v2, page 4); positions are mockup pixels.
--
-- Two modes share the art:
--   "inventory" (default): items you own; the ribbon says "YOUR SKINS" etc. and the button equips.
--   "index": every item in the game, including ones you don't have yet (dimmed, showing where they come from);
--            the ribbon says "INDEX: SKINS" etc. and the button only shows Owned / Locked.
--
-- local inventory = InventoryScreen.mount(playerGui, { onEquip = function(categoryId, itemId) ... end })
-- local index = InventoryScreen.mount(playerGui, {}, "index")
-- inventory.setEquipped("Skins", "Chubby") -- from the server's attributes

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Theme = require(Shared:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local Art = Assets.InventoryScreen

local InventoryScreen = {}

export type Mode = "inventory" | "index"

export type Callbacks = {
	onEquip: ((categoryId: string, itemId: string) -> ())?,
}

export type Handle = Kit.Window & {
	showCategory: (categoryId: string) -> (),
	setEquipped: (categoryId: string, itemId: string) -> (),
}

-- Mockup canvas and art rectangles {x, y, w, h}.
local CANVAS = Vector2.new(1714, 1140)
local TABS = {
	Skins = { image = Art.TabSkins, rect = { 100, 205, 190, 220 }, label = "SKINS" },
	Taunts = { image = Art.TabTaunts, rect = { 107, 435, 180, 168 }, label = "TAUNTS" },
	Arrows = { image = Art.TabArrows, rect = { 107, 607, 180, 176 }, label = "ARROWS" },
	KillEffects = { image = Art.TabKillEffects, rect = { 107, 790, 180, 177 }, label = "KILL EFFECTS" },
}
local TAB_DIM = Color3.fromRGB(150, 150, 150) -- tint on tabs that aren't selected
local LOCKED_TINT = Color3.fromRGB(70, 60, 55) -- item art you don't own (index mode)
local CLOSE = { 1478, 80, 124, 120 }
local TITLE = { 640, 60, 570, 104 } -- over the painted-out ribbon, right of the star

-- Card grid (over the painted-out parchment). Cards are 233 x 324 images with ~5 px of margin.
local GRID = { 318, 253, 735, 732 }
local CARD = Vector2.new(233, 324)
local CARD_GAP = Vector2.new(12, 14)
local CARD_ART = { 22, 42, 190, 200 } -- item art box inside a card
local CARD_NAME = { 10, 244, 213, 52 }
local CHECK = { 160, -4, 74, 74 } -- equipped badge, over the card's top-right corner

-- Detail panel.
local NAME = { 1092, 272, 422, 72 }
local RARITY = { 1092, 342, 422, 54 }
local PREVIEW = { 1130, 415, 325, 385 }
local EQUIP = { 1105, 795, 395, 135 }
local EQUIP_TEXT = { 50, 24, 295, 84 }

local function textLayer(label: Frame): TextLabel
	return label:FindFirstChild("Text") :: TextLabel
end

function InventoryScreen.mount(parent: Instance, callbacks: Callbacks?, mode: Mode?): Handle
	local cb: Callbacks = callbacks or {}
	local isIndex = mode == "index"
	local window = Kit.window(parent, if isIndex then "IndexScreen" else "InventoryScreen", Art.Window, CANVAS)
	local root = window.root

	local category: Cosmetics.Category = Cosmetics.list[1]
	local equipped: { [string]: string } = {} -- categoryId -> itemId
	for _, c in Cosmetics.list do
		equipped[c.id] = c.default
	end
	local selected = category.default

	local function visibleItems(c: Cosmetics.Category): { Cosmetics.Item }
		if isIndex then
			return c.items
		end
		local owned = {}
		for _, item in c.items do
			if Cosmetics.ownedByDefault(item) then
				table.insert(owned, item)
			end
		end
		return owned
	end

	local title = Kit.label("", 150, { Name = "Title", ZIndex = 2, Parent = root })
	title.Position, title.Size = Kit.rect(TITLE)

	local tabButtons: { [string]: ImageButton } = {}
	local showCategory: (categoryId: string) -> ()
	for _, c in Cosmetics.list do
		local tab = TABS[c.id]
		local button = Kit.overlayButton(root, "Tab" .. c.id, tab.image, tab.rect)
		button.Activated:Connect(function()
			showCategory(c.id)
		end)
		tabButtons[c.id] = button
	end

	-- Card grid.
	local grid = Kit.create("ScrollingFrame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = Theme.Colors.WoodDark,
		ScrollBarThickness = 10,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
		Parent = root,
	}, {
		Kit.create("UIGridLayout", {
			CellPadding = UDim2.fromOffset(CARD_GAP.X, CARD_GAP.Y),
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for the check badge, which pokes above the first row.
		Kit.create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 2) }),
	})
	grid.Position, grid.Size = Kit.rect(GRID)

	-- Detail panel.
	local nameLabel = Kit.label("", 60, { Name = "ItemName", ZIndex = 2, Parent = root })
	nameLabel.Position, nameLabel.Size = Kit.rect(NAME)
	local rarityLabel = Kit.label("", 44, { Name = "Rarity", ZIndex = 2, Parent = root })
	rarityLabel.Position, rarityLabel.Size = Kit.rect(RARITY)
	local preview = Kit.create("ImageLabel", {
		Name = "Preview",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
		Parent = root,
	})
	preview.Position, preview.Size = Kit.rect(PREVIEW)

	local equipButton = Kit.overlayButton(root, "Equip", Art.Equip, EQUIP)
	local equipLabel = Kit.label("Equip", 150, { Name = "Label", Parent = equipButton })
	equipLabel.Position, equipLabel.Size = Kit.rect(EQUIP_TEXT)

	local cards: { [string]: { button: ImageButton, check: ImageLabel } } = {}

	local function refresh()
		local current = equipped[category.id]
		for id, card in cards do
			card.button.Image = if id == current and not isIndex
				then Art.CardEquipped
				elseif id == selected then Art.CardSelected
				else Art.CardNormal
			card.check.Visible = id == current
		end
		local item = category.byId[selected]
		if not item then
			return
		end
		local owned = Cosmetics.ownedByDefault(item)
		Kit.setText(nameLabel, item.name)
		Kit.setText(rarityLabel, item.rarity)
		textLayer(rarityLabel).TextColor3 = Theme.Rarity[item.rarity] or Theme.Colors.Text
		preview.Image = item.image
		preview.ImageColor3 = if owned then Color3.new(1, 1, 1) else LOCKED_TINT

		if isIndex then
			equipButton.Image = Art.Equipped
			Kit.setEnabled(equipButton, false)
			Kit.setText(equipLabel, if owned then "Owned" else (item.source or "Locked"))
		else
			local isEquipped = selected == current
			equipButton.Image = if isEquipped then Art.Equipped else Art.Equip
			Kit.setEnabled(equipButton, not isEquipped)
			Kit.setText(equipLabel, if isEquipped then "Equipped" else "Equip")
		end
	end

	local function buildCards()
		for _, card in cards do
			card.button:Destroy()
		end
		table.clear(cards)
		for index, item in visibleItems(category) do
			local owned = Cosmetics.ownedByDefault(item)
			local button = Kit.create("ImageButton", {
				Name = item.id,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = Art.CardNormal,
				LayoutOrder = index,
				ZIndex = 2,
			})
			local art = Kit.create("ImageLabel", {
				Name = "Art",
				BackgroundTransparency = 1,
				Image = item.image,
				ImageColor3 = if owned then Color3.new(1, 1, 1) else LOCKED_TINT,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 3,
				Parent = button,
			})
			art.Position, art.Size = Kit.rect(CARD_ART)
			local label = Kit.label(if owned or not isIndex then item.name else "???", 34, {
				Name = "ItemName",
				ZIndex = 3,
				Parent = button,
			})
			label.Position, label.Size = Kit.rect(CARD_NAME)
			local check = Kit.image("ImageLabel", Art.Check, CHECK[1], CHECK[2], CHECK[3], CHECK[4], {
				Name = "Check",
				ZIndex = 4,
				Parent = button,
			})
			button.Activated:Connect(function()
				selected = item.id
				refresh()
			end)
			button.Parent = grid
			cards[item.id] = { button = button, check = check }
		end
	end

	showCategory = function(categoryId: string)
		local next = Cosmetics.byId[categoryId]
		if not next then
			return
		end
		category = next
		selected = equipped[category.id]
		local label = TABS[category.id].label
		Kit.setText(title, if isIndex then "INDEX: " .. label else "YOUR " .. label)
		for id, button in tabButtons do
			button.ImageColor3 = if id == category.id then Color3.new(1, 1, 1) else TAB_DIM
		end
		buildCards()
		grid.CanvasPosition = Vector2.zero
		refresh()
	end

	equipButton.Activated:Connect(function()
		if not isIndex and selected ~= equipped[category.id] and cb.onEquip then
			cb.onEquip(category.id, selected)
		end
	end)

	Kit.overlayButton(root, "Close", Art.Close, CLOSE).Activated:Connect(window.close)
	window.onOpen(function()
		showCategory(category.id)
	end)

	local handle = window :: Handle
	handle.showCategory = showCategory
	handle.setEquipped = function(categoryId: string, itemId: string)
		local c = Cosmetics.byId[categoryId]
		if c and c.byId[itemId] then
			equipped[categoryId] = itemId
			if c == category then
				refresh()
			end
		end
	end
	showCategory(category.id)
	return handle
end

return InventoryScreen
