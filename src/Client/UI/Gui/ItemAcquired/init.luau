--[[
	ItemAcquired

	Description:
	"You got something" popups (items, skins, emotes, taunts, currency, pickups), stacked at the bottom left; the newest is
	at the bottom and older ones shrink and fade upward, each leaving after a few seconds.
	Looks: a blank toast in the style of the new menus (ClientArt/Assets.ItemAcquired.Toast) with the icon or model in its
	blue slot and the title and subtitle printed on the parchment. The template is built in code (TOAST rects are in the
	art's own pixels). The previous template is kept as OldTemplate.rbxmx (reference only).
]]

local ItemAcquiredGui = {}
ItemAcquiredGui.Type = "HUD"
ItemAcquiredGui.Open = false

local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AcquirableThingData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Referential"):WaitForChild("AcquirableThingData"))
local ItemViewport = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ItemViewport"))

local Gui = script:WaitForChild("ItemAcquired") :: ScreenGui
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local Theme = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClientArt"):WaitForChild("Theme"))
local Art = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClientArt"):WaitForChild("Assets")).ItemAcquired

-- // The toast art (1020 x 348) and what goes on it, in its pixels: {x, y, w, h}
local TOAST = Vector2.new(1020, 348)
local TOAST_ICON = { 121, 105, 142, 142 } -- // Inside the blue slot
local TOAST_TITLE = { 300, 92, 640, 86 }
local TOAST_SUBTITLE = { 300, 182, 640, 70 }

local function toastRect(r: { number }): (UDim2, UDim2)
	return UDim2.fromScale(r[1] / TOAST.X, r[2] / TOAST.Y), UDim2.fromScale(r[3] / TOAST.X, r[4] / TOAST.Y)
end

-- // The popup template: the toast image, the icon placeholder (ItemViewport adds a model view next to it) and two
-- // labels printed in the menus' dark brown
local function buildTemplate(): CanvasGroup
	local template = Instance.new("CanvasGroup")
	template.Name = "Template"
	template.BackgroundTransparency = 1
	template.AnchorPoint = Vector2.new(0, 1)
	template.Position = UDim2.new(0, 24, 1, -24)
	template.Size = UDim2.fromOffset(340, math.round(340 * TOAST.Y / TOAST.X))
	template.Visible = false

	local toast = Instance.new("ImageLabel")
	toast.Name = "Toast"
	toast.BackgroundTransparency = 1
	toast.Image = Art.Toast
	toast.Size = UDim2.fromScale(1, 1)
	toast.Parent = template

	local icon = Instance.new("ImageLabel")
	icon.Name = "ImageIcon"
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Position, icon.Size = toastRect(TOAST_ICON)
	icon.ZIndex = 2
	icon.Parent = template

	local function label(name: string, r: { number }, color: Color3)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.FontFace = Theme.Font
		text.TextColor3 = color
		text.TextScaled = true
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Position, text.Size = toastRect(r)
		text.ZIndex = 2
		text.Parent = template
	end
	label("TitleLabel", TOAST_TITLE, Theme.Colors.Ink)
	label("SubtitleLabel", TOAST_SUBTITLE, Theme.Colors.InkSoft)
	return template
end

local Template = buildTemplate()

local NOTIFICATION_LIFETIME = 5
local MAX_VISIBLE_NOTIFICATIONS = 3

-- Template authoring values; runtime sizes derive from these to preserve the width/height ratio
local BASE_WIDTH = Template.Size.X.Offset
local BASE_HEIGHT = Template.Size.Y.Offset
local BASE_PADDING = 10
local BASE_MARGIN = Vector2.new(Template.Position.X.Offset, -Template.Position.Y.Offset)
local BASE_VIEWPORT = Vector2.new(1280, 720)
local MIN_SCALE = 0.6
local MAX_SCALE = 1.5

-- Fraction of size/opacity lost per stack position
local SIZE_LOST_PER_POSITION = 0.1
local TRANSPARENCY_LOST_PER_POSITION = 0.25

local MOVE_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ENTER_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DESTROY_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local activeNotifications: { CanvasGroup } = {}
local currentScale = 1

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function computeScale(): number
	local viewport = Gui.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return currentScale
	end
	local fit = math.min(viewport.X / BASE_VIEWPORT.X, viewport.Y / BASE_VIEWPORT.Y)
	return math.clamp(fit, MIN_SCALE, MAX_SCALE)
end

local function getPositionScale(index: number): number
	return math.max(0, 1 - SIZE_LOST_PER_POSITION * (index - 1)) * currentScale
end

local function getNotificationSize(index: number): UDim2
	local scale = getPositionScale(index)
	return UDim2.fromOffset(math.round(BASE_WIDTH * scale), math.round(BASE_HEIGHT * scale))
end

local function getNotificationTransparency(index: number): number
	return math.clamp(TRANSPARENCY_LOST_PER_POSITION * (index - 1), 0, 1)
end

local function getNotificationPosition(index: number): UDim2
	-- Stacks upward from the bottom margin, accounting for each lower notification's scaled height
	local stackOffset = 0
	for lowerIndex = 1, index - 1 do
		stackOffset += BASE_HEIGHT * getPositionScale(lowerIndex) + BASE_PADDING * currentScale
	end
	return UDim2.new(0, math.round(BASE_MARGIN.X * currentScale), 1, math.round(-BASE_MARGIN.Y * currentScale - stackOffset))
end

local function getOffscreenPosition(index: number): UDim2
	local target = getNotificationPosition(index)
	return UDim2.new(target.X.Scale, -math.round(BASE_WIDTH * getPositionScale(index)), target.Y.Scale, target.Y.Offset)
end

local function updateNotificationLayout(animate: boolean)
	for index, frame in activeNotifications do
		if frame:GetAttribute("Destroying") then
			continue
		end
		local goal = {
			Position = getNotificationPosition(index),
			Size = getNotificationSize(index),
			GroupTransparency = getNotificationTransparency(index),
		}
		if animate then
			TweenService:Create(frame, MOVE_TWEEN_INFO, goal):Play()
		else
			frame.Position = goal.Position
			frame.Size = goal.Size
			frame.GroupTransparency = goal.GroupTransparency
		end
	end
end

local function onViewportResized()
	local scale = computeScale()
	if scale == currentScale then
		return
	end
	currentScale = scale
	updateNotificationLayout(false)
end

local function beginDestruction(frame: CanvasGroup)
	if frame:GetAttribute("Destroying") then
		return
	end
	frame:SetAttribute("Destroying", true)

	local activeIndex = table.find(activeNotifications, frame)
	if activeIndex then
		table.remove(activeNotifications, activeIndex)
	end

	TweenService:Create(frame, DESTROY_TWEEN_INFO, { GroupTransparency = 1 }):Play()
	updateNotificationLayout(true)

	task.delay(DESTROY_TWEEN_INFO.Time, function()
		frame:Destroy()
	end)
end

-- // The icon is a render of `modelName` (a Shared/Assets/Tools model) if given, otherwise the image
local function acquiredItem(image: (string | number)?, modelName: string?, title: string, subtitle: string)
	ItemAcquiredGui.open()

	while #activeNotifications >= MAX_VISIBLE_NOTIFICATIONS do
		beginDestruction(activeNotifications[#activeNotifications])
	end

	currentScale = computeScale()

	local frame = Template:Clone()
	frame.Name = "ItemAcquiredNotification"
	frame.Size = getNotificationSize(1)
	frame.Position = getOffscreenPosition(1)
	frame.GroupTransparency = 1
	frame.Visible = true

	local titleLabel = frame:FindFirstChild("TitleLabel")
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = title
	end

	local subtitleLabel = frame:FindFirstChild("SubtitleLabel")
	if subtitleLabel and subtitleLabel:IsA("TextLabel") then
		subtitleLabel.Text = subtitle
	end

	local imageIcon = frame:FindFirstChild("ImageIcon")
	if imageIcon and imageIcon:IsA("ImageLabel") then
		ItemViewport.setDisplay(imageIcon, image, modelName)
	end

	table.insert(activeNotifications, 1, frame)
	frame.Parent = Gui

	TweenService:Create(frame, ENTER_TWEEN_INFO, { Position = getNotificationPosition(1), GroupTransparency = getNotificationTransparency(1) }):Play()
	for index, other in activeNotifications do
		if other ~= frame and not other:GetAttribute("Destroying") then
			TweenService:Create(other, MOVE_TWEEN_INFO, {
				Position = getNotificationPosition(index),
				Size = getNotificationSize(index),
				GroupTransparency = getNotificationTransparency(index),
			}):Play()
		end
	end

	task.delay(NOTIFICATION_LIFETIME, function()
		beginDestruction(frame)
	end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ItemAcquiredGui.open()
	ItemAcquiredGui.Open = true
	Gui.Enabled = true
end

function ItemAcquiredGui.close(_instant: boolean?)
	ItemAcquiredGui.Open = false
	Gui.Enabled = false
	for _, frame in table.clone(activeNotifications) do
		beginDestruction(frame)
	end
end

function ItemAcquiredGui.acquiredCustomItem(image: (string | number)?, title: string, subtitle: string)
	acquiredItem(image, nil, title, subtitle)
end

-- // Shows a render of a Shared/Assets/Tools model (acquired skin / weapon) instead of an image
function ItemAcquiredGui.acquiredModelItem(modelName: string?, title: string, subtitle: string)
	acquiredItem(nil, modelName, title, subtitle)
end

function ItemAcquiredGui.acquiredItem(acquirableItemId: string)
	local itemData = AcquirableThingData[acquirableItemId]
	if not itemData then
		warn("Acquirable item not found: " .. acquirableItemId)
		return
	end
	acquiredItem(itemData.Img, nil, itemData.Title, itemData.Subtitle)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	Gui.Parent = Player.PlayerGui
	Gui.Enabled = false
	Template.Visible = false
	currentScale = computeScale()
	Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(onViewportResized)
end
_init()

function ItemAcquiredGui.start()
end

return ItemAcquiredGui