--[[
	Topbar

	Buttons in Roblox's topbar, in line with the default topbar buttons (player list, chat...).
	The ScreenGui uses TopbarSafeInsets, so it only covers the free part of the topbar between Roblox's own buttons:
	"Left" buttons line up after Roblox's left buttons, "Right" buttons before Roblox's right buttons.

	Every button uses the same text size; its width grows to fit its text (and optional icon).

	Usage (from the module that owns the feature):
		TopbarGui.addButton({
			Id = "DailyRewards",
			Text = "Daily",
			Icon = "🎁",         -- optional: an emoji/text glyph, or an image id ("rbxassetid://...")
			Side = "Left",       -- "Left" or "Right"
			Order = 1,           -- optional: sort order within its side (lowest first)
			onActivated = DailyClaimsGui.toggle,
		})
]]

local TopbarGui = {}
TopbarGui.Type = "Dynamic" -- // Always on screen; not opened/closed with the other HUD guis
TopbarGui.Open = true

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local FONT = Enum.Font.FredokaOne
local TEXT_SIZE = 20 -- // Shared by every topbar button, so their text always matches
local ICON_SIZE = 22
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local BACKGROUND_COLOR = Color3.fromRGB(18, 18, 21) -- // Close to Roblox's own topbar buttons
local BACKGROUND_TRANSPARENCY = 0.3
local HOVER_TRANSPARENCY = 0.15
local PRESS_TRANSPARENCY = 0
local HORIZONTAL_PADDING = 14 -- // Space between the button's edge and its contents
local CONTENT_GAP = 6 -- // Space between the icon and the text
local BUTTON_GAP = 12 -- // Space between buttons (and between Roblox's buttons and ours)
local BUTTON_HEIGHT = 44 -- // Roblox's topbar buttons are 44 px tall (in a 58 px topbar)
local TOP_OFFSET = 12 -- // Roblox's topbar buttons sit 12 px from the top of the screen

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Side = "Left" | "Right"

export type ButtonConfig = {
	Id: string,
	Text: string,
	Icon: string?,
	Side: Side,
	Order: number?,
	onActivated: () -> (),
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local Gui: ScreenGui
local Containers: { [Side]: Frame } = {}
local Buttons: { [string]: TextButton } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function create(className: string, properties: { [string]: any }): any
	local instance = Instance.new(className)
	for property, value in properties do
		if property ~= "Parent" then
			instance[property] = value
		end
	end
	instance.Parent = properties.Parent
	return instance
end

-- // Keeps our buttons the same height and vertical position as Roblox's, scaled down if the topbar is shorter
local function updateHeight()
	local topbarHeight = GuiService.TopbarInset.Height
	if topbarHeight <= 0 then
		return -- // Topbar hidden or not measured yet
	end

	local height = math.min(BUTTON_HEIGHT, topbarHeight - 4)
	local top = math.min(TOP_OFFSET, topbarHeight - height)
	for _, container in Containers do
		container.Position = UDim2.new(container.Position.X.Scale, container.Position.X.Offset, 0, top)
		container.Size = UDim2.new(1, -BUTTON_GAP * 2, 0, height)
	end
end

local function createContainer(side: Side): Frame
	local container = create("Frame", {
		Name = side,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(if side == "Left" then 0 else 1, 0),
		Position = UDim2.new(if side == "Left" then 0 else 1, if side == "Left" then BUTTON_GAP else -BUTTON_GAP, 0, TOP_OFFSET),
		Size = UDim2.new(1, -BUTTON_GAP * 2, 0, BUTTON_HEIGHT),
		Parent = Gui,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = if side == "Left" then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, BUTTON_GAP),
		Parent = container,
	})
	return container
end

local function createIcon(icon: string, parent: GuiObject)
	if string.find(icon, "^rbxasset") or string.find(icon, "^rbxthumb") or string.find(icon, "^http") then
		create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = icon,
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
			Parent = parent,
		})
	else
		create("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Text = icon,
			Font = FONT,
			TextSize = ICON_SIZE,
			TextColor3 = TEXT_COLOR,
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			LayoutOrder = 1,
			Parent = parent,
		})
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Adds a topbar button (or replaces the one with the same Id) and returns it
function TopbarGui.addButton(config: ButtonConfig): TextButton
	TopbarGui.removeButton(config.Id)

	local button = create("TextButton", {
		Name = config.Id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = BACKGROUND_COLOR,
		BackgroundTransparency = BACKGROUND_TRANSPARENCY,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = config.Order or 0,
		Parent = Containers[config.Side] or Containers.Left,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = button })
	create("UIPadding", {
		PaddingLeft = UDim.new(0, HORIZONTAL_PADDING),
		PaddingRight = UDim.new(0, HORIZONTAL_PADDING),
		Parent = button,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, CONTENT_GAP),
		Parent = button,
	})

	if config.Icon and config.Icon ~= "" then
		createIcon(config.Icon, button)
	end

	create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Text = config.Text,
		Font = FONT,
		TextSize = TEXT_SIZE,
		TextColor3 = TEXT_COLOR,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = button,
	})

	-- // Hover / press feedback
	local hovered = false
	button.MouseEnter:Connect(function()
		hovered = true
		button.BackgroundTransparency = HOVER_TRANSPARENCY
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		button.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundTransparency = PRESS_TRANSPARENCY
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundTransparency = if hovered then HOVER_TRANSPARENCY else BACKGROUND_TRANSPARENCY
	end)

	button.Activated:Connect(config.onActivated)

	Buttons[config.Id] = button
	return button
end

function TopbarGui.removeButton(id: string)
	local button = Buttons[id]
	if button then
		button:Destroy()
		Buttons[id] = nil
	end
end

function TopbarGui.getButton(id: string): TextButton?
	return Buttons[id]
end

function TopbarGui.open()
	TopbarGui.Open = true
	Gui.Enabled = true
end

function TopbarGui.close()
	TopbarGui.Open = false
	Gui.Enabled = false
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	Gui = create("ScreenGui", {
		Name = "Topbar",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets, -- // Only the free space between Roblox's topbar buttons
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Enabled = true,
	})
	Containers.Left = createContainer("Left")
	Containers.Right = createContainer("Right")

	updateHeight()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(updateHeight)

	Gui.Parent = player:WaitForChild("PlayerGui")
end

_init()

return TopbarGui
