local CharacterLogic = {}

--local PITCH_MIN = math.rad(-80)
--local PITCH_MAX = math.rad(80)

local function wrapRadians(angle: number): number
	return ((angle + math.pi) % (2 * math.pi)) - math.pi
end

function CharacterLogic.getYawFromLookAt(origin: Vector3, lookAt: Vector3): number
	local delta = lookAt - origin
	if delta.Magnitude <= 1e-5 then
		return 0
	end

	return math.atan2(-delta.X, -delta.Z)
end

--function CharacterLogic.getYawPitchFromLookAt(origin: Vector3, lookAt: Vector3): (number, number)
--	local delta = lookAt - origin
--	if delta.Magnitude <= 1e-5 then
--		return 0, 0
--	end
--
--	local yaw = math.atan2(-delta.X, -delta.Z)
--	local pitch = math.atan2(delta.Y, Vector2.new(delta.X, delta.Z).Magnitude)
--	return yaw, pitch
--end
--
--function CharacterLogic.getLookVectorFromYawPitch(yaw: number, pitch: number): Vector3
--	return CFrame.fromOrientation(pitch, yaw, 0).LookVector
--end

function CharacterLogic.getLookVectorFromYaw(yaw: number): Vector3
	return CFrame.Angles(0, yaw, 0).LookVector
end

function CharacterLogic.getShortestAngleDelta(fromAngle: number, toAngle: number): number
	return wrapRadians(toAngle - fromAngle)
end

function CharacterLogic.lerpAngle(fromAngle: number, toAngle: number, alpha: number): number
	return wrapRadians(fromAngle + CharacterLogic.getShortestAngleDelta(fromAngle, toAngle) * alpha)
end

function CharacterLogic.quantizeYaw(yaw: number): number
	return math.round(math.map(wrapRadians(yaw), -math.pi, math.pi, 0, 65535))
end

function CharacterLogic.dequantizeYaw(value: number): number
	return wrapRadians(math.map(value, 0, 65535, -math.pi, math.pi))
end

--function CharacterLogic.quantizePitch(pitch: number): number
--	local clamped = math.clamp(pitch, PITCH_MIN, PITCH_MAX)
--	return math.round(math.map(clamped, PITCH_MIN, PITCH_MAX, 0, 65535))
--end
--
--function CharacterLogic.dequantizePitch(value: number): number
--	return math.map(value, 0, 65535, PITCH_MIN, PITCH_MAX)
--end

return CharacterLogic
