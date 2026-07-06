-- // Regulates boomerang functionality

local Boomerang = {}

local ReplicatedStorage = game.ReplicatedStorage
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(game.ServerStorage.Server.Referential.ThrownWeapons)
local RoundCyclingService = require(game.ServerStorage.Server.Core.RoundCyclingService)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

local Characters = game.Workspace.Characters
local ThrownWeaponsFolder = game.Workspace.ThrownWeapons
local ThrownWeaponReplicationPart = ReplicatedStorage.Shared.Assets.ThrownWeaponReplication

local RunService = game:GetService("RunService")
local thrownWeaponReplicationRemote = SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication")
local thrownBoomerangSpawnedRemote = SimpleRemotes.getEvent("ThrownBoomerangSpawned")
local thrownBoomerangDespawnedRemote = SimpleRemotes.getEvent("ThrownBoomerangDespawned")

local SLOW_RATE = 5
local UP_VECTOR = Vector3.new(0, 1, 0)

local function createReplicationPayload(ownerUserId: number, position: Vector3): buffer
   local payload = buffer.create(16)
   local offset = 0
   offset = BufferUtil.writeu32(payload, offset, ownerUserId)
   BufferUtil.writeVector3_96(payload, offset, position)
   return payload
end

local function fireDespawned(ownerUserId: number)
   local payload = buffer.create(4)
   BufferUtil.writeu32(payload, 0, ownerUserId)
   -- TODO: fire only for players that are currently in game or spectating? (if lobby is out of sight, they don't need to see this)
   thrownBoomerangDespawnedRemote:FireAllClients(payload)
end

local function replicateIfMoved(ownerUserId: number, replicationPart: BasePart, lastReplicatedPosition: Vector3): Vector3
   local currentPosition = replicationPart.Position
   if currentPosition ~= lastReplicatedPosition then
      local payload = createReplicationPayload(ownerUserId, currentPosition)
      -- TODO: fire only for players that are currently in game or spectating? (if lobby is out of sight, they don't need to see this)
      thrownWeaponReplicationRemote:FireAllClients(payload)
      return currentPosition
   end
   return lastReplicatedPosition
end

local function raycastWithHorizontalHitbox(
   rayOrigin: Vector3,
   direction: Vector3,
   rayDistance: number,
   hitboxRadius: number,
   raycastParams: RaycastParams,
   weaponData: ThrownWeapons.Data
): RaycastResult?
   for i, p in pairs(weaponData.TestRaycastVisualizers) do
      if p and p.Parent then
         p.Color = Color3.new(0.164706, 0.960784, 0.007843)
         p.Transparency = 1
      end
   end
   rayDistance = math.max(rayDistance, hitboxRadius)

   local rightDirection = direction:Cross(UP_VECTOR).Unit
   local leftOrigin = rayOrigin - rightDirection * hitboxRadius
   local rightOrigin = rayOrigin + rightDirection * hitboxRadius

   -- Position all 3 raycast visualizers at the predicted raycast endpoints
   weaponData.TestRaycastVisualizers[1].Position = rayOrigin + direction * rayDistance
   weaponData.TestRaycastVisualizers[2].Position = leftOrigin + direction * rayDistance
   weaponData.TestRaycastVisualizers[3].Position = rightOrigin + direction * rayDistance

   local raycastResult = RaycastsUtility.raycastProjectileObstruction(rayOrigin, direction, rayDistance, raycastParams)
   if raycastResult or hitboxRadius <= 0 then
      weaponData.TestRaycastVisualizers[1].Position = raycastResult.Position
      weaponData.TestRaycastVisualizers[1].Color = Color3.new(1, 0, 0)
      return raycastResult
   end

   raycastResult = RaycastsUtility.raycastProjectileObstruction(leftOrigin, direction, rayDistance, raycastParams)
   if raycastResult then
      weaponData.TestRaycastVisualizers[2].Position = raycastResult.Position
      weaponData.TestRaycastVisualizers[2].Color = Color3.new(1, 0, 0)
      return raycastResult
   end

   local finalResult = RaycastsUtility.raycastProjectileObstruction(rightOrigin, direction, rayDistance, raycastParams)
   if finalResult then
      weaponData.TestRaycastVisualizers[3].Position = finalResult.Position
      weaponData.TestRaycastVisualizers[3].Color = Color3.new(1, 0, 0)
   end
   return finalResult
end

function Boomerang.throw(player: Player, boomerangId: string, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data)
   if not toolData.Boomerang then
      warn(`this is not a boomerang`)
      return
   end
   local character = player.Character
   if not character then
      print(`no character`)
      return
   end

   -- TODO: cast in front of the player to see if they already have a wall obstructing them (ie trying to throw the weapon inside a wall)

   local replicationPart = ThrownWeaponReplicationPart:Clone()
   replicationPart.Name = `BoomerangReplication_{player.Name}`
   local startPosition = character.PrimaryPart.Position + character.PrimaryPart.CFrame.LookVector * 3
   replicationPart.Position = Vector3.new(startPosition.X, GlobalConfig.BoomerangHeight, startPosition.Z)
   replicationPart.Parent = ThrownWeaponsFolder
   thrownBoomerangSpawnedRemote:FireAllClients(player.UserId, replicationPart.Position, boomerangId)
   thrownWeaponData.ReplicationPart = replicationPart
   thrownWeaponData.State = ThrownWeapons.StateEnum.Outgoing

   local direction = character.PrimaryPart.CFrame.LookVector
   direction = Vector3.new(direction.X, 0, direction.Z).Unit
   local speed = toolData.Boomerang.Speed
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local energy = toolData.Boomerang.Bounces
   local lastReplicatedPosition = replicationPart.Position
   local raycastParams = RaycastsUtility.getProjectileObstructionParams({replicationPart}) -- TODO: add throwing player or anyone on the throwing player's team

   thrownWeaponData.MovementConnection = RunService.Stepped:Connect(function(time, deltaTime)
      if not replicationPart or not replicationPart.Parent then
         return
      end

      -- Exhaustion
      if energy <= 0 then
         speed = speed - (speed * SLOW_RATE * deltaTime)
         if speed <= .1 then
            thrownWeaponData.MovementConnection:Disconnect()
            thrownWeaponData.MovementConnection = nil
            return
         end
      end

      -- Raycast in front of the boomerang to detect collisions with walls or other obstacles
      local rayOrigin = replicationPart.Position
      local rayDistance = speed * deltaTime
      local raycastResult = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams, thrownWeaponData)

      -- Result
      if raycastResult then
         local struckObject = raycastResult.Instance
         print(`Boomerang struck {struckObject.Name}`)

         if struckObject:IsDescendantOf(Characters) then
            print('STRUCK A PLAYER')
            if energy > 0 and RoundCyclingService.isInRound() then 
               print(`deal damage`)
            else
               print(`hit player while on exhausted recoil`)
            end
         else
            energy -= 1
            direction = direction - 2 * direction:Dot(raycastResult.Normal) * raycastResult.Normal
            direction = Vector3.new(direction.X, 0, direction.Z).Unit
            if energy == 0 then
               thrownWeaponData.State = ThrownWeapons.StateEnum.Exhausted
            end
            return
         end
      end

      local currentCFrame = replicationPart.CFrame
      replicationPart:PivotTo(currentCFrame + direction * speed * deltaTime)
      lastReplicatedPosition = replicateIfMoved(player.UserId, replicationPart, lastReplicatedPosition)
   end)
end

-- // Restore to player / remove from field
function Boomerang.removeFromField(player: Player, thrownWeaponData: ThrownWeapons.Data)
   if thrownWeaponData.ReplicationPart then
      thrownWeaponData.ReplicationPart:Destroy()
   end
   fireDespawned(player.UserId)
   for _, part in ipairs(ThrownWeapons.Data[player].TestRaycastVisualizers) do
      part:Destroy()
   end
   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end
   ThrownWeapons.Data[player] = nil
end

function Boomerang.recall(player: Player, boomerangId: string, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data)
   if not toolData.Boomerang then
      warn(`this is not a boomerang`)
      return
   end
   local character = player.Character
   if not character then
      print(`no character`)
      return
   end
   local replicationPart = thrownWeaponData.ReplicationPart  
   if not replicationPart or not replicationPart.Parent then
      warn(`no replication part found for thrown tool`)
      return
   end
   if thrownWeaponData.State == ThrownWeapons.StateEnum.Returning then
      print(`already returning`)
      return
   end

   thrownWeaponData.State = ThrownWeapons.StateEnum.Returning
   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end

   local maximumSpeed = toolData.Boomerang.Speed
   local speed = 0
   local slideSpeed = 0
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local lastReplicatedPosition = replicationPart.Position
   local raycastParams = RaycastsUtility.getProjectileObstructionParams({replicationPart, Characters})

   local slideDirection = Vector3.new()
   local slideMomentum = 0 -- momentum carried by the slide

   thrownWeaponData.MovementConnection = RunService.Stepped:Connect(function(_, deltaTime)
      if not replicationPart or not replicationPart.Parent then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
         return
      end

      local rootPart = character and character.PrimaryPart
      if not rootPart then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
         return
      end

      -- // Prioritize movement towards the player
      local toPlayer = (rootPart.Position - replicationPart.Position)
      local distance = toPlayer.Magnitude
      local direction = toPlayer.Unit

      -- // Raycast in that direction for an obstruction
      local rayOrigin = replicationPart.Position
      local rayDistance = (math.max(speed, hitboxRadius)) * deltaTime
      local raycastResult = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams, thrownWeaponData)

      -- // If we hit something, adjust movement direction to move perpendicular to the obstruction
      if raycastResult and raycastResult.Instance then
         speed = 0
         slideMomentum = 1

         -- Determine new movement direction adjacent to the obstructing surface
         -- Prioritize whichever direction brings the boomerang closer to the player
         local normal = raycastResult.Normal
         slideDirection = direction - normal * direction:Dot(normal)
         local slideMagnitude = slideDirection.Magnitude
         slideDirection = slideDirection.Unit

         -- Obstruction is directly between player and wall = stop movement
         if slideMagnitude < 0.01 then
            speed = 0
            return
         end

         -- Determine new slide speed
         local maximumSlideSpeed = math.clamp(maximumSpeed * slideMagnitude, 0, maximumSpeed)
         slideSpeed = math.clamp(slideSpeed + deltaTime * 60, 0, maximumSlideSpeed)
         local slideDistance = slideSpeed * deltaTime

         --local slideHit = workspace:Raycast(
         --  replicationPart.Position,
         --   slideDirection * slideDistance,
         --   raycastParams
         --)
         local slideHit = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius*.5, raycastParams, thrownWeaponData)

         if slideHit and not slideHit.Instance:IsDescendantOf(Characters) then
            speed = 0
            return
         end

         replicationPart:PivotTo(
            replicationPart.CFrame + slideDirection * slideDistance
         )
         lastReplicatedPosition = replicateIfMoved(player.UserId, replicationPart, lastReplicatedPosition)
      else
         slideMomentum = math.clamp(slideMomentum - (deltaTime * 10), 0, 1)
         local blendedDirection = slideDirection * slideMomentum + direction * (1 - slideMomentum)
         blendedDirection = blendedDirection.Unit
         local blendedSpeed = slideSpeed * slideMomentum + speed * (1 - slideMomentum)

         speed = math.min(speed + deltaTime * 100, toolData.Boomerang.Speed)
         slideSpeed = speed
         replicationPart:PivotTo(replicationPart.CFrame + blendedDirection * blendedSpeed * deltaTime)
         lastReplicatedPosition = replicateIfMoved(player.UserId, replicationPart, lastReplicatedPosition)
      end

      if distance <= speed * deltaTime then
         Boomerang.removeFromField(player, thrownWeaponData)
         return
      end
   end)
end

return Boomerang