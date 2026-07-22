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
	return workspace:Raycast(origin, direction * distance, raycastParams)
end

function RaycastsUtility.getMouseWorldPosition(maxDistance: number?, raycastParams: RaycastParams?): Vector3?
	if not RunService:IsClient() then
		return nil
	end

	local camera = workspace.CurrentCamera
	local localPlayer = Players.LocalPlayer
	if not camera or not localPlayer then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local distance = maxDistance or 2048

	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * distance, raycastParams)
	if raycastResult then
		return raycastResult.Position
	end

	return unitRay.Origin + unitRay.Direction * distance
end

return RaycastsUtility