local RaycastsUtility = {}

function RaycastsUtility.getProjectileObstructionParams(filterDescendantsInstances: { Instance }): RaycastParams
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = filterDescendantsInstances
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	return raycastParams
end

function RaycastsUtility.RaycastProjectileObstruction(
	origin: Vector3,
	direction: Vector3,
	distance: number,
	raycastParams: RaycastParams
)
	return workspace:Raycast(origin, direction * distance, raycastParams)
end

return RaycastsUtility
