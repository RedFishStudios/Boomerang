--[[
	ItemViewport

	Description:
	Shows a model in a ViewportFrame, posed and framed so it fits entirely inside a square render.
	For any GUI that displays items (Inventory, and later the Shop, Daily Claims...).
	- renderTool: a weapon/skin model from Shared/Assets/Tools (the same model the character holds),
	  posed with its Viewport data in Shared/Constants/Tools.
	- renderModel: any model, with an explicit rotation.
	Give the ViewportFrame a UIAspectRatioConstraint of 1 so the render stays square.
]]

local ItemViewport = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolLibrary = require(ReplicatedStorage.Shared.Library.ToolLibrary)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FIELD_OF_VIEW = 30
local MARGIN = 1.08 -- // Camera distance multiplier: >1 leaves a little space around the model
local DEFAULT_ROTATION = CFrame.Angles(math.rad(75), 0, 0) -- // Flat models (local Y thin) face the camera, tilted a little
local CORNER_SIGNS = {
	Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function clear(viewport: ViewportFrame)
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	viewport.CurrentCamera = nil
end

-- // Camera looking along -Z, close enough that every corner of every part fits in a square view
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

-- // Replaces the viewport's content with a copy of the model, rotated and framed. Returns the copy.
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

-- // Shows a model from Shared/Assets/Tools, posed by Tools[modelName].Viewport. Returns the copy, or nil if not found.
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

function ItemViewport.clear(viewport: ViewportFrame)
	clear(viewport)
end

return ItemViewport
