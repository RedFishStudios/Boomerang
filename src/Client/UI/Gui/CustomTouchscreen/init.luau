local TouchscreenGui = {}
TouchscreenGui.Type = "HUD"
TouchscreenGui.Open = false

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Player = game:GetService("Players").LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientMods = ReplicatedStorage.Client

local _UIController = require(ClientMods.UI.UIController)
local AbilityController = require(ClientMods.Core.AbilityController)
local WeaponController = require(ClientMods.Core.WeaponController)
local PlatformController = require(ClientMods.Core.PlatformController)

-- // Gui Values // --

local Gui = script.CustomTouchscreen
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local aimThumbstickContainer = Gui.AimThumbstick
local aimThumbstick = aimThumbstickContainer.Thumbstick

local aimThumbstickDragAngle = 0

local setupDone = false

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

local aimThumbstickDefaultPosition = aimThumbstick.Position
local draggingAimThumbstick = false
local DragInput = nil
local dragStart = nil
local startPos = nil
local THUMBSTICK_ORIGIN: Vector2? = nil

local function ensureThumbstickOrigin()
	THUMBSTICK_ORIGIN = aimThumbstick.AbsolutePosition
end

local drag

-- // T-118: the circle's center in the same space as the touch positions. Touch positions already line up with this GUI's
-- // AbsolutePosition (it ignores the top bar inset), so no inset correction: subtracting it put the thumbstick below the finger.
local function getContainerCenterInInputSpace(): Vector3
	local center = aimThumbstickContainer.AbsolutePosition + aimThumbstickContainer.AbsoluteSize / 2
	return Vector3.new(center.X, center.Y, 0)
end

-- // Touch has started on the thumbstick, or (T-118) anywhere in the circle around it: aiming starts and the thumbstick
-- // jumps under the finger (its offset from the circle's center is the aim direction, as when dragging)
local function touchStarted(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if draggingAimThumbstick then
		return
	end
	local GuisAtPosition = Player.PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
	for _, o in pairs(GuisAtPosition) do
		if (o:IsA("TextButton") or o:IsA("ImageButton")) and o ~= aimThumbstick then
			return
		end
	end

	-- // Only inside the circle (the container is a square frame with round corners)
	local center = getContainerCenterInInputSpace()
	local radius = math.min(aimThumbstickContainer.AbsoluteSize.X, aimThumbstickContainer.AbsoluteSize.Y) / 2
	if (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(center.X, center.Y)).Magnitude > radius then
		return
	end

	-- Presume that they are draggingAimThumbstick it
	-- If they aren't (have only tapped it), there is no consequence
	ensureThumbstickOrigin()
	draggingAimThumbstick = true
	DragInput = input
	dragStart = center -- // Measured from the circle's center, so the thumbstick sits under the finger
	startPos = aimThumbstickDefaultPosition
	aimThumbstickDragAngle = 0
	WeaponController.beginThumbstickAim()
	WeaponController.setThumbstickAimDirection(aimThumbstickDragAngle)
	drag(input, gameProcessed) -- // Jump to the touch (and aim that way right away)
end

function drag(input, gameProcessed)
	if input == DragInput and draggingAimThumbstick then
		if THUMBSTICK_ORIGIN == nil then
			return
		end

		local delta = input.Position - dragStart
		aimThumbstick.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		local adjustedAbsolutePosition = aimThumbstick.AbsolutePosition
		local moveVector = adjustedAbsolutePosition - THUMBSTICK_ORIGIN
		if moveVector.Magnitude <= 1e-5 then
			return
		end

		-- Signed angle where 0 = up, negative = right, positive = left.
		local angle = -math.atan2(moveVector.X, -moveVector.Y)
		if typeof(angle) == "number" and angle > -3.15 and angle < 3.15 then
			aimThumbstickDragAngle = angle
			WeaponController.setThumbstickAimDirection(angle)
		end
	end
end

-- Touch has ended
local function touchEnded(input, gameProcessed, shouldThrow: boolean?)
	if input == DragInput then
		local releasedAngle = aimThumbstickDragAngle
		draggingAimThumbstick = false
		aimThumbstick.Position = aimThumbstickDefaultPosition
		DragInput = nil
		dragStart = nil
		startPos = nil

		if shouldThrow == false then
			WeaponController.setThumbstickAimDirection(nil)
			return
		end

		WeaponController.releaseThumbstickAim(releasedAngle)
	end
end

-- // T-121: the Dash and Stab buttons sit in a row to the left of the aim circle with a gap between each. Their sizes follow the
-- // screen height but their old positions followed its width, so on some screens they overlapped. Laid out here in pixels from
-- // the aim circle, so the spacing is the same on every screen shape (their Y position still comes from the rbxmx).
local ACTION_BUTTON_GAP = 0.035 -- // Gap between the aim circle, Dash and Stab, as a fraction of the screen height

local function layoutActionButtons()
	local screenHeight = Gui.AbsoluteSize.Y
	if screenHeight <= 0 then
		return
	end
	local gap = screenHeight * ACTION_BUTTON_GAP
	local aimLeft = aimThumbstickContainer.AbsolutePosition.X - Gui.AbsolutePosition.X
	local dash, stab = Gui.Dash, Gui.Stab
	-- // Both are anchored at their right edge (AnchorPoint X = 1)
	dash.Position = UDim2.new(0, aimLeft - gap, dash.Position.Y.Scale, dash.Position.Y.Offset)
	stab.Position = UDim2.new(0, aimLeft - gap - dash.AbsoluteSize.X - gap, stab.Position.Y.Scale, stab.Position.Y.Offset)
end

local function setupFunctionality()
   if setupDone then
      return
   end
   setupDone = true

   Gui.Dash.Activated:Connect(function()
      AbilityController.useMovementInput()
   end)

   Gui.Stab.Activated:Connect(function()
      AbilityController.activate("Stab")
   end)

	aimThumbstick.InputBegan:Connect(touchStarted)
	-- // T-118: touching anywhere in the circle around the thumbstick starts aiming too (and doesn't reach the world/camera)
	aimThumbstickContainer.Active = true
	aimThumbstickContainer.InputBegan:Connect(touchStarted)
	UserInputService.TouchMoved:Connect(drag)
	UserInputService.TouchEnded:Connect(touchEnded)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

----------------------------------------------------------------------------------------------------------------------------------------------------------------

function TouchscreenGui.open()
   setupFunctionality()
   TouchscreenGui.Open = true	
	Gui.Enabled = true
	layoutActionButtons()
end

function TouchscreenGui.close(Instant: boolean?)
   TouchscreenGui.Open = false
	Gui.Enabled = false
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Parent = Player.PlayerGui
   Gui.ClipToDeviceSafeArea = false
   Gui.IgnoreGuiInset = true
	ensureThumbstickOrigin()
	Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutActionButtons)
	aimThumbstickContainer:GetPropertyChangedSignal("AbsolutePosition"):Connect(layoutActionButtons)
	layoutActionButtons()

   GuiService.MenuOpened:Connect(function()
      if draggingAimThumbstick then
			touchEnded(DragInput, false, false)
		end
		draggingAimThumbstick = false
		aimThumbstick.Position = aimThumbstickDefaultPosition
   end)

   if PlatformController.getDominantControlScheme() == "Touch" then
      TouchscreenGui.open()
   else
      TouchscreenGui.close()
   end

   PlatformController.DominantControlSchemeChanged:Add(function(newScheme: "PC" | "Console" | "Touch")
      if newScheme == "Touch" then
         TouchscreenGui.open()
      else
			if draggingAimThumbstick and DragInput then
				touchEnded(DragInput, false, false)
			end
         TouchscreenGui.close()
      end
   end)
end
_init()

function TouchscreenGui.start()
end

--[[

- When the player is dragging the aim thumbstick, the direction the aim thumbstick is being dragged represents the direction their character should face
- When the player begins dragging the thumbstick, they begin Aiming. When they release the thumbstick after a drag, they throw their weapon.

]]

return TouchscreenGui