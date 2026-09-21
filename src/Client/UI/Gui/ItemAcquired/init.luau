local ItemAcquiredGui = {}
ItemAcquiredGui.Type = "HUD"
ItemAcquiredGui.Open = false

local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AcquirableNotifData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Referential"):WaitForChild("AcquirableNotifData"))

local Gui = script:WaitForChild("ItemAcquired") :: ScreenGui
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local Template = script:WaitForChild("Template") :: CanvasGroup

local NOTIFICATION_LIFETIME = 5
local MAX_VISIBLE_NOTIFICATIONS = 3

-- Template authoring values; all runtime sizes derive from these so the width/height ratio is preserved.
local BASE_WIDTH = Template.Size.X.Offset
local BASE_HEIGHT = Template.Size.Y.Offset
local BASE_PADDING = 10
local BASE_MARGIN = Vector2.new(Template.Position.X.Offset, -Template.Position.Y.Offset)
local BASE_VIEWPORT = Vector2.new(1280, 720)
local MIN_SCALE = 0.6
local MAX_SCALE = 1.5

-- Fraction of size/opacity each notification loses for every position it is pushed back in the stack
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
	-- Stacked upwards from the bottom margin, accounting for each lower notification's shrunken height
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

local function resolveImage(image: (string | number)?): string?
	if type(image) == "number" then
		return "rbxassetid://" .. image
	elseif type(image) == "string" and image ~= "" then
		return image
	end
	return nil
end

local function acquiredItem(image: (string | number)?, title: string, subtitle: string)
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
		local resolved = resolveImage(image)
		if resolved then
			imageIcon.Image = resolved
			imageIcon.Visible = true
		else
			imageIcon.Visible = false
		end
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
	acquiredItem(image, title, subtitle)
end

function ItemAcquiredGui.acquiredItem(acquirableItemId: string)
	local itemData = AcquirableNotifData[acquirableItemId]
	if not itemData then
		warn("Acquirable item not found: " .. acquirableItemId)
		return
	end
	acquiredItem(itemData.Img, itemData.Title, itemData.Subtitle)
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