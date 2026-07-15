local CharacterLogic = {}

local ANIMATION_SPEEDS = table.freeze({
	Root = 8,
})

function CharacterLogic.getYawFromLookAt(origin: Vector3, lookAt: Vector3): number
	local delta = lookAt - origin
	if delta.Magnitude <= 1e-5 then
		return 0
	end

	return math.atan2(-delta.X, -delta.Z)
end

function CharacterLogic.getRootYawCFrame(currentCFrame: CFrame, lookAt: Vector3): CFrame
	local yawAngle = CharacterLogic.getYawFromLookAt(currentCFrame.Position, lookAt)
	return CFrame.Angles(0, yawAngle, 0) + currentCFrame.Position
end

function CharacterLogic.stepRootYaw(currentCFrame: CFrame, lookAt: Vector3, deltaTime: number): CFrame
	local target = CharacterLogic.getRootYawCFrame(currentCFrame, lookAt)
	return currentCFrame:Lerp(target, deltaTime * ANIMATION_SPEEDS.Root)
end

return CharacterLogic
