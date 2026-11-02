--[[
	GuiMirror

	Description:
	Flips a GuiObject to the other side of its parent horizontally (for the left-handed touch layout): its Position's X
	and AnchorPoint's X are mirrored, so it sits the same distance from the opposite edge. The original values are
	remembered, so mirroring twice or un-mirroring always comes back to exactly where it was. If something else moves
	the object while it's mirrored (e.g. Roblox re-laying out its touch controls), call setMirrored again: the new
	position is taken as the new original.
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
		-- // Wherever it is now (not one of our mirrored values) is its original place
		local position, anchorPoint = guiObject.Position, guiObject.AnchorPoint
		if state and anchorPoint == state.MirroredAnchorPoint then
			anchorPoint = state.OriginalAnchorPoint -- // Only its Position was changed since: the anchor is still ours
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
