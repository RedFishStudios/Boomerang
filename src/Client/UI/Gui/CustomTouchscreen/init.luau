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

-- // Touch has started on the thumbstick
local function touchStarted(input, gameProcessed)
	local GuisAtPosition = Player.PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
	for _, o in pairs(GuisAtPosition) do
		if (o:IsA("TextButton") or o:IsA("ImageButton")) and o ~= aimThumbstick then
			return
		end
	end

	-- Presume that they are draggingAimThumbstick it
	-- If they aren't (have only tapped it), there is no consequence
	ensureThumbstickOrigin()
	if not draggingAimThumbstick then
		draggingAimThumbstick = true
		DragInput = input
		dragStart = input.Position
		startPos = aimThumbstick.Position
		aimThumbstickDragAngle = 0
		WeaponController.beginThumbstickAim()
		WeaponController.setThumbstickAimDirection(aimThumbstickDragAngle)
	end
end

local function drag(input, gameProcessed)
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
         warn(angle)
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

local function setupFunctionality()
   if setupDone then
      return
   end
   setupDone = true

   Gui.Dash.Activated:Connect(function()
      AbilityController.activate("Dash")
   end)

   Gui.Stab.Activated:Connect(function()
      AbilityController.activate("Stab")
   end)

	aimThumbstick.InputBegan:Connect(touchStarted)
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