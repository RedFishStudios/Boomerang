local StormCloseLibrary = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

StormCloseLibrary.REMOTE_EVENT_NAME = "StormClose"
StormCloseLibrary.REMOTE_ACTION_CREATE = "Create"
StormCloseLibrary.REMOTE_ACTION_SHIFT = "Shift"
StormCloseLibrary.REMOTE_ACTION_CLEAR = "Clear"

StormCloseLibrary.WALL_THICKNESS = 0.01
StormCloseLibrary.WALL_HEIGHT = 0.01
StormCloseLibrary.BEAM_HEIGHT = 10
StormCloseLibrary.RECTANGLE_TWEEN_DURATION = 1

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function StormCloseLibrary.getRectangleWallDefinitions(centerPosition: Vector3, width: number, height: number)
	local wallThickness = StormCloseLibrary.WALL_THICKNESS
	local wallHeight = StormCloseLibrary.WALL_HEIGHT

	return {
		Front = {
			size = Vector3.new(width, wallHeight, wallThickness),
			position = centerPosition + Vector3.new(0, wallHeight / 2, -height / 2),
			rotation = Vector3.new(0, 0, 0),
		},
		Back = {
			size = Vector3.new(width, wallHeight, wallThickness),
			position = centerPosition + Vector3.new(0, wallHeight / 2, height / 2),
			rotation = Vector3.new(0, 180, 0),
		},
		Left = {
			size = Vector3.new(height, wallHeight, wallThickness),
			position = centerPosition + Vector3.new(-width / 2, wallHeight / 2, 0),
			rotation = Vector3.new(0, 90, 0),
		},
		Right = {
			size = Vector3.new(height, wallHeight, wallThickness),
			position = centerPosition + Vector3.new(width / 2, wallHeight / 2, 0),
			rotation = Vector3.new(0, -90, 0),
		},
	}
end

function StormCloseLibrary.getRectangleBounds(centerPosition: Vector3, width: number, height: number)
	local halfWidth = width / 2
	local halfHeight = height / 2

	return {
		minX = centerPosition.X - halfWidth,
		maxX = centerPosition.X + halfWidth,
		minZ = centerPosition.Z - halfHeight,
		maxZ = centerPosition.Z + halfHeight,
	}
end

function StormCloseLibrary.isPointInsideRectangle(point: Vector3, centerPosition: Vector3, width: number, height: number): boolean
	local bounds = StormCloseLibrary.getRectangleBounds(centerPosition, width, height)
	return point.X >= bounds.minX and point.X <= bounds.maxX and point.Z >= bounds.minZ and point.Z <= bounds.maxZ
end

function StormCloseLibrary.getTweenAlpha(startTime: number, duration: number, now: number): number
	if duration <= 0 then
		return 1
	end

	return math.clamp((now - startTime) / duration, 0, 1)
end

function StormCloseLibrary.lerpDimensions(startWidth: number, startHeight: number, targetWidth: number, targetHeight: number, alpha: number): (number, number)
	return startWidth + ((targetWidth - startWidth) * alpha), startHeight + ((targetHeight - startHeight) * alpha)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function StormCloseLibrary.init()
end

function StormCloseLibrary.start()
end

return StormCloseLibrary