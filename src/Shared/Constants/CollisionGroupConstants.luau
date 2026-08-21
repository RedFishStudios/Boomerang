local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local function collisionGroupData(groupName: string, collidesWith: {string})
   if RunService:IsServer() then
      PhysicsService:RegisterCollisionGroup(groupName)
   end
   return {
      Name = groupName,
      CollidesWith = collidesWith
   }
end

local function deepRegisterCollisionGroups(setupData): string
   if RunService:IsServer() then
      for _, otherGroupName in ipairs(setupData.CollidesWith) do
         PhysicsService:CollisionGroupSetCollidable(setupData.Name, otherGroupName, true)
      end
   end
   return setupData.Name
end

local function configureCollisionMatrix(setupDataByGroup)
   if not RunService:IsServer() then
      return
   end

   local groupNames = {}
   for groupName in pairs(setupDataByGroup) do
      table.insert(groupNames, groupName)
   end

   -- Start from a fully non-collidable matrix, then opt in explicit relationships.
   for _, groupA in ipairs(groupNames) do
      for _, groupB in ipairs(groupNames) do
         PhysicsService:CollisionGroupSetCollidable(groupA, groupB, false)
      end
   end

   for _, setupData in pairs(setupDataByGroup) do
      for _, otherGroupName in ipairs(setupData.CollidesWith) do
         PhysicsService:CollisionGroupSetCollidable(setupData.Name, otherGroupName, true)
      end
   end
end

local SetupData = {
   Players = collisionGroupData("Players", {"ArenaWalls"}),
   ThrownWeapons = collisionGroupData("ThrownWeapons", {"ArenaWalls", "Players"}),
   HandWeapons = collisionGroupData("HandWeapons", {"Players"}),
   ArenaWalls = collisionGroupData("ArenaWalls", {"Players", "ThrownWeapons"}),
   Fire = collisionGroupData("Fire", {"Players"}),
   ArenaFloor = collisionGroupData("ArenaFloor", {"Camera"}),
   Camera = collisionGroupData("Camera", {"ArenaFloor"}),
   WaterParts = collisionGroupData("WaterParts", {"Players", "WaterDetector"}),
   WaterDetector = collisionGroupData("WaterDetector", {"WaterParts"}),
}

configureCollisionMatrix(SetupData)

local CollisionGroups = {
   Players = deepRegisterCollisionGroups(SetupData.Players),
   ThrownWeapons = deepRegisterCollisionGroups(SetupData.ThrownWeapons),
   HandWeapons = deepRegisterCollisionGroups(SetupData.HandWeapons),
   ArenaWalls = deepRegisterCollisionGroups(SetupData.ArenaWalls),
   ArenaFloor = deepRegisterCollisionGroups(SetupData.ArenaFloor),
   Camera = deepRegisterCollisionGroups(SetupData.Camera),
   WaterParts = deepRegisterCollisionGroups(SetupData.WaterParts),
   WaterDetector = deepRegisterCollisionGroups(SetupData.WaterDetector),
   Fire = deepRegisterCollisionGroups(SetupData.Fire),
}

return CollisionGroups