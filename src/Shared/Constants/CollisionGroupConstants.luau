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
      PhysicsService:CollisionGroupSetCollidable(groupA, "Default", false)
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
   Players = collisionGroupData("Players", {"ArenaWalls", "ArenaFloor", "Default"}),
   ThrownWeapons = collisionGroupData("ThrownWeapons", {"ArenaWalls", "ThrownWeapons", "Players"}),
   HandWeapons = collisionGroupData("HandWeapons", {"Players"}),
   ArenaWalls = collisionGroupData("ArenaWalls", {"Players", "ThrownWeapons"}),
   Fire = collisionGroupData("Fire", {"Players"}),
   ArenaFloor = collisionGroupData("ArenaFloor", {"Camera"}),
   ArenaFloorDetector = collisionGroupData("ArenaFloorDetector", {"ArenaFloor"}),
   Camera = collisionGroupData("Camera", {"ArenaFloor"}),
   WaterParts = collisionGroupData("WaterParts", {"Players", "WaterDetector"}),
   WaterDetector = collisionGroupData("WaterDetector", {"WaterParts"}),
   LobbyVolume = collisionGroupData("LobbyVolume", {"LobbyVolume"}),
}

configureCollisionMatrix(SetupData)

local CollisionGroups = {
   Players = deepRegisterCollisionGroups(SetupData.Players),
   ThrownWeapons = deepRegisterCollisionGroups(SetupData.ThrownWeapons),
   HandWeapons = deepRegisterCollisionGroups(SetupData.HandWeapons),
   ArenaWalls = deepRegisterCollisionGroups(SetupData.ArenaWalls),
   ArenaFloor = deepRegisterCollisionGroups(SetupData.ArenaFloor),
   ArenaFloorDetector = deepRegisterCollisionGroups(SetupData.ArenaFloorDetector),
   Camera = deepRegisterCollisionGroups(SetupData.Camera),
   WaterParts = deepRegisterCollisionGroups(SetupData.WaterParts),
   WaterDetector = deepRegisterCollisionGroups(SetupData.WaterDetector),
   Fire = deepRegisterCollisionGroups(SetupData.Fire),
   LobbyVolume = deepRegisterCollisionGroups(SetupData.LobbyVolume),
}

return CollisionGroups