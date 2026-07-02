local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local function createCollisionGroup(groupName: string, collidesWith: {string})
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

local SetupData = {
   Players = createCollisionGroup("Players", {"ArenaObstructions"}),
   ThrownWeapons = createCollisionGroup("ThrownWeapons", {"ArenaObstructions", "Players"}),
   HandWeapons = createCollisionGroup("HandWeapons", {"Players"}),
   ArenaObstructions = createCollisionGroup("ArenaObstructions", {"Players", "ThrownWeapons"})
}

local CollisionGroups = {
   Players = deepRegisterCollisionGroups(SetupData.Players),
   ThrownWeapons = deepRegisterCollisionGroups(SetupData.ThrownWeapons),
   HandWeapons = deepRegisterCollisionGroups(SetupData.HandWeapons),
   ArenaObstructions = deepRegisterCollisionGroups(SetupData.ArenaObstructions)
}

return CollisionGroups