local DynamicCollisionLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)

type DynamicCollisionData = {
   PreviousTransform: CFrame,
   CurrentTransform: CFrame,
   PreviousTime: number,
   CurrentTime: number,
}

local registeredObjects: {[Instance]: DynamicCollisionData} = {}

function DynamicCollisionLibrary.register(object: BasePart, transform: CFrame?, timestamp: number?): boolean
   if not object:IsA("BasePart") then
      return false
   end

   local initialTransform = transform or object:GetPivot()
   local initialTime = timestamp or workspace:GetServerTimeNow()
   registeredObjects[object] = {
      PreviousTransform = initialTransform,
      CurrentTransform = initialTransform,
      PreviousTime = initialTime,
      CurrentTime = initialTime,
   }
   return true
end

function DynamicCollisionLibrary.unregister(object: Instance)
   registeredObjects[object] = nil
end

function DynamicCollisionLibrary.capturePreviousTransform(object: BasePart, timestamp: number?)
   local data = registeredObjects[object]
   if not data then
      DynamicCollisionLibrary.register(object, object:GetPivot(), timestamp)
      return
   end

   data.PreviousTransform = data.CurrentTransform
   data.PreviousTime = data.CurrentTime
end

function DynamicCollisionLibrary.recordCurrentTransform(object: BasePart, transform: CFrame?, timestamp: number?)
   local data = registeredObjects[object]
   if not data then
      DynamicCollisionLibrary.register(object, transform, timestamp)
      return
   end

   data.CurrentTransform = transform or object:GetPivot()
   data.CurrentTime = timestamp or workspace:GetServerTimeNow()
end

local function findRegisteredObject(object: Instance): DynamicCollisionData?
   local currentObject: Instance? = object
   while currentObject do
      local data = registeredObjects[currentObject]
      if data then
         return data
      end
      currentObject = currentObject.Parent
   end
   return nil
end

function DynamicCollisionLibrary.getPointVelocity(
	object: Instance,
	worldPosition: Vector3
): Vector3?
	local data = findRegisteredObject(object)
	if not data then
		return nil
	end

	local dt = data.CurrentTime - data.PreviousTime
	if dt <= 1e-5 then
		return Vector3.zero
	end

	-- Keep the point fixed in the platform's local space
	-- at the previous transform.
	local localPosition = data.PreviousTransform:PointToObjectSpace(worldPosition)

	local previousWorldPosition =
		data.PreviousTransform:PointToWorldSpace(localPosition)

	local currentWorldPosition =
		data.CurrentTransform:PointToWorldSpace(localPosition)

	return (currentWorldPosition - previousWorldPosition) / dt
end

function DynamicCollisionLibrary.getOverlappingVelocity(position: Vector3, radius: number): Vector3?
   if radius <= 0 then
      return nil
   end
   radius*= 3

   local overlapParams = OverlapParams.new()
   overlapParams.CollisionGroup = CollisionGroupConstants.ThrownWeapons
   local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams)
   local closestDistance = math.huge
   local overlappingVelocity = nil
   for _, part in parts do
      local data = findRegisteredObject(part)
      if not data then
         continue
      end

      local distance = (part.Position - position).Magnitude
      if distance >= closestDistance then
         continue
      end

      local velocity = DynamicCollisionLibrary.getPointVelocity(part, position)
      if velocity then
         closestDistance = distance
         overlappingVelocity = velocity
      end
   end

   return overlappingVelocity
end


return DynamicCollisionLibrary