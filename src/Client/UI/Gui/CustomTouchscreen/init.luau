local TouchscreenGui = {}
TouchscreenGui.Type = "HUD"
TouchscreenGui.Open = false

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = game:GetService("Players").LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientMods = ReplicatedStorage.Client

local _UIController = require(ClientMods.UI.UIController)
local AbilityController = require(ClientMods.Core.AbilityController)
local WeaponController = require(ClientMods.Core.WeaponController)
local PlatformController = require(ClientMods.Core.PlatformController)
local Icons = require(ReplicatedStorage.Shared.Constants.Icons)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)

-- // Gui Values // --

local Gui = script.CustomTouchscreen
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true

local aimThumbstickContainer = Gui.AimThumbstick
local aimThumbstick = aimThumbstickContainer.Thumbstick
local aimThumbstickImage = aimThumbstick.ThumbstickImage

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

-- // MANUAL RECALL MODE (T-138): while the boomerang is dead (or flying back from a manual recall), the aim thumbstick becomes
-- // the Manual Recall button: its knob shows Icons.ManualRecall, it no longer aims, and holding it recalls exactly like holding
-- // E on PC. Back in hand, it's the aim thumbstick again. Each switch pops the knob out a little and back (POP_SCALE).
local POP_SCALE = 1.25 -- // How much bigger the knob pops out when it switches
local POP_OUT_SECONDS = 0.08
local POP_BACK_SECONDS = 0.18

-- // The "Recall" label under the knob in recall mode, in the HUD's text style (MenuButtons: Fredoka One, white, dark brown outline)
local RECALL_LABEL_NAME = "RecallLabel"
local RECALL_LABEL_TEXT = "Recall"
local RECALL_LABEL_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local RECALL_LABEL_COLOR = Color3.fromRGB(255, 255, 255)
local RECALL_LABEL_STROKE_COLOR = Color3.fromRGB(60, 35, 15)
local RECALL_LABEL_STROKE_THICKNESS = 2

local recallMode = false
local recallInput: InputObject? = nil -- // The touch holding the recall (another finger lifting doesn't end it)
local knobScale = Instance.new("UIScale")
knobScale.Parent = aimThumbstick
local popTween: Tween? = nil

-- // The label under the knob (Sol's TextLabel under ThumbstickImage if it's there, else made here with the same layout)
local function getRecallLabel(): TextLabel
	local label = aimThumbstickImage:FindFirstChild(RECALL_LABEL_NAME) or aimThumbstickImage:FindFirstChildWhichIsA("TextLabel")
	if not label then
		label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, 0.8)
		label.Size = UDim2.fromScale(2, 0.3)
		label.Parent = aimThumbstickImage
	end
	label.Name = RECALL_LABEL_NAME
	label.BackgroundTransparency = 1
	label.Text = RECALL_LABEL_TEXT
	label.FontFace = RECALL_LABEL_FONT
	label.TextColor3 = RECALL_LABEL_COLOR
	label.TextScaled = true
	label.TextStrokeTransparency = 1 -- // The UIStroke below draws the outline
	local stroke = label:FindFirstChildWhichIsA("UIStroke") or Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = RECALL_LABEL_STROKE_COLOR
	stroke.Thickness = RECALL_LABEL_STROKE_THICKNESS
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return label
end
local recallLabel = getRecallLabel()
recallLabel.Visible = false

local function toImage(assetId: number): string
	return `rbxassetid://{assetId}`
end

local function needsManualRecall(): boolean
	if DeadWeapons.Data[Player] then
		return true
	end
	local thrownWeaponData = ThrownWeapons.Data[Player]
	return thrownWeaponData ~= nil and thrownWeaponData.RecallFromDead == true -- // Flying back from a manual recall: keep holding
end

local function isBoomerangInHand(): boolean
	return not ThrownWeapons.Data[Player] and not DeadWeapons.Data[Player]
end

-- // The cartoony switch: out to POP_SCALE, then back to normal with a little overshoot
local function popKnob()
	if popTween then
		popTween:Cancel()
	end
	knobScale.Scale = 1
	local popOut = TweenService:Create(knobScale, TweenInfo.new(POP_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = POP_SCALE })
	popTween = popOut
	popOut.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			return
		end
		local popBack = TweenService:Create(knobScale, TweenInfo.new(POP_BACK_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		popTween = popBack
		popBack:Play()
	end)
	popOut:Play()
end

local function endRecallHold()
	if recallInput then
		recallInput = nil
		WeaponController.endRecallInput()
	end
end

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

	-- // MANUAL RECALL MODE: the press starts holding the recall instead of aiming
	if recallMode then
		if not recallInput and WeaponController.beginRecallInput() then
			recallInput = input
		end
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
	if recallInput and input == recallInput then
		endRecallHold()
		return
	end
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

-- // MANUAL RECALL MODE: switch the thumbstick when the boomerang dies, and back once it's in hand again
local function setRecallMode(enabled: boolean)
	if recallMode == enabled then
		return
	end
	recallMode = enabled
	if enabled and draggingAimThumbstick and DragInput then
		touchEnded(DragInput, false, false) -- // Stop aiming without throwing
	end
	if not enabled then
		endRecallHold()
	end
	aimThumbstick.Position = aimThumbstickDefaultPosition
	aimThumbstickImage.Image = toImage(if enabled then Icons.ManualRecall else Icons.AimThumbstick)
	recallLabel.Visible = enabled -- // Pops with the knob (it's inside it)
	popKnob()
end

local function updateRecallMode()
	if not recallMode and needsManualRecall() then
		setRecallMode(true)
	elseif recallMode and isBoomerangInHand() then
		setRecallMode(false)
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
	-- // A mouse click held on the recall button (Studio's touch emulation) ends on the mouse release
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if recallInput and recallInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1 then
			endRecallHold()
		end
	end)
	RunService.Heartbeat:Connect(updateRecallMode)
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
   aimThumbstickImage.Image = toImage(Icons.AimThumbstick)
   Gui.Parent = Player.PlayerGui
   Gui.ClipToDeviceSafeArea = false
   Gui.IgnoreGuiInset = true
	ensureThumbstickOrigin()
	Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutActionButtons)
	aimThumbstickContainer:GetPropertyChangedSignal("AbsolutePosition"):Connect(layoutActionButtons)
	layoutActionButtons()

   GuiService.MenuOpened:Connect(function()
      endRecallHold()
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
			endRecallHold()
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