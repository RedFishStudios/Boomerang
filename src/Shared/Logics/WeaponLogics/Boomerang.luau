-- // Regulates boomerang functionality

local Boomerang = {}

local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()

local ReplicatedStorage = game.ReplicatedStorage
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)

-- // Context-Specific Modules
local CombatService
if isServer then
   CombatService = require(game.ServerStorage.Server.Core.CombatService)
end

-- // Values
local Characters = game.Workspace.Characters
local ThrownWeaponsFolder = game.Workspace.ThrownWeapons
local ThrownWeaponReplicationPart = ReplicatedStorage.Shared.Assets.ThrownWeaponReplication

local thrownBoomerangSpawnedRemote = SimpleRemotes.getEvent("ThrownBoomerangSpawned")
local thrownBoomerangDespawnedRemote = SimpleRemotes.getEvent("ThrownBoomerangDespawned")
local thrownWeaponReplicationRemote = SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication")

local SLOW_RATE = 5
local UP_VECTOR = Vector3.new(0, 1, 0)
local REPLICATION_RATE = 1 / 20
local MAX_CATCHUP_SECONDS = 1.25
local CATCHUP_STEP = 1 / 60

local WEAPON_UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable

local SPAWN_PACKET_SIZE = 8 + 12 + 12 + 4 + 8
local DESPAWN_PACKET_SIZE = 8
local SNAPSHOT_PACKET_SIZE = 1 + 8 + 12 + 12 + 4 + 1 + 8

type ThrowInitOptions = {
   StartPosition: Vector3?,
   Direction: Vector3?,
   Speed: number?,
   ThrowServerTime: number?
}

type RecallInitOptions = {
   InitialSpeed: number?
}


local function getHorizontalDirection(direction: Vector3): Vector3
   local horizontal = Vector3.new(direction.X, 0, direction.Z)
   if horizontal.Magnitude <= 1e-5 then
      return Vector3.new(0, 0, -1)
   end
   return horizontal.Unit
end

local function getHorizontalRayOrigins(rayOrigin: Vector3, direction: Vector3, hitboxRadius: number): {Vector3}
   local rightDirection = direction:Cross(UP_VECTOR).Unit
   return {
      rayOrigin,
      rayOrigin - rightDirection * hitboxRadius,
      rayOrigin + rightDirection * hitboxRadius,
   }
end

-- // Notify all users of a boomerang spawn
local function fireSpawned(ownerUserId: number, boomerangId: string, position: Vector3, direction: Vector3, speed: number, throwServerTime: number)
   if not isServer then
      return
   end

   local payload = buffer.create(SPAWN_PACKET_SIZE)
   local offset = 0
   offset = BufferUtil.writeUserId(payload, offset, ownerUserId)
   offset = BufferUtil.writeVector3_96(payload, offset, position)
   offset = BufferUtil.writeVector3_96(payload, offset, direction)
   offset = BufferUtil.writef32(payload, offset, speed)
   BufferUtil.writef64(payload, offset, throwServerTime)

   thrownBoomerangSpawnedRemote:FireAllClients(boomerangId, payload)
end

-- // Notify all users of a boomerang despawn
local function fireDespawned(ownerUserId: number)
   if not isServer then
      return
   end
   local payload = buffer.create(DESPAWN_PACKET_SIZE)
   BufferUtil.writeUserId(payload, 0, ownerUserId)
   thrownBoomerangDespawnedRemote:FireAllClients(payload)
end

-- // Notify all users of a boomerang simulation snapshot
local function fireSnapshot(ownerUserId: number, position: Vector3, direction: Vector3, speed: number, state: number)
   if not isServer then
      return
   end

   local payload = buffer.create(SNAPSHOT_PACKET_SIZE)
   local offset = 0
   offset = BufferUtil.writeu8(payload, offset, WEAPON_UNRELIABLE_CODES.BoomerangSnapshot)
   offset = BufferUtil.writeUserId(payload, offset, ownerUserId)
   offset = BufferUtil.writeVector3_96(payload, offset, position)
   offset = BufferUtil.writeVector3_96(payload, offset, direction)
   offset = BufferUtil.writef32(payload, offset, speed)
   offset = BufferUtil.writeu8(payload, offset, state)
   BufferUtil.writef64(payload, offset, workspace:GetServerTimeNow())

   thrownWeaponReplicationRemote:FireAllClients(payload)
end

-- // Raycasting horizontally for horizontal moving boomerang collisions
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

   local horizontalRayOrigins = getHorizontalRayOrigins(rayOrigin, direction, hitboxRadius)
   local centerOrigin = horizontalRayOrigins[1]
   local leftOrigin = horizontalRayOrigins[2]
   local rightOrigin = horizontalRayOrigins[3]

   -- Position all 3 raycast visualizers at the predicted raycast endpoints
   weaponData.TestRaycastVisualizers[1].Position = centerOrigin + direction * rayDistance
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

local function raycastWithHorizontalCharacterHitbox(rayOrigin: Vector3, direction: Vector3, hitboxRadius: number): {Model}
   local characterRaycastParams = RaycastParams.new()
   characterRaycastParams.FilterType = Enum.RaycastFilterType.Include
   characterRaycastParams.FilterDescendantsInstances = {Characters}
   characterRaycastParams.IgnoreWater = true

   local horizontalRayOrigins = getHorizontalRayOrigins(rayOrigin, direction, hitboxRadius)
   local hitModels = {}
   local seenModels = {}

   local characterRayDistance = 2 -- TODO: adjust player detection ray length

   for _, origin in ipairs(horizontalRayOrigins) do
      local raycastResult = workspace:Raycast(origin, direction * characterRayDistance, characterRaycastParams)
      if raycastResult then
         local hitModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
         if hitModel and not table.find(seenModels, hitModel) then
            table.insert(seenModels, hitModel)

            local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
               table.insert(hitModels, hitModel)
            end
         end
      end
   end

   return hitModels
end

-- // Throw a boomerang onto the field
function Boomerang.throw(player: Player, boomerangId: string, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data, options: ThrowInitOptions?)
   if not toolData.Boomerang then
      warn(`this is not a boomerang`)
      return
   end
   local character = player.Character
   if not character then
      print(`no character`)
      return
   end

   local direction = getHorizontalDirection((options and options.Direction) or character.PrimaryPart.CFrame.LookVector)
   local speed = (options and options.Speed) or toolData.Boomerang.Speed
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local throwDistance = toolData.Boomerang.ThrowDistance
   local energy = toolData.Boomerang.Bounces

   local startPosition = (options and options.StartPosition) or (character.PrimaryPart.Position + character.PrimaryPart.CFrame.LookVector * 3)
   local throwOrigin = startPosition
   local throwServerTime = (options and options.ThrowServerTime) or workspace:GetServerTimeNow()

   if isServer then
      -- Server creates and monitors a simple representation part
      local partHost = ThrownWeaponReplicationPart:Clone()
      partHost.Name = `BoomerangReplication_{player.Name}`
      partHost.Position = startPosition
      partHost.Parent = ThrownWeaponsFolder
      fireSpawned(player.UserId, boomerangId, startPosition, direction, speed, throwServerTime)
      thrownWeaponData.Host = partHost
      thrownWeaponData.State = ThrownWeapons.StateEnum.Outgoing
   else
      -- Client creates and monitors the actual 3D model of the projectile
      local boomerangModel = ReplicatedStorage.Shared.Assets.Tools.ClassicBoomerang:Clone()
      boomerangModel.Name = `Boomerang_{player.Name}`
      boomerangModel:PivotTo(CFrame.new(startPosition))
      boomerangModel.Parent = workspace
      thrownWeaponData.Host = boomerangModel
   end

   local raycastParams = RaycastsUtility.getProjectileObstructionParams({thrownWeaponData.Host, Characters})
   local nextReplicationAt = 0

   local function simulateStep(deltaTime: number, shouldRecallTransitions: boolean)
      if not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
         return false
      end

      -- Exhaustion
      if energy <= 0 then
         thrownWeaponData.State = ThrownWeapons.StateEnum.Exhausted
         speed = speed - (speed * SLOW_RATE * deltaTime)
         if speed <= .1 then
            return false
         end
      end

      -- Raycast in front of the boomerang to detect collisions with walls or other obstacles
      local rayOrigin = thrownWeaponData.Host:GetPivot().Position
      local rayDistance = speed * deltaTime

      -- Switch to recall once the boomerang has traveled far enough from where it was thrown.
      if (rayOrigin - throwOrigin).Magnitude >= throwDistance then
         if shouldRecallTransitions then
            Boomerang.recall(player, boomerangId, toolData, thrownWeaponData)
            return true
         end
      end

      local victimModels = raycastWithHorizontalCharacterHitbox(rayOrigin, direction, hitboxRadius)
      local playerDamaged = false
      for _, victimModel in ipairs(victimModels) do
         local victimPlayer = victimModel and game.Players:GetPlayerFromCharacter(victimModel)
         if victimPlayer and victimPlayer ~= player then
            if victimPlayer.Team and (victimPlayer.Team ~= player.Team or victimPlayer.Team:GetAttribute("FriendlyFire") == true) then
               playerDamaged = true
               if isServer then
                  local Humanoid = victimModel:FindFirstChildOfClass("Humanoid")
                  if Humanoid and Humanoid.Health > 0 then
                     CombatService.damagePlayer(player, boomerangId, victimPlayer, Humanoid, 100000)
                  end
               else
                  print("play effect on client")
               end
            end
         end
      end

      if playerDamaged then
         if shouldRecallTransitions then
            Boomerang.recall(player, boomerangId, toolData, thrownWeaponData)
            return true
         end
      end

      local obstructionRaycastResult = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams, thrownWeaponData)
      if obstructionRaycastResult then
         energy -= 1
         direction = direction - 2 * direction:Dot(obstructionRaycastResult.Normal) * obstructionRaycastResult.Normal
         direction = getHorizontalDirection(direction)
         if energy == 0 then
            if shouldRecallTransitions then
               Boomerang.recall(player, boomerangId, toolData, thrownWeaponData)
            else
               thrownWeaponData.State = ThrownWeapons.StateEnum.Exhausted
            end
         end
         thrownWeaponData.Direction = direction
         thrownWeaponData.Speed = speed
         return true
      end

      local currentCFrame = thrownWeaponData.Host:GetPivot()
      thrownWeaponData.Host:PivotTo(currentCFrame + direction * speed * deltaTime)
      thrownWeaponData.Direction = direction
      thrownWeaponData.Speed = speed
      return true
   end

   -- Fast-forward newly replicated boomerangs to the best estimate of where they should be now.
   if not isServer and options and options.ThrowServerTime then
      local catchup = math.clamp(workspace:GetServerTimeNow() - options.ThrowServerTime, 0, MAX_CATCHUP_SECONDS)
      while catchup > 0 do
         local dt = math.min(CATCHUP_STEP, catchup)
         if not simulateStep(dt, false) then
            break
         end
         catchup -= dt
      end
   end

   thrownWeaponData.MovementConnection = RunService.Stepped:Connect(function(time, deltaTime)
      if not simulateStep(deltaTime, true) then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
         return
      end

      if isServer and time >= nextReplicationAt and thrownWeaponData.Host and thrownWeaponData.Host.Parent then
         nextReplicationAt = time + REPLICATION_RATE
         fireSnapshot(player.UserId, thrownWeaponData.Host:GetPivot().Position, direction, speed, thrownWeaponData.State)
      end
   end)
end

-- // Restore to player / remove from field
function Boomerang.removeFromField(player: Player, thrownWeaponData: ThrownWeapons.Data)
   if thrownWeaponData.Host then
      thrownWeaponData.Host:Destroy()
   end
   if isServer then
      fireDespawned(player.UserId)
   end
   for _, part in ipairs(thrownWeaponData.TestRaycastVisualizers) do
      if part and part.Parent then
         part:Destroy()
      end
   end
   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end
   ThrownWeapons.Data[player] = nil
end

function Boomerang.recall(player: Player, boomerangId: string, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data, options: RecallInitOptions?)
   print("recall")
   if not toolData.Boomerang then
      warn(`this is not a boomerang`)
      return
   end
   local character = player.Character
   if not character then
      print(`no character`)
      return
   end
   local host = thrownWeaponData.Host  
   if not host or not host.Parent then
      warn(`no host found for thrown tool`)
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
   local speed = options and options.InitialSpeed or 0
   local slideSpeed = 0
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local raycastParams = RaycastsUtility.getProjectileObstructionParams({host, Characters})
   local nextReplicationAt = 0

   local slideDirection = Vector3.new()
   local slideMomentum = 0 -- momentum carried by the slide

   thrownWeaponData.MovementConnection = RunService.Stepped:Connect(function(_, deltaTime)
      if not host or not host.Parent then
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
      local toPlayer = (rootPart.Position - host:GetPivot().Position)
      local distance = toPlayer.Magnitude
      if distance <= 1e-5 then
         Boomerang.removeFromField(player, thrownWeaponData)
         return
      end
      local direction = toPlayer.Unit

      -- // Raycast in that direction for an obstruction
      local rayOrigin = host:GetPivot().Position
      local rayDistance = (math.max(speed, hitboxRadius)) * deltaTime
      local raycastResult = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams, thrownWeaponData)
      local sliding = false

      -- // If we hit something, adjust movement direction to move perpendicular to the obstruction
      if raycastResult and raycastResult.Instance then
         sliding = true
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
         local slideHit = raycastWithHorizontalHitbox(rayOrigin, slideDirection, rayDistance, hitboxRadius*.5, raycastParams, thrownWeaponData)

         if slideHit and not slideHit.Instance:IsDescendantOf(Characters) then
            speed = 0
            return
         end

         host:PivotTo(
            host:GetPivot() + slideDirection * slideDistance
         )
      else
         slideMomentum = math.clamp(slideMomentum - (deltaTime * 10), 0, 1)
         local blendedDirection = slideDirection * slideMomentum + direction * (1 - slideMomentum)
         blendedDirection = blendedDirection.Unit
         local blendedSpeed = slideSpeed * slideMomentum + speed * (1 - slideMomentum)

         speed = math.min(speed + deltaTime * 100, toolData.Boomerang.Speed)
         slideSpeed = speed
         host:PivotTo(host:GetPivot() + blendedDirection * blendedSpeed * deltaTime)
      end

      local victimModels = raycastWithHorizontalCharacterHitbox(rayOrigin, if sliding then slideDirection else direction, hitboxRadius)
      for _, victimModel in ipairs(victimModels) do
         local victimPlayer = victimModel and game.Players:GetPlayerFromCharacter(victimModel)
         if victimPlayer and victimPlayer ~= player then
            if victimPlayer.Team and (victimPlayer.Team ~= player.Team or victimPlayer.Team:GetAttribute("FriendlyFire") == true) then
               if isServer then
                  local Humanoid = victimModel:FindFirstChildOfClass("Humanoid")
                  if Humanoid and Humanoid.Health > 0 then
                     CombatService.damagePlayer(player, boomerangId, victimPlayer, Humanoid, 100000)
                  end
               else
                  print("play effect on client")
               end
            end
         end
      end

      thrownWeaponData.Direction = direction
      thrownWeaponData.Speed = math.max(speed, slideSpeed)

      if isServer and os.clock() >= nextReplicationAt and host and host.Parent then
         nextReplicationAt = os.clock() + REPLICATION_RATE
         fireSnapshot(player.UserId, host:GetPivot().Position, direction, thrownWeaponData.Speed, thrownWeaponData.State)
      end

      if distance <= speed * deltaTime then
         Boomerang.removeFromField(player, thrownWeaponData)
         return
      end
   end)

   if isServer and host and host.Parent then
      local rootPart = character and character.PrimaryPart
      local immediateDirection = thrownWeaponData.Direction or Vector3.zero
      if rootPart then
         immediateDirection = getHorizontalDirection(rootPart.Position - host:GetPivot().Position)
      end
      fireSnapshot(player.UserId, host:GetPivot().Position, immediateDirection, thrownWeaponData.Speed or speed, thrownWeaponData.State)
   end
end

return Boomerang