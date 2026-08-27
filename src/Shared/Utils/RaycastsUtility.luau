local RaycastsUtility = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

function RaycastsUtility.getProjectileObstructionParams(filterDescendantsInstances: { Instance }): RaycastParams
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = filterDescendantsInstances
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	return raycastParams
end

function RaycastsUtility.raycastProjectileObstruction(
	origin: Vector3,
	direction: Vector3,
	distance: number,
	raycastParams: RaycastParams
)
	local directionMagnitude = direction.Magnitude
	if distance <= 0 or directionMagnitude <= 1e-6 then
		return nil
	end

	local directionUnit = direction / directionMagnitude
	local currentOrigin = origin
	local remainingDistance = distance
	local epsilon = 1e-3
	local maxIterations = 32

	for _ = 1, maxIterations do
		if remainingDistance <= 0 then
			return nil
		end

		local result = workspace:Raycast(currentOrigin, directionUnit * remainingDistance, raycastParams)
		if not result then
			return nil
		end

		if result.Instance.CanCollide then
			return result
		end

		local filter = raycastParams.FilterDescendantsInstances
		local nextFilter = table.create(#filter + 1)
		for i, instance in ipairs(filter) do
			nextFilter[i] = instance
		end
		nextFilter[#nextFilter + 1] = result.Instance
		raycastParams.FilterDescendantsInstances = nextFilter

		local travelled = (result.Position - currentOrigin).Magnitude + epsilon
		remainingDistance -= travelled
		currentOrigin = result.Position + directionUnit * epsilon
	end

	return nil
end

-- // Sweeps a volume for the first collidable obstruction, passing through non-collidable geometry
function RaycastsUtility.blockcastProjectileObstruction(
	origin: CFrame,
	size: Vector3,
	direction: Vector3,
	distance: number,
	raycastParams: RaycastParams
)
	local directionMagnitude = direction.Magnitude
	if distance <= 0 or directionMagnitude <= 1e-6 then
		return nil
	end

	local directionUnit = direction / directionMagnitude
	local currentOrigin = origin
	local remainingDistance = distance
	local epsilon = 1e-3
	local maxIterations = 32

	for _ = 1, maxIterations do
		if remainingDistance <= 0 then
			return nil
		end

		local result = workspace:Blockcast(currentOrigin, size, directionUnit * remainingDistance, raycastParams)
		if not result then
			return nil
		end

		if result.Instance.CanCollide then
			return result
		end

		local filter = raycastParams.FilterDescendantsInstances
		local nextFilter = table.create(#filter + 1)
		for i, instance in ipairs(filter) do
			nextFilter[i] = instance
		end
		nextFilter[#nextFilter + 1] = result.Instance
		raycastParams.FilterDescendantsInstances = nextFilter

		local travelled = result.Distance + epsilon
		remainingDistance -= travelled
		currentOrigin = currentOrigin + directionUnit * travelled
	end

	return nil
end

function RaycastsUtility.getMouseWorldPosition(maxDistance: number?, raycastParams: RaycastParams?, position: Vector2?): Vector3?
	if not RunService:IsClient() then
		return nil
	end

	local camera = workspace.CurrentCamera
	local localPlayer = Players.LocalPlayer
	if not camera or not localPlayer then
		return nil
	end

	local mouseLocation = position or UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local distance = maxDistance or 2048

	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * distance, raycastParams)
	if raycastResult then
		return raycastResult.Position
	end

	return unitRay.Origin + unitRay.Direction * distance
end

return RaycastsUtility