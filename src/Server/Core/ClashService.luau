
--[[

   Manages weapon clashes
   A weapon clash occurs when two weapons collide in the air

]]

local ClashService = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local WeaponService = require(ServerStorage.Server.Core.WeaponService)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local WEAPON_OVERLAP_RADIUS = 4
local WEAPON_OVERLAP_RADIUS_SQUARED = WEAPON_OVERLAP_RADIUS ^ 2
local CLASH_COOLDOWN = 1

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

local function getWeaponMovementCollisionPoint(
   previousA: Vector3,
   currentA: Vector3,
   previousB: Vector3,
   currentB: Vector3
): Vector3?
   if math.max(previousA.X, currentA.X) + WEAPON_OVERLAP_RADIUS < math.min(previousB.X, currentB.X)
      or math.max(previousB.X, currentB.X) + WEAPON_OVERLAP_RADIUS < math.min(previousA.X, currentA.X)
      or math.max(previousA.Z, currentA.Z) + WEAPON_OVERLAP_RADIUS < math.min(previousB.Z, currentB.Z)
      or math.max(previousB.Z, currentB.Z) + WEAPON_OVERLAP_RADIUS < math.min(previousA.Z, currentA.Z)
   then
      return nil
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
   if closestX ^ 2 + closestZ ^ 2 > WEAPON_OVERLAP_RADIUS_SQUARED then
      return nil
   end

   local positionA = previousA:Lerp(currentA, closestTime)
   local positionB = previousB:Lerp(currentB, closestTime)
   return (positionA + positionB) * 0.5
end

local function getClashDirections(
   previousA: Vector3,
   currentA: Vector3,
   previousB: Vector3,
   currentB: Vector3
): (Vector3, Vector3)
   local separation = Vector3.new(currentA.X - currentB.X, 0, currentA.Z - currentB.Z)
   if separation.Magnitude <= 1e-5 then
      local relativeMovement = (currentA - previousA) - (currentB - previousB)
      separation = Vector3.new(-relativeMovement.X, 0, -relativeMovement.Z)
   end
   if separation.Magnitude <= 1e-5 then
      separation = Vector3.xAxis
   end

   local directionA = separation.Unit
   return directionA, -directionA
end

local function clearAllClashRecords(player: Player)
   lastClashes[player] = {}
   for otherPlayer, _ in pairs(lastClashes) do
      if lastClashes[otherPlayer] then
         lastClashes[otherPlayer][player] = nil
      end
   end
end

local function registerClashRecord(playerA: Player, playerB: Player)
   local now = workspace:GetServerTimeNow()
   if not lastClashes[playerA] then
      lastClashes[playerA] = {}
   end
   lastClashes[playerA][playerB] = now
   if not lastClashes[playerB] then
      lastClashes[playerB] = {}
   end
   lastClashes[playerB][playerA] = now
end

local function hasClashRecord(playerA: Player, playerB: Player): boolean
   local now = workspace:GetServerTimeNow()
   if lastClashes[playerA] and lastClashes[playerA][playerB] then
      local lastClashTime = lastClashes[playerA][playerB]
      if now - lastClashTime < CLASH_COOLDOWN then
         return true
      end
   end
   if lastClashes[playerB] and lastClashes[playerB][playerA] then
      local lastClashTime = lastClashes[playerB][playerA]
      if now - lastClashTime < CLASH_COOLDOWN then
         return true
      end
   end
   return false
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
         if weaponA.State == ThrownWeapons.StateEnum.Clashed or weaponA.State == ThrownWeapons.StateEnum.Dead then
            continue
         end
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
            if weaponB.State == ThrownWeapons.StateEnum.Clashed or weaponB.State == ThrownWeapons.StateEnum.Dead then
               continue
            end
            if hasClashRecord(playerA, playerB) then
               continue
            end
            local cframeB = weaponB.CFrame
            if not cframeB then
               continue
            end
            local currentPositionB = cframeB.Position
            local previousPositionB = weaponB.LastPosition or currentPositionB

            local collisionPoint = getWeaponMovementCollisionPoint(previousPositionA, currentPositionA, previousPositionB, currentPositionB)
            if collisionPoint then
               registerClashRecord(playerA, playerB)
               local directionA, directionB = getClashDirections(
                  previousPositionA,
                  currentPositionA,
                  previousPositionB,
                  currentPositionB
               )
               WeaponService.clashWeapon(playerA, weaponA, directionA, collisionPoint)
               WeaponService.clashWeapon(playerB, weaponB, directionB, collisionPoint)

               SoundLibrary.stop(weaponA.InstanceId)
               SoundLibrary.stop(weaponB.InstanceId)
               SoundLibrary.play(`{weaponA.InstanceId}-{weaponB.InstanceId}-Clash`, Sounds.Data.BoomerangClash.Name, collisionPoint)
               break
            end
         end
         fullChecked[playerA] = true
      end
   end)

   -- // Clear all clash records
   PlayersUtil.PlayerRemoving:Add(function(player)
      clearAllClashRecords(player)
   end)
   SharedTasks.WeaponReturnedTasks:Add(function(player: Player)
      clearAllClashRecords(player)
   end)
end

return ClashService