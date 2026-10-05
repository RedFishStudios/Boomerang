--[[
	Skins (T-072)

	Description:
	The Skins menu, opened from the Skins button in the left lobby menu (MenuButtons).
	Lists every skin (Shared/Referential/Skins) with a 3D preview and an Equip / Equipped / Locked button.
	Built from Skins.rbxmx (the Shop panel) and SkinListingTemplate.rbxmx (the Shop listing card).
]]

local SkinsGui = {}
SkinsGui.Type = "HUD"
SkinsGui.Open = false
SkinsGui.RequiresMouse = true -- // Clickable menu: frees the mouse in the locked camera (MouseUnlockController)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local UIController = require(ReplicatedStorage.Client.UI.UIController)
local SkinController = require(ReplicatedStorage.Client.Core.SkinController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local TEXT_EQUIP = "Equip"
local TEXT_EQUIPPED = "Equipped"
local TEXT_LOCKED = "Locked"
local COLOR_EQUIP = Color3.fromRGB(255, 255, 255)
local COLOR_EQUIPPED = Color3.fromRGB(140, 230, 120)
local COLOR_LOCKED = Color3.fromRGB(150, 150, 150)

local PREVIEW_CAMERA_ANGLE = CFrame.Angles(math.rad(-20), math.rad(35), 0)
local PREVIEW_DISTANCE_MULTIPLIER = 1.3 -- // Camera distance from the model, relative to its size

local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local HOVER_SCALE = 1.05
local HOVER_TILT = 3
local HOVER_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local ToolAssets = ReplicatedStorage.Shared.Assets.Tools

local SkinsScreenGui: ScreenGui = script:WaitForChild("Skins")
local ListingTemplate = script:WaitForChild("SkinListingTemplate")
local Container: Frame
local Content: ScrollingFrame
local containerGoalPosition: UDim2
local containerOffscreenPosition: UDim2
local activeTween: Tween?

local listings: { [string]: GuiObject } = {}
local equipRequestPending = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function setupButtonHover(button: GuiButton)
	local defaultSize = button.Size
	local defaultRotation = button.Rotation
	local hoverSize = UDim2.new(
		defaultSize.X.Scale * HOVER_SCALE,
		defaultSize.X.Offset * HOVER_SCALE,
		defaultSize.Y.Scale * HOVER_SCALE,
		defaultSize.Y.Offset * HOVER_SCALE
	)
	local hoverTween: Tween?

	local function tweenTo(size: UDim2, rotation: number)
		if hoverTween then
			hoverTween:Cancel()
		end
		hoverTween = TweenService:Create(button, HOVER_TWEEN_INFO, { Size = size, Rotation = rotation })
		hoverTween:Play()
	end

	button.MouseEnter:Connect(function()
		tweenTo(hoverSize, defaultRotation + HOVER_TILT)
	end)
	button.MouseLeave:Connect(function()
		tweenTo(defaultSize, defaultRotation)
	end)
end

-- // Puts a copy of the skin's model in the viewport, with a camera framing it
local function setupPreview(viewport: ViewportFrame, modelName: string)
	local asset = ToolAssets:FindFirstChild(modelName)
	if not (asset and asset:IsA("Model")) then
		warn(`SkinsGui: tool model not found for {modelName}`)
		return
	end

	local model = asset:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = viewport

	local boxCFrame, boxSize = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = boxSize.Magnitude * PREVIEW_DISTANCE_MULTIPLIER
	local cameraCFrame = CFrame.new(boxCFrame.Position) * PREVIEW_CAMERA_ANGLE * CFrame.new(0, 0, distance)
	camera.CFrame = CFrame.lookAt(cameraCFrame.Position, boxCFrame.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function updateListing(skinId: string)
	local listing = listings[skinId]
	if not listing then
		return
	end

	local actionText = listing.Action.ActionText
	if not SkinController.ownsSkin(skinId) then
		actionText.Text = TEXT_LOCKED
		actionText.TextColor3 = COLOR_LOCKED
	elseif SkinController.getEquippedSkinId() == skinId then
		actionText.Text = TEXT_EQUIPPED
		actionText.TextColor3 = COLOR_EQUIPPED
	else
		actionText.Text = TEXT_EQUIP
		actionText.TextColor3 = COLOR_EQUIP
	end
end

local function updateAllListings()
	for skinId in listings do
		updateListing(skinId)
	end
end

local function onActionClicked(skinId: string)
	if equipRequestPending or not SkinController.ownsSkin(skinId) or SkinController.getEquippedSkinId() == skinId then
		return
	end

	equipRequestPending = true
	SkinController.requestEquip(skinId)
	equipRequestPending = false
	updateAllListings()
end

local function buildListings()
	for order, skinId in SkinLibrary.getSortedSkinIds() do
		local skin = SkinLibrary.getSkin(skinId)
		if not skin then
			continue
		end

		local listing = ListingTemplate:Clone()
		listing.Name = skinId
		listing.LayoutOrder = order
		listing.ItemName.Text = skin.Name
		setupPreview(listing.Preview, skin.Model)

		listing.Action.MouseButton1Click:Connect(function()
			onActionClicked(skinId)
		end)
		setupButtonHover(listing.Action)

		listing.Parent = Content
		listings[skinId] = listing
		updateListing(skinId)
	end
end

local function playContainerTween(tweenInfo: TweenInfo, goalPosition: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(Container, tweenInfo, { Position = goalPosition })
	activeTween:Play()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SkinsGui.open()
	SkinsGui.Open = true
	SkinsScreenGui.Enabled = true
	updateAllListings()
	Container.Position = containerOffscreenPosition
	playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
	UIController.supercede("Skins", "GamemodeHud")
end

function SkinsGui.close()
	SkinsGui.Open = false
	playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
	UIController.unSupercede("Skins", "GamemodeHud")

	task.delay(0.4, function()
		if not SkinsGui.Open then
			SkinsScreenGui.Enabled = false
		end
	end)
end

function SkinsGui.toggle()
	if SkinsGui.Open then
		SkinsGui.close()
	else
		SkinsGui.open()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	SkinsScreenGui.Enabled = false
	SkinsScreenGui.Parent = player:WaitForChild("PlayerGui")

	Container = SkinsScreenGui:WaitForChild("Container")
	local panel = Container:WaitForChild("ImageLabel")
	Content = panel:WaitForChild("ListingsContent")

	containerGoalPosition = Container.Position
	containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)

	local exitButton = panel:WaitForChild("Exit")
	setupButtonHover(exitButton)
	exitButton.MouseButton1Click:Connect(SkinsGui.close)
end

function SkinsGui.start()
	buildListings()

	SkinController.SkinGrantedTasks:Add(updateListing)
	SkinController.SkinEquippedTasks:Add(updateAllListings)
end

_init()

return SkinsGui
