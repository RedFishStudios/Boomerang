local UIUtil = {}

local TweenService = game:GetService("TweenService")

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type GuiImage = ImageButton | ImageLabel
export type Input = Enum.UserInputType | Enum.KeyCode | nil

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

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

return UIUtil
