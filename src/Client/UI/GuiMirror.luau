--[[
	GuiMirror

	Description:
	Mirrors a GuiObject horizontally within its parent (left-handed touch layout) by flipping Position X and
	AnchorPoint X. Original values are stored, so un-mirroring restores them exactly. If something else moves the
	object while mirrored (e.g. Roblox re-laying out touch controls), call setMirrored again to take the new position
	as the original.
]]

local GuiMirror = {}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

type MirrorState = {
	OriginalPosition: UDim2,
	OriginalAnchorPoint: Vector2,
	MirroredPosition: UDim2,
	MirroredAnchorPoint: Vector2,
}

local states: { [GuiObject]: MirrorState } = setmetatable({}, { __mode = "k" }) :: any

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Whether the object is currently shown mirrored (and not moved since)
function GuiMirror.isMirrored(guiObject: GuiObject): boolean
	local state = states[guiObject]
	return state ~= nil and guiObject.Position == state.MirroredPosition and guiObject.AnchorPoint == state.MirroredAnchorPoint
end

function GuiMirror.setMirrored(guiObject: GuiObject, mirrored: boolean)
	local state = states[guiObject]
	local isShownMirrored = GuiMirror.isMirrored(guiObject)
	if mirrored == isShownMirrored then
		return
	end
	if mirrored then
		-- // Current values become the originals
		local position, anchorPoint = guiObject.Position, guiObject.AnchorPoint
		if state and anchorPoint == state.MirroredAnchorPoint then
			anchorPoint = state.OriginalAnchorPoint -- // Only Position changed; the anchor is still the mirrored one
		end
		state = {
			OriginalPosition = position,
			OriginalAnchorPoint = anchorPoint,
			MirroredPosition = UDim2.new(1 - position.X.Scale, -position.X.Offset, position.Y.Scale, position.Y.Offset),
			MirroredAnchorPoint = Vector2.new(1 - anchorPoint.X, anchorPoint.Y),
		}
		states[guiObject] = state
		guiObject.AnchorPoint = state.MirroredAnchorPoint
		guiObject.Position = state.MirroredPosition
	elseif state then
		guiObject.AnchorPoint = state.OriginalAnchorPoint
		guiObject.Position = state.OriginalPosition
		states[guiObject] = nil
	end
end

return GuiMirror
