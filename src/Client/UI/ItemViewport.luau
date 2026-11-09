--[[
	ItemViewport

	Description:
	Shows a model in a ViewportFrame, posed and framed to fit a square render.
	- renderTool: a model from Shared/Assets/Tools, posed by its Viewport data in Shared/Constants/Tools.
	- renderModel: any model, with an explicit rotation.
	- setDisplay: fills an ImageLabel's spot with an image id or a model render (or nothing).
	Give the ViewportFrame a UIAspectRatioConstraint of 1 to keep the render square.
]]

local ItemViewport = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolLibrary = require(ReplicatedStorage.Shared.Library.ToolLibrary)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FIELD_OF_VIEW = 30
local EMOTES_RIG_NAME = "EmotesRig" -- // Model in ReplicatedStorage: blank character used to preview emotes
local EMOTES_RIG_ROTATION = CFrame.Angles(0, math.pi, 0) -- // Characters face -Z; the camera looks from +Z
local EMOTES_RIG_ZOOM = 0.85 -- // <1 leaves room for emotes that move outside the standing pose
local MARGIN = 1.08 -- // Camera distance multiplier; >1 adds space around the model
local DEFAULT_ROTATION = CFrame.Angles(math.rad(75), 0, 0) -- // Flat models (thin local Y) face the camera, tilted
local CORNER_SIGNS = {
	Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function clear(viewport: ViewportFrame)
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Camera") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
	viewport.CurrentCamera = nil
end

-- // Camera looking along -Z, close enough that every part corner fits in a square view
local function getFittingCameraCFrame(model: Model, zoom: number): CFrame
	local corners = {}
	local minCorner = Vector3.one * math.huge
	local maxCorner = -Vector3.one * math.huge

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local halfSize = part.Size / 2
			for _, sign in CORNER_SIGNS do
				local corner = part.CFrame * (halfSize * sign)
				table.insert(corners, corner)
				minCorner = minCorner:Min(corner)
				maxCorner = maxCorner:Max(corner)
			end
		end
	end

	local center = (minCorner + maxCorner) / 2
	local tanHalfFov = math.tan(math.rad(FIELD_OF_VIEW) / 2)
	local distance = 0
	for _, corner in corners do
		local offset = corner - center
		distance = math.max(distance, offset.Z + math.max(math.abs(offset.X), math.abs(offset.Y)) / tanHalfFov)
	end

	return CFrame.new(center + Vector3.new(0, 0, distance * MARGIN / zoom))
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Replaces the viewport's content with a rotated, framed copy of the model. Returns the copy.
function ItemViewport.renderModel(viewport: ViewportFrame, sourceModel: Model, rotation: CFrame?, zoom: number?): Model
	clear(viewport)

	local model = sourceModel:Clone()
	model:PivotTo(rotation or DEFAULT_ROTATION)
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	camera.CFrame = getFittingCameraCFrame(model, zoom or 1)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	return model
end

-- // Shows a Shared/Assets/Tools model posed by Tools[modelName].Viewport. Returns the copy, or nil if not found.
function ItemViewport.renderTool(viewport: ViewportFrame, modelName: string): Model?
	local asset = ToolLibrary.getToolAssetsFolder():FindFirstChild(modelName)
	if not (asset and asset:IsA("Model")) then
		warn(`ItemViewport: tool model not found for {modelName}`)
		clear(viewport)
		return nil
	end

	local tool = Tools[modelName]
	local viewportData = tool and tool.Viewport
	return ItemViewport.renderModel(
		viewport,
		asset,
		viewportData and viewportData.Rotation,
		viewportData and viewportData.Zoom
	)
end

-- // A ViewportFrame matching `placeholder`'s layout, created once and reused. The caller decides which of the two is
-- // visible.
-- // Aspect ratio constraints are copied to keep the placeholder's shape.
function ItemViewport.getOrCreate(placeholder: GuiObject): ViewportFrame
	local viewportName = `{placeholder.Name}Viewport`
	local existing = placeholder.Parent:FindFirstChild(viewportName)
	if existing and existing:IsA("ViewportFrame") then
		return existing
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = viewportName
	viewport.AnchorPoint = placeholder.AnchorPoint
	viewport.Position = placeholder.Position
	viewport.Size = placeholder.Size
	viewport.SizeConstraint = placeholder.SizeConstraint
	viewport.Rotation = placeholder.Rotation
	viewport.ZIndex = placeholder.ZIndex
	viewport.LayoutOrder = placeholder.LayoutOrder
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	for _, child in placeholder:GetChildren() do
		if child:IsA("UIAspectRatioConstraint") then
			child:Clone().Parent = viewport
		end
	end
	viewport.Parent = placeholder.Parent
	return viewport
end

-- // Fills `placeholder`'s spot with a render of `modelName` (a Shared/Assets/Tools model), else with `image` (asset id
-- // or full
-- // image string), else hides both.
function ItemViewport.setDisplay(placeholder: ImageLabel, image: (string | number)?, modelName: string?)
	if modelName then
		placeholder.Visible = false
		local viewport = ItemViewport.getOrCreate(placeholder)
		viewport.Visible = true
		ItemViewport.renderTool(viewport, modelName)
		return
	end

	-- // Only looks up an existing viewport; none is created without a model
	local existing = placeholder.Parent and placeholder.Parent:FindFirstChild(`{placeholder.Name}Viewport`)
	if existing and existing:IsA("ViewportFrame") then
		existing.Visible = false
	end

	if type(image) == "number" then
		placeholder.Image = `rbxassetid://{image}`
	elseif type(image) == "string" and image ~= "" then
		placeholder.Image = image
	else
		placeholder.Visible = false
		return
	end
	placeholder.ScaleType = Enum.ScaleType.Fit
	placeholder.Visible = true
end

-- // Loops the animation on the model's Animator
local function playLooped(model: Model, animationId: string | number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn(`ItemViewport: {EMOTES_RIG_NAME} has no Humanoid/Animator`)
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{animationId}`
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()
end

-- // Shows a copy of the EmotesRig looping the animation. Returns the copy, or nil if the rig is missing.
-- // The rig must be inside a WorldModel, and the viewport must be in the game before the animation loads, so playback
-- // starts
-- // once the viewport is parented. Stops when the viewport's content is replaced or cleared.
function ItemViewport.renderEmote(viewport: ViewportFrame, animationId: string | number): Model?
	local rig = ReplicatedStorage:FindFirstChild(EMOTES_RIG_NAME) or ReplicatedStorage:WaitForChild(EMOTES_RIG_NAME, 5)
	if not (rig and rig:IsA("Model")) then
		warn(`ItemViewport: {EMOTES_RIG_NAME} not found in ReplicatedStorage`)
		clear(viewport)
		return nil
	end

	clear(viewport)

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local model = rig:Clone()
	model:PivotTo(EMOTES_RIG_ROTATION)
	model.Parent = worldModel

	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	camera.CFrame = getFittingCameraCFrame(model, EMOTES_RIG_ZOOM)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	if viewport:IsDescendantOf(game) then
		playLooped(model, animationId)
	else
		local connection: RBXScriptConnection
		connection = viewport.AncestryChanged:Connect(function()
			if not viewport:IsDescendantOf(game) then
				return
			end
			connection:Disconnect()
			if model:IsDescendantOf(viewport) then
				playLooped(model, animationId)
			end
		end)
		-- // Content was replaced or the viewport destroyed before joining the game
		model.Destroying:Once(function()
			connection:Disconnect()
		end)
	end

	return model
end

function ItemViewport.clear(viewport: ViewportFrame)
	clear(viewport)
end

local IMAGE_PLACEHOLDER_NAME = "ImagePlaceholder"

-- // For non-model items (charge up effects): fills the viewport with an ImageLabel of `image` (asset id), or a label
-- // showing
-- // `glyph` while there is no art. Pass nothing to remove it.
-- // IMAGE PLACEHOLDER: set the item's Icon (e.g. ChargeUpEffects.Icon) once its image exists.
function ItemViewport.setImagePlaceholder(viewport: ViewportFrame, image: number?, glyph: string?, label: string?)
	local existing = viewport:FindFirstChild(IMAGE_PLACEHOLDER_NAME)
	if image == nil and glyph == nil then
		if existing then
			existing:Destroy()
		end
		return
	end

	clear(viewport)
	local imageLabel = existing
	if not imageLabel then
		imageLabel = Instance.new("ImageLabel")
		imageLabel.Name = IMAGE_PLACEHOLDER_NAME
		imageLabel.BackgroundTransparency = 1
		imageLabel.Size = UDim2.fromScale(1, 1)
		imageLabel.ScaleType = Enum.ScaleType.Fit
		imageLabel.ZIndex = viewport.ZIndex + 1
		imageLabel.Parent = viewport

		local text = Instance.new("TextLabel")
		text.Name = "Glyph"
		text.BackgroundTransparency = 1
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Position = UDim2.fromScale(0.5, 0.5)
		text.Size = UDim2.fromScale(0.8, 0.8)
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.new(1, 1, 1)
		text.ZIndex = imageLabel.ZIndex
		text.Parent = imageLabel
	end

	imageLabel.Image = if image then `rbxassetid://{image}` else ""
	imageLabel.Glyph.Text = if image then "" else (glyph or "?")
	imageLabel.Glyph.Visible = image == nil
end

return ItemViewport
