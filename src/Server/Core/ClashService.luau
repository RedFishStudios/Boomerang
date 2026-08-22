
--[[

   Manages weapon clashes
   A weapon clash occurs when two weapons collide in the air

]]

local ClashService = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local WeaponService = require(ServerStorage.Server.Core.WeaponService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local WEAPON_OVERLAP_RADIUS = 2
local WEAPON_OVERLAP_RADIUS_SQUARED = WEAPON_OVERLAP_RADIUS ^ 2

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local lastClashes: {[Player]: {[Player]: number}} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function weaponMovementsOverlap(
   previousA: Vector3,
   currentA: Vector3,
   previousB: Vector3,
   currentB: Vector3
): boolean
   if math.max(previousA.X, currentA.X) + WEAPON_OVERLAP_RADIUS < math.min(previousB.X, currentB.X)
      or math.max(previousB.X, currentB.X) + WEAPON_OVERLAP_RADIUS < math.min(previousA.X, currentA.X)
      or math.max(previousA.Z, currentA.Z) + WEAPON_OVERLAP_RADIUS < math.min(previousB.Z, currentB.Z)
      or math.max(previousB.Z, currentB.Z) + WEAPON_OVERLAP_RADIUS < math.min(previousA.Z, currentA.Z)
   then
      return false
   end

   local relativeStartX = previousA.X - previousB.X
   local relativeStartZ = previousA.Z - previousB.Z
   local relativeMovementX = (currentA.X - previousA.X) - (currentB.X - previousB.X)
   local relativeMovementZ = (currentA.Z - previousA.Z) - (currentB.Z - previousB.Z)
   local relativeMovementLengthSquared = relativeMovementX ^ 2 + relativeMovementZ ^ 2
   local closestTime = 0
   if relativeMovementLengthSquared > 0 then
      closestTime = math.clamp(
         -(relativeStartX * relativeMovementX + relativeStartZ * relativeMovementZ) / relativeMovementLengthSquared,
         0,
         1
      )
   end

   local closestX = relativeStartX + relativeMovementX * closestTime
   local closestZ = relativeStartZ + relativeMovementZ * closestTime
   return closestX ^ 2 + closestZ ^ 2 <= WEAPON_OVERLAP_RADIUS_SQUARED
end

local function clearAllClashRecords(player: Player)
   lastClashes[player] = {}
   for otherPlayer, _ in pairs(lastClashes) do
      if lastClashes[otherPlayer] then
         lastClashes[otherPlayer][player] = nil
      end
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ClashService.init()
      -- // Clash logic
   RunService.Heartbeat:Connect(function()
      local fullChecked: {[Player]: boolean} = {}
      local thrownWeapons = ThrownWeapons.Data
      for playerA, weaponA in pairs(thrownWeapons) do
         local cframeA = weaponA.CFrame
         if not cframeA then
            continue
         end
         local currentPositionA = cframeA.Position
         local previousPositionA = weaponA.LastPosition or currentPositionA

         for playerB, weaponB in pairs(thrownWeapons) do
            if playerA == playerB or fullChecked[playerB] then
               continue
            end
            local cframeB = weaponB.CFrame
            if not cframeB then
               continue
            end
            local currentPositionB = cframeB.Position
            local previousPositionB = weaponB.LastPosition or currentPositionB

            if weaponMovementsOverlap(previousPositionA, currentPositionA, previousPositionB, currentPositionB) then
               local Part = Instance.new("Part")
               Part.Position = currentPositionA
               Part.Parent = game.Workspace
               Part.Color = Color3.new(1, 0, 0)
               Part.Size = Vector3.new(1, 1, 1)
               local PartB = Instance.new("Part")
               PartB.Position = currentPositionB
               PartB.Parent = game.Workspace
               PartB.Color = Color3.new(1, 0, 0)
               PartB.Size = Vector3.new(1, 1, 1)
            end
         end
         fullChecked[playerA] = true
      end
   end)

   -- // Clear all clash records
   PlayersUtil.PlayerRemoving:Connect(function(player)
      clearAllClashRecords(player)
   end)
   WeaponService.WeaponReturnedTasks:Add(function(player: Player)
      clearAllClashRecords(player)
   end)
end

return ClashService