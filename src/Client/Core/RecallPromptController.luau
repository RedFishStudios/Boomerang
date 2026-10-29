--[[
	RecallPromptController (T-149)

	Description:
	PC and console: when the local player's boomerang is dead (or dying) on the field, a small green "[E] Recall" prompt
	pops up above their head, telling them to hold the recall key. It goes away (pop out) once they start recalling, when
	the boomerang is back, or when they switch to touch (touch players have the Manual Recall button instead).

	- A BillboardGui on its own invisible host part (client-only, under the camera) that this controller moves every frame:
	  it follows the player's root horizontally, but its height is smoothed (small ups and downs from walking or
	  prediction corrections are eased out; a jump or a step up is followed quickly), so the prompt stays level instead of
	  wiggling with the character. StudsOffsetWorldSpace puts the anchor just above the head (the head's height over the
	  root is measured once each time it pops in), and SizeOffset (0, 0.5) raises the prompt by half its height in SCREEN
	  space, so its bottom edge sits on that point and it reads as "above the head" from the top-down camera (looking
	  down at the head) and the over-the-shoulder camera alike.
	- Its size is in studs (Scale), recomputed every frame from the camera's distance and field of view, so it's the same
	  size on screen in both camera modes (SCREEN_HEIGHT_FRACTION of the screen's height).
	- Everything sits in a CanvasGroup, so the pop animations fade the whole prompt at once (GroupTransparency) and scale
	  it with a UIScale (never below MIN_SCALE: a CanvasGroup shrunk to nothing breaks).
	- The key shown is the platform's own label / button image for the recall key (WeaponController's recall keys).
]]

local RecallPromptController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)
local DeadWeaponLogic = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Dead)
local CreateElement = require(ReplicatedStorage.Shared.Utils.CreateElement)
local PlatformController = require(ReplicatedStorage.Client.Core.PlatformController)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local WeaponController = require(ReplicatedStorage.Client.Core.WeaponController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Look
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local FRAME_COLOR = Color3.fromRGB(80, 190, 70)
local OUTLINE_COLOR = Color3.fromRGB(60, 35, 15) -- // The HUD's dark brown outline
local KEY_BOX_COLOR = Color3.fromRGB(55, 140, 50)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local PROMPT_ASPECT_RATIO = 2.7 -- // Width / height
local SCREEN_HEIGHT_FRACTION = 0.065 -- // The prompt's height as a fraction of the screen's height
local HEAD_CLEARANCE = 0.6 -- // Studs between the top of the head and the prompt's bottom edge
local DEFAULT_HEAD_TOP_ABOVE_ANCHOR = 2.3 -- // Head top over the root's centre when the rendered head can't be measured
-- // The host's height follows the root slowly for small changes (walk bob, prediction jitter) and quickly for big ones
local LEVEL_FOLLOW_RATE = 3 -- // Per second, for height changes within LEVEL_DEADBAND
local LEVEL_CATCHUP_RATE = 18 -- // Per second, for bigger changes (jumps, steps, falls)
local LEVEL_DEADBAND = 1 -- // Studs
local RENDER_PRIORITY = Enum.RenderPriority.Last.Value -- // After the camera and the character have moved this frame

-- // Pop in: from MIN_SCALE and invisible, overshoot to POP_IN_OVERSHOOT_SCALE while fading in fast, settle to 1
local MIN_SCALE = 0.8
local POP_IN_OVERSHOOT_SCALE = 1.15
local POP_IN_GROW = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_IN_SETTLE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local POP_IN_FADE = TweenInfo.new(0.1, Enum.EasingStyle.Linear)
-- // Pop out: expand to POP_OUT_EXPAND_SCALE, then shrink to MIN_SCALE, fading out the whole time
local POP_OUT_EXPAND_SCALE = 1.12
local POP_OUT_EXPAND = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_OUT_SHRINK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local POP_OUT_FADE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer

local billboard: BillboardGui
local host: Part -- // The invisible part the billboard hangs from (see the header)
local hostY: number? = nil -- // Its smoothed height (nil = jump straight to the root next frame)
local canvas: CanvasGroup
local uiScale: UIScale
local keyLabel: TextLabel
local keyImage: ImageLabel
local isShown = false
local animationToken = 0
local shownScheme: string? = nil
local headTopAboveAnchor = DEFAULT_HEAD_TOP_ABOVE_ANCHOR

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function build()
	keyLabel = CreateElement("TextLabel", {
		Name = "KeyText",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextScaled = true,
		TextColor3 = TEXT_COLOR,
		Text = "E",
	}, { CreateElement("UIStroke", { Color = OUTLINE_COLOR, Thickness = 1.5 }) })

	keyImage = CreateElement("ImageLabel", {
		Name = "KeyImage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.85),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	})

	local keyBox = CreateElement("Frame", {
		Name = "KeyBox",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.07, 0.5),
		Size = UDim2.fromScale(0.62, 0.62), -- // Square (the aspect constraint keeps it so): 62% of the height
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = KEY_BOX_COLOR,
		BorderSizePixel = 0,
	}, {
		CreateElement("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
		CreateElement("UIStroke", { Color = TEXT_COLOR, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		keyLabel,
		keyImage,
	})

	local recallText = CreateElement("TextLabel", {
		Name = "RecallText",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.93, 0.5),
		Size = UDim2.fromScale(0.58, 0.6),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextScaled = true,
		TextColor3 = TEXT_COLOR,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Recall",
	}, { CreateElement("UIStroke", { Color = OUTLINE_COLOR, Thickness = 2 }) })

	local frame = CreateElement("Frame", {
		Name = "Frame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = FRAME_COLOR,
		BorderSizePixel = 0,
	}, {
		CreateElement("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
		CreateElement("UIStroke", { Color = OUTLINE_COLOR, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		keyBox,
		recallText,
	})

	uiScale = CreateElement("UIScale", { Scale = MIN_SCALE }) :: UIScale

	-- // Inset a little so the outline and the overshoot aren't clipped by the billboard's edges
	canvas = CreateElement("CanvasGroup", {
		Name = "Prompt",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
	}, { uiScale, frame }) :: CanvasGroup

	billboard = CreateElement("BillboardGui", {
		Name = "RecallPrompt",
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Size = UDim2.fromScale(3, 3 / PROMPT_ASPECT_RATIO),
		SizeOffset = Vector2.new(0, 0.5), -- // Bottom edge on the anchor point, in screen space (see the header)
		ClipsDescendants = false,
	}, { canvas }) :: BillboardGui
	billboard.Parent = localPlayer:WaitForChild("PlayerGui")

	host = Instance.new("Part")
	host.Name = "RecallPromptHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.Parent = workspace.CurrentCamera -- // Local only: never replicated, never hit by anything
	billboard.Adornee = host
end

-- // The recall key for the current control scheme, as the platform's label or button image
local function updateKeyDisplay(scheme: string)
	if shownScheme == scheme then
		return
	end
	shownScheme = scheme
	local keyCode = if scheme == "Console" then WeaponController.RECALL_GAMEPAD_KEY else WeaponController.RECALL_KEY
	local image = if scheme == "Console" then UserInputService:GetImageForKeyCode(keyCode) else ""
	if image and image ~= "" then
		keyImage.Image = image
		keyImage.Visible = true
		keyLabel.Visible = false
	else
		local text = UserInputService:GetStringForKeyCode(keyCode)
		keyLabel.Text = if text and text ~= "" then text else (keyCode.Name:gsub("^Button", ""))
		keyImage.Visible = false
		keyLabel.Visible = true
	end
end

-- // The part whose position the host follows: the player's root (physics character), else the rendered one
local function getAnchor(): BasePart?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	local rendered = CharacterRenderController.getCharacterModel(localPlayer, false)
	local renderedRoot = rendered and rendered:FindFirstChild("HumanoidRootPart")
	return if renderedRoot and renderedRoot:IsA("BasePart") then renderedRoot else nil
end

-- // How far the top of the (rendered) head is above the anchor; measured once per pop-in, so the walk bob doesn't move it
local function measureHeadTop(anchor: BasePart): number
	local rendered = CharacterRenderController.getCharacterModel(localPlayer, false)
	local head = rendered and rendered:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local above = head.Position.Y + head.Size.Y / 2 - anchor.Position.Y
		if above > 0 and above < 10 then
			return above
		end
	end
	return DEFAULT_HEAD_TOP_ABOVE_ANCHOR
end

-- // Moves the host to the anchor: same X / Z, smoothed height
local function moveHost(anchor: BasePart, deltaTime: number)
	local position = anchor.Position
	local targetY = position.Y
	if hostY == nil then
		hostY = targetY
	else
		local difference = targetY - hostY
		local rate = if math.abs(difference) > LEVEL_DEADBAND then LEVEL_CATCHUP_RATE else LEVEL_FOLLOW_RATE
		hostY += difference * (1 - math.exp(-rate * deltaTime))
	end
	host.CFrame = CFrame.new(position.X, hostY :: number, position.Z)
	if host.Parent ~= workspace.CurrentCamera then
		host.Parent = workspace.CurrentCamera -- // The camera was replaced
	end
end

local function shouldShow(scheme: string): boolean
	if scheme ~= "PC" and scheme ~= "Console" then
		return false
	end
	local deadWeaponData = DeadWeapons.Data[localPlayer]
	if not deadWeaponData then
		return false
	end
	if WeaponController.isRecallHeld() or DeadWeaponLogic.isRecallCharging(deadWeaponData) then
		return false -- // Already recalling
	end
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function popIn()
	animationToken += 1
	local token = animationToken
	billboard.Enabled = true
	uiScale.Scale = MIN_SCALE
	canvas.GroupTransparency = 1
	TweenService:Create(canvas, POP_IN_FADE, { GroupTransparency = 0 }):Play()
	local grow = TweenService:Create(uiScale, POP_IN_GROW, { Scale = POP_IN_OVERSHOOT_SCALE })
	grow.Completed:Connect(function()
		if token == animationToken then
			TweenService:Create(uiScale, POP_IN_SETTLE, { Scale = 1 }):Play()
		end
	end)
	grow:Play()
end

local function popOut()
	animationToken += 1
	local token = animationToken
	TweenService:Create(canvas, POP_OUT_FADE, { GroupTransparency = 1 }):Play()
	local expand = TweenService:Create(uiScale, POP_OUT_EXPAND, { Scale = POP_OUT_EXPAND_SCALE })
	expand.Completed:Connect(function()
		if token ~= animationToken then
			return
		end
		local shrink = TweenService:Create(uiScale, POP_OUT_SHRINK, { Scale = MIN_SCALE })
		shrink.Completed:Connect(function()
			if token == animationToken then
				billboard.Enabled = false
			end
		end)
		shrink:Play()
	end)
	expand:Play()
end

local function update(deltaTime: number)
	local scheme = PlatformController.getDominantControlScheme()
	local show = shouldShow(scheme)
	local anchor = getAnchor()
	if show and not anchor then
		show = false
	end

	if show ~= isShown then
		isShown = show
		if show then
			updateKeyDisplay(scheme)
			headTopAboveAnchor = measureHeadTop(anchor :: BasePart)
			hostY = nil -- // Start level with the player
			popIn()
		else
			popOut()
		end
	elseif show then
		updateKeyDisplay(scheme)
	end

	if not billboard.Enabled or not anchor then
		return
	end
	moveHost(anchor, deltaTime)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, headTopAboveAnchor + HEAD_CLEARANCE, 0)

	-- // Same size on screen at any camera distance (top-down is far away, over-the-shoulder is close)
	local camera = workspace.CurrentCamera
	if camera then
		local distance = (camera.CFrame.Position - host.Position).Magnitude
		local visibleHeight = 2 * distance * math.tan(math.rad(camera.FieldOfView) / 2)
		local height = math.max(visibleHeight * SCREEN_HEIGHT_FRACTION, 0.1)
		billboard.Size = UDim2.fromScale(height * PROMPT_ASPECT_RATIO, height)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RecallPromptController.init() end

function RecallPromptController.start()
	build()
	RunService:BindToRenderStep("RecallPrompt", RENDER_PRIORITY, update)
end

return RecallPromptController
