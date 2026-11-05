local UIUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage.Shared.Constants.Icons)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type GuiImage = ImageButton | ImageLabel
export type Input = Enum.UserInputType | Enum.KeyCode | nil

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-- // The listing card art has transparent margins around the card itself; this is the share of the image the card fills
local LISTING_CARD_VISIBLE_SCALE = Vector2.new(0.945, 0.563)

local tweenInfoIn = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenInfoOut = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local actualSizesCache: { [GuiObject]: UDim2 } = {}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function UIUtil.frameAnimateIn(frame: Frame, customTweenInfo: TweenInfo?)
	local tweenInfo = customTweenInfo or tweenInfoIn

	if not actualSizesCache[frame] then
		actualSizesCache[frame] = frame.Size
	end

	frame.Size = UDim2.fromScale(0, 0)
	local tween = TweenService:Create(frame, tweenInfo, { Size = actualSizesCache[frame] })
	tween:Play()
	tween.Completed:Wait()
end

function UIUtil.frameAnimateOut(frame: Frame, customTweenInfo: TweenInfo?)
	local tweenInfo = customTweenInfo or tweenInfoOut

	local tween = TweenService:Create(frame, tweenInfo, { Size = UDim2.fromScale(0, 0) })
	tween:Play()
	tween.Completed:Wait()
end

function UIUtil.templatify<T>(guiObject: T)
	local parent = guiObject.Parent
	guiObject.Parent = nil

	return function()
		local clone = guiObject:Clone() :: T
		clone.Parent = parent
		return clone
	end
end

function UIUtil.getAnchorDirection(object: GuiObject)
	local position = object.Position
	local scale = Vector2.new(position.X.Scale, position.Y.Scale)
	local difference = scale - object.AnchorPoint
	local length = difference.Magnitude

	return if length > 0 then difference / length else Vector2.zero
end

function UIUtil.bulkTweenCreate(instance: GuiObject, tweens: { { TweenInfo: TweenInfo, PropertyTable: { [string]: any } } }): ...Tween
	local createdTweens = {}
	for _, v in next, tweens do
		table.insert(createdTweens, TweenService:Create(instance, v.TweenInfo, v.PropertyTable))
	end
	return unpack(createdTweens)
end

-- // Card art for a listing (a quest, a setting row): parent it to a transparent frame and the visible card fills that
-- // frame. The art is grayscale, so color is a tint: it can only darken, and it reads a little darker than the tint.
function UIUtil.createListingCardArt(color: Color3): ImageLabel
	local art = Instance.new("ImageLabel")
	art.Name = "CardArt"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(1 / LISTING_CARD_VISIBLE_SCALE.X, 1 / LISTING_CARD_VISIBLE_SCALE.Y)
	art.BackgroundTransparency = 1
	art.Image = `rbxassetid://{Icons.MenuListingCard}`
	art.ImageColor3 = color
	art.ZIndex = 0
	return art
end

return UIUtil
