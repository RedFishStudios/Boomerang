local ItemAcquiredGui = {}
ItemAcquiredGui.Type = "HUD"
ItemAcquiredGui.Open = false

local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientMods = ReplicatedStorage.Client
local AcquirableNotifData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Referential"):WaitForChild("AcquirableNotifData"))

local Gui = script:WaitForChild("ItemAcquired") :: ScreenGui
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local Template = script:WaitForChild("Template") :: Frame

local NOTIFICATION_LIFETIME = 5
local MAX_VISIBLE_NOTIFICATIONS = 3
local NOTIFICATION_PADDING = 10
local NOTIFICATION_HEIGHT = Template.Size.Y.Offset
local NOTIFICATION_POSITION = UDim2.fromScale(0, 1) + UDim2.fromOffset(24, -24)
local MOVE_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DESTROY_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local activeNotifications: { Frame } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function beginDestruction(frame: Frame)
	if frame:GetAttribute("Destroying") then
		return
	end
	frame:SetAttribute("Destroying", true)

	local activeIndex = table.find(activeNotifications, frame)
	if activeIndex then
		table.remove(activeNotifications, activeIndex)
	end

	local tweens = { TweenService:Create(frame, DESTROY_TWEEN_INFO, { BackgroundTransparency = 1 }) }
	for _, descendant in frame:GetDescendants() do
		if descendant:IsA("TextLabel") then
			table.insert(tweens, TweenService:Create(descendant, DESTROY_TWEEN_INFO, { TextTransparency = 1, TextStrokeTransparency = 1 }))
		elseif descendant:IsA("UIStroke") then
			table.insert(tweens, TweenService:Create(descendant, DESTROY_TWEEN_INFO, { Transparency = 1 }))
		end
	end

	for _, tween in tweens do
		tween:Play()
	end

	task.delay(DESTROY_TWEEN_INFO.Time, function()
		if frame then
			frame:Destroy()
		end
	end)
end

local function getNotificationPosition(index: number): UDim2
	return NOTIFICATION_POSITION - UDim2.fromOffset(0, (NOTIFICATION_HEIGHT + NOTIFICATION_PADDING) * (index - 1))
end

local function updateNotificationPositions()
	for index, frame in activeNotifications do
		TweenService:Create(frame, MOVE_TWEEN_INFO, { Position = getNotificationPosition(index) }):Play()
	end
end

local function acquiredItem(image: string, title: string, subtitle: string)
   ItemAcquiredGui.open()

	while #activeNotifications >= MAX_VISIBLE_NOTIFICATIONS do
		beginDestruction(activeNotifications[#activeNotifications])
	end

	local frame = Template:Clone()
	frame.Name = "ItemAcquiredNotification"
	frame.Position = getNotificationPosition(1)
	frame.Visible = true

	local itemNameLabel = frame:FindFirstChild("ItemName")
	if itemNameLabel and itemNameLabel:IsA("TextLabel") then
		itemNameLabel.Text = title
	end

	table.insert(activeNotifications, 1, frame)
	frame.Parent = Gui
	updateNotificationPositions()

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
	for _, frame in activeNotifications do
		beginDestruction(frame)
	end
end

function ItemAcquiredGui.acquiredCustomItem(image: string, title: string, subtitle: string)
   acquiredItem(image, title, subtitle)
end

function ItemAcquiredGui.acquiredItem(acquirableItemId: string)
   local itemData = AcquirableNotifData[acquirableItemId]
   if not itemData then
      warn("Acquirable item not found: " .. acquirableItemId) 
      return
   end
	acquiredItem(itemData.Image, itemData.Title, itemData.Subtitle)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	Gui.Parent = Player.PlayerGui
	Gui.Enabled = false
	Template.Visible = false
end
_init()

function ItemAcquiredGui.start()
   game:GetService("ContextActionService"):BindAction("testacquireitemnotif", function(_, inputState)
       if inputState == Enum.UserInputState.Begin then
           ItemAcquiredGui.acquiredItem("OnFire")
       end
   end, false, Enum.KeyCode.B)
end

return ItemAcquiredGui
