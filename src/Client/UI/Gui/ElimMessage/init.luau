local ElimMessageGui = {}
ElimMessageGui.Type = "HUD"
ElimMessageGui.Open = false

local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer

local Gui = script:WaitForChild("ElimMessage") :: ScreenGui
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local Template = script:WaitForChild("Template") :: CanvasGroup

local NOTIFICATION_LIFETIME = 2
local MAX_VISIBLE_NOTIFICATIONS = 3

-- Template authoring values; all runtime sizes derive from these so the width/height ratio is preserved.
local BASE_MARGIN = Vector2.new(10, 10)
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
	local viewport = Gui.AbsoluteSize
	local maxWidth = viewport.X / 4
	local maxHeight = viewport.Y / 3.5
	-- Y = X / 2.48, but constrained by maxHeight
	local baseWidth = maxWidth
	local baseHeight = math.min(baseWidth / 2.48, maxHeight)
	local scale = getPositionScale(index)
	return UDim2.fromOffset(math.round(baseWidth * scale), math.round(baseHeight * scale))
end

local function getNotificationTransparency(index: number): number
	return math.clamp(TRANSPARENCY_LOST_PER_POSITION * (index - 1), 0, 1)
end

local function getNotificationPosition(index: number): UDim2
	local viewport = Gui.AbsoluteSize
	local maxWidth = viewport.X / 4
	local maxHeight = viewport.Y / 3.5
	local baseHeight = math.min(maxWidth / 2.48, maxHeight)
	
	-- Calculate the height of the first notification
	local firstNotifHeight = baseHeight * getPositionScale(1)
	
	-- Calculate total height needed for all notifications above this one
	local heightAbove = 0
	for i = 1, index - 1 do
		heightAbove += (baseHeight * getPositionScale(i)) / 1.5
	end
	
	-- Position centered on the right side
	local centerY = viewport.Y / 2
	local yOffset = centerY - (firstNotifHeight / 2) - heightAbove
	
	-- Anchor on the right side: X=1 moves to right edge
	return UDim2.new(1, -math.round(BASE_MARGIN.X * currentScale), 0, math.round(yOffset))
end

local function getOffscreenPosition(index: number): UDim2
	local viewport = Gui.AbsoluteSize
	local baseWidth = viewport.X / 4
	local target = getNotificationPosition(index)
	-- Off-screen to the right
	return UDim2.new(target.X.Scale, math.round(baseWidth * getPositionScale(index)), target.Y.Scale, target.Y.Offset)
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

local function getPlayerBustImage(userId: number): string
   print(userId)
   return "rbxthumb://type=AvatarBust&id=" .. userId .. "&w=420&h=420"
end

local function showElimMessage(userIdA: number, userIdB: number, elimType: string)
	ElimMessageGui.open()

	while #activeNotifications >= MAX_VISIBLE_NOTIFICATIONS do
		beginDestruction(activeNotifications[#activeNotifications])
	end

   local playerA = game.Players:GetPlayerByUserId(userIdA)
   local playerB = game.Players:GetPlayerByUserId(userIdB)
   if not playerA or not playerB then
      warn(`discarding elim message for userIdA=${userIdA} userIdB=${userIdB}`)
      return
   end

	currentScale = computeScale()

	local frame = Template:Clone()
	frame.Name = "ElimMessageNotification"
	frame.Size = getNotificationSize(1)
	frame.Position = getOffscreenPosition(1)
	frame.GroupTransparency = 1
	frame.Visible = true

   local PlayerAFrame = frame:FindFirstChild("PlayerA")
   PlayerAFrame.Image = getPlayerBustImage(userIdA)
   local PlayerBFrame = frame:FindFirstChild("PlayerB")
   PlayerBFrame.Image = getPlayerBustImage(userIdB)

   frame:FindFirstChild("ElimType").Text = elimType

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

function ElimMessageGui.open()
	ElimMessageGui.Open = true
	Gui.Enabled = true
end

function ElimMessageGui.close(_instant: boolean?)
	ElimMessageGui.Open = false
	Gui.Enabled = false
	for _, frame in table.clone(activeNotifications) do
		beginDestruction(frame)
	end
end

function ElimMessageGui.showElimMessage(userIdA: number, userIdB: number, elimType: string)
	showElimMessage(userIdA, userIdB, elimType)
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

   game:GetService("ContextActionService"):BindAction("testopenelimnotif", function(_, inputState)
         if inputState == Enum.UserInputState.Begin then
            ElimMessageGui.showElimMessage(game.Players.LocalPlayer.UserId, game.Players.LocalPlayer.UserId, "Tested")
         end
   end, false, Enum.KeyCode.Z)
end
_init()

function ElimMessageGui.start()
   
end

return ElimMessageGui