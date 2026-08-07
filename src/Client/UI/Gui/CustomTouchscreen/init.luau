local TouchscreenGui = {}
TouchscreenGui.Type = "HUD"
TouchscreenGui.Open = false

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Player = game:GetService("Players").LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientMods = ReplicatedStorage.Client
local SharedMods = ReplicatedStorage.Shared

local _UIController = require(ClientMods.UI.UIController)
local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
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

local lastSignificantThumbstickPosition = aimThumbstick.AbsolutePosition
local aimThumbstickDefaultPosition = aimThumbstick.Position
local draggingAimThumbstick = false
local DragInput = nil
local dragStart = nil
local startPos = nil
local THUMBSTICK_ORIGIN = aimThumbstick.Parent.AbsolutePosition
-- Vector describing straight-forward movement (equivalent of holding W)
local FORWARD_VECTOR = (Vector2.new(THUMBSTICK_ORIGIN.X, THUMBSTICK_ORIGIN.Y - 10) - THUMBSTICK_ORIGIN)

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
	lastSignificantThumbstickPosition = aimThumbstick.AbsolutePosition
	THUMBSTICK_ORIGIN = aimThumbstick.Parent.AbsolutePosition
	if not draggingAimThumbstick then
		draggingAimThumbstick = true
		DragInput = input
		dragStart = input.Position
		startPos = aimThumbstick.Position
		aimThumbstickDragAngle = 0
	end
end

local function drag(input, gameProcessed)
	if input == DragInput and draggingAimThumbstick then
		local delta = input.Position - dragStart
		aimThumbstick.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		-- Change target yaw if the Thumbstick has moved significantly
		if (aimThumbstick.AbsolutePosition - lastSignificantThumbstickPosition).Magnitude > 3 then
			lastSignificantThumbstickPosition = aimThumbstick.AbsolutePosition	

			-- The vector describing the direction the player has moved the Thumbstick
			local adjustedAbsolutePosition = aimThumbstick.AbsolutePosition + Vector2.new(0, 0)
			local moveVector = (adjustedAbsolutePosition - THUMBSTICK_ORIGIN)
			-- The angle between moveVector and FORWARD_VECTOR describes the InputAngle
			local angle = math.acos(FORWARD_VECTOR:Dot(moveVector) / (FORWARD_VECTOR.magnitude * moveVector.magnitude))
			--angle = math.deg(angle) -- convert to degrees from radians
			-- The above angle will always be positive; determine if it is to the left or right
			if adjustedAbsolutePosition.X > THUMBSTICK_ORIGIN.X then
				angle = angle * -1
			end
			-- For some reason, this checker is necessary
			if typeof(angle) == "number" and angle > -3.15 and angle < 3.15 then
            aimThumbstickDragAngle = angle
			end
		end
	end
end

-- Touch has ended
local function touchEnded(input, gameProcessed)
   print(`touch ended`)
	if input == DragInput then
		draggingAimThumbstick = false
		aimThumbstick.Position = aimThumbstickDefaultPosition
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

   GuiService.MenuOpened:Connect(function()
      if draggingAimThumbstick then
			touchEnded(DragInput, false)
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
         TouchscreenGui.close()
      end
   end)
end
_init()

function TouchscreenGui.start()
end

return TouchscreenGui