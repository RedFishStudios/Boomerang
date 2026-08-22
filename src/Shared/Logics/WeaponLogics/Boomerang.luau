-- // Regulates boomerang functionality

local Boomerang = {}

local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()

local ReplicatedStorage = game.ReplicatedStorage
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local GameTeamLibrary = require(ReplicatedStorage.Shared.Library.GameTeamLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local HttpService = game:GetService("HttpService")

local AnimationController

-- // Context-Specific Modules
local WeaponService, ToolController
if isServer then
   WeaponService = require(game.ServerStorage.Server.Core.WeaponService)
else
   ToolController = require(ReplicatedStorage.Client.Core.ToolController)
	AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
end

-- // Values
local Characters = game.Workspace.Characters
local WeaponsFolder = game.Workspace:WaitForChild("Weapons")
local ThrownWeaponReplicationPart = ReplicatedStorage.Shared.Assets.ThrownWeaponReplication

local thrownBoomerangSpawnedRemote = SimpleRemotes.getEvent("ThrownBoomerangSpawned")
local thrownBoomerangDespawnedRemote = SimpleRemotes.getEvent("ThrownBoomerangDespawned")
local thrownWeaponReplicationRemote = SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication")

local SLOW_RATE = 5
local UP_VECTOR = Vector3.new(0, 1, 0)
local REPLICATION_RATE = 1 / 20
local MAX_CATCHUP_SECONDS = 1.25
local CATCHUP_STEP = 1 / 60
local AIM_START_SPEED_BONUS_MULTIPLIER = 1.0
local AIM_SPEED_FADE_RATE = 2.0
local RECALL_CATCH_RADIUS_MIN = 1.5
local CLASH_SPEED_SCALE = 0.5
local CLASH_MINIMUM_SPEED = 12
local CLASH_DECELERATION = 120
local CLASH_FALL_ACCELERATION = 120
local CLASH_MAX_FALL_SPEED = 80
local CLASH_GROUND_RAY_DISTANCE = 2048
local CLASH_GROUND_EPSILON = 0.02
local DEAD_PICKUP_DISTANCE = 3

local WEAPON_UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable
local WEAPON_RAYCAST_COLLISION_GROUP = CollisionGroupConstants.ThrownWeapons

local SPAWN_PACKET_SIZE = 8 + 12 + 12 + 4 + 8
local DESPAWN_PACKET_SIZE = 8 + 1
local SNAPSHOT_PACKET_SIZE = 1 + 8 + 12 + 12 + 4 + 1 + 8
local RAYCAST_VISUALIZERS_ENABLED = GlobalConfig.RaycastVisualizersEnabled
local PROJECTILE_HITBOX_VISUALIZER_ENABLED = GlobalConfig.ProjectileHitboxVisualizerEnabled

local BOOMERANG_SPIN_SPEED = math.rad(1080)

type ThrowInitOptions = {
   StartPosition: Vector3?,
   Direction: Vector3?,
   Speed: number?,
   InstanceId: string?,
   ThrowServerTime: number?,
   TimeSinceAiming: number?,
   AimStrengthAlpha: number?,
   ExistingHost: Model?
}

type RecallInitOptions = {
   InitialSpeed: number?
}

type RemoveFromFieldOptions = {
   ReturnToPlayer: boolean?
}

type ClashInitOptions = {
   Direction: Vector3,
   Speed: number?,
   Position: Vector3?,
}

-- // Flatten a direction vector
local function getHorizontalDirection(direction: Vector3): Vector3
   local horizontal = Vector3.new(direction.X, 0, direction.Z)
   if horizontal.Magnitude <= 1e-5 then
      return Vector3.new(0, 0, -1)
   end
   return horizontal.Unit
end

-- // Update the rotation of the trail based on the boomerang's movement
--    This ensures the trail leaves fully broad streak behind the boomerang
local function updateTrailOrientation(thrownWeaponData: ThrownWeapons.Data)
	local positions = thrownWeaponData.LastMovementPositions
	if not positions or #positions < 2 then
		-- Not enough movement data yet; use the default orientation
		thrownWeaponData.TrailObject.Attachment0.Position = Vector3.new(-1, 0, 0)
		thrownWeaponData.TrailObject.Attachment1.Position = Vector3.new(1, 0, 0)
		return
	end

	local currentPosition = positions[#positions]
	local previousPosition = positions[#positions - 1]

	-- Direction the object is moving in, ignoring vertical movement
	local movement = currentPosition - previousPosition
	movement = Vector3.new(movement.X, 0, movement.Z)

	if movement.Magnitude < 0.001 then
		return
	end

	movement = movement.Unit

	-- Get a direction perpendicular to the movement.
	-- This gives us the width direction of the trail.
	local perpendicular = Vector3.new(-movement.Z, 0, movement.X)

	-- Position the attachments on either side of the object.
	local width = 1

	thrownWeaponData.TrailObject.Attachment0.Position = perpendicular * -width
	thrownWeaponData.TrailObject.Attachment1.Position = perpendicular * width
end

-- // Add trail
local function addTrail(thrownWeaponData: ThrownWeapons.Data)
   if isServer then
      return
   end

   -- Record position for purpose of trail orientation
   local currentPosition = thrownWeaponData.CFrame.Position
   if not thrownWeaponData.LastMovementPositions then
      thrownWeaponData.LastMovementPositions = {}
   end
   table.insert(thrownWeaponData.LastMovementPositions, currentPosition)
   if #thrownWeaponData.LastMovementPositions > 2 then
      table.remove(thrownWeaponData.LastMovementPositions, 1)
   end

   if thrownWeaponData.TrailObject then
      thrownWeaponData.TrailObject.TrailHost:PivotTo(CFrame.new(thrownWeaponData.CFrame.Position))
      updateTrailOrientation(thrownWeaponData)
      return
   end
   
   local trailHost = Instance.new("Part")
   trailHost.Name = "TrailHost"
   trailHost.Parent = game.Workspace
   trailHost.Transparency = 1
   trailHost.Anchored = true
   trailHost.CanCollide = false
   trailHost.CanTouch = false
   trailHost.CanQuery = false
   trailHost:PivotTo(CFrame.new(thrownWeaponData.CFrame.Position))

   local attachment0 = Instance.new("Attachment")
   attachment0.Parent = trailHost

   local attachment1 = Instance.new("Attachment")
   attachment1.Parent = trailHost

   local trail = Instance.new("Trail")
   trail.Attachment0 = attachment0
   trail.Attachment1 = attachment1
   trail.Parent = trailHost

   local ownerPlayer = game.Players:GetPlayerByUserId(thrownWeaponData.OwnerUserId)
   if ownerPlayer == game.Players.LocalPlayer then
      trail.Color = ColorSequence.new(GlobalConfig.MyBoomerangTrailColor)
   elseif GameTeamLibrary.hasFriendlyFire(ownerPlayer.Team) then
      trail.Color = ColorSequence.new(GlobalConfig.EnemyBoomerangTrailColor)
   else
      local team = ownerPlayer.Team
      trail.Color = ColorSequence.new(if team then team.Color3 else GlobalConfig.EnemyBoomerangTrailColor)
   end

   trail.Lifetime = GlobalConfig.ThrownWeaponTrailLifetime

   attachment0.Position = Vector3.new(-1, 0, 0)
   attachment1.Position = Vector3.new(1, 0, 0)

   trail.Transparency = NumberSequence.new({
      NumberSequenceKeypoint.new(0, 1),
      NumberSequenceKeypoint.new(.1, 0),
      NumberSequenceKeypoint.new(1, 1)
   })

   thrownWeaponData.TrailObject = {
      TrailHost = trailHost,
      Trail = trail,
      Attachment0 = attachment0,
      Attachment1 = attachment1
   }

	updateTrailOrientation(thrownWeaponData)
end

-- // Get distance between two points flattened on the Y axis
local function getHorizontalDistance(fromPosition: Vector3, toPosition: Vector3): number
   local delta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
   return delta.Magnitude
end

local function getHorizontalRayOrigins(rayOrigin: Vector3, direction: Vector3, hitboxRadius: number): {Vector3}
   local rightDirection = direction:Cross(UP_VECTOR).Unit
   return {
      rayOrigin,
      rayOrigin - rightDirection * hitboxRadius,
      rayOrigin + rightDirection * hitboxRadius,
   }
end

local function getWeaponCFrame(thrownWeaponData: ThrownWeapons.Data): CFrame?
   local host = thrownWeaponData.Host
   if host and host.Parent then
      return host:GetPivot()
   end
   return thrownWeaponData.CFrame
end

-- // For a clashed boomerang, raycast downwards to detect where the boomerang should come to a rest
local function getClashRestingY(thrownWeaponData: ThrownWeapons.Data, position: Vector3, raycastParams: RaycastParams): number?
   local host = thrownWeaponData.Host
   if not host or not host.Parent then
      return nil
   end

   local result = workspace:Raycast(position, Vector3.new(0, -CLASH_GROUND_RAY_DISTANCE, 0), raycastParams)
   if not result then
      return nil
   end

   local boundsCFrame, boundsSize
   if host:IsA("Model") then
      boundsCFrame, boundsSize = host:GetBoundingBox()
   else
      boundsCFrame, boundsSize = host.CFrame, host.Size
   end

   local bottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
   local pivotToBottom = math.max(0, position.Y - bottomY)
   return result.Position.Y + pivotToBottom + CLASH_GROUND_EPSILON
end

local function setWeaponCFrame(thrownWeaponData: ThrownWeapons.Data, cframe: CFrame, deltaTime: number?)
   thrownWeaponData.LastPosition = thrownWeaponData.CFrame.Position
   thrownWeaponData.CFrame = cframe

   local host = thrownWeaponData.Host
   if host and host.Parent then
      if not isServer then
         local direction = thrownWeaponData.Direction
         if direction and direction.Magnitude > 1e-5 then
            local visualRotation = (thrownWeaponData.VisualRotation or 0) + (BOOMERANG_SPIN_SPEED * (deltaTime or 0))
            thrownWeaponData.VisualRotation = visualRotation

            local faceDirection = getHorizontalDirection(direction)
            local baseCFrame = CFrame.new(cframe.Position, cframe.Position + faceDirection)
            local spinCFrame = CFrame.Angles(0, visualRotation, 0)
            host:PivotTo(baseCFrame * spinCFrame)
         else
            host:PivotTo(cframe)
         end
      else
         host:PivotTo(cframe)
      end
      addTrail(thrownWeaponData)
     -- registerBeamSegment(thrownWeaponData, cframe.Position)
      --addNewBeam(thrownWeaponData)
   end
end

local function updateRaycastVisualizers(weaponData: ThrownWeapons.Data, rayOrigin: Vector3, direction: Vector3, rayDistance: number, hitboxRadius: number, raycastResult: RaycastResult?, finalResult: RaycastResult?)
   if not RAYCAST_VISUALIZERS_ENABLED then
      return
   end

   for i, p in pairs(weaponData.TestRaycastVisualizers) do
      if p and p.Parent then
         p.Color = Color3.new(0.164706, 0.960784, 0.007843)
         p.Transparency = .5
      end
   end

   rayDistance = math.max(rayDistance, hitboxRadius)
   local horizontalRayOrigins = getHorizontalRayOrigins(rayOrigin, direction, hitboxRadius)
   local leftOrigin = horizontalRayOrigins[2]
   local rightOrigin = horizontalRayOrigins[3]

   weaponData.TestRaycastVisualizers[1].Position = rayOrigin + direction * rayDistance
   weaponData.TestRaycastVisualizers[2].Position = leftOrigin + direction * rayDistance
   weaponData.TestRaycastVisualizers[3].Position = rightOrigin + direction * rayDistance

   if raycastResult then
      weaponData.TestRaycastVisualizers[1].Position = raycastResult.Position
      weaponData.TestRaycastVisualizers[1].Color = Color3.new(1, 0, 0)
   end

   if finalResult then
      weaponData.TestRaycastVisualizers[3].Position = finalResult.Position
      weaponData.TestRaycastVisualizers[3].Color = Color3.new(1, 0, 0)
   end
end

-- // Notify all users of a boomerang spawn
local function fireSpawned(ownerUserId: number, boomerangId: string, instanceId: string, position: Vector3, direction: Vector3, speed: number, throwServerTime: number)
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

   thrownBoomerangSpawnedRemote:FireAllClients(boomerangId, payload, instanceId)
end

-- // Notify all users of a boomerang despawn
local function fireDespawned(ownerUserId: number, returnToPlayer: boolean)
   if not isServer then
      return
   end
   local payload = buffer.create(DESPAWN_PACKET_SIZE)
   local offset = BufferUtil.writeUserId(payload, 0, ownerUserId)
   BufferUtil.writeu8(payload, offset, if returnToPlayer then 1 else 0)
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
   rayDistance = math.max(rayDistance, hitboxRadius)

   local horizontalRayOrigins = getHorizontalRayOrigins(rayOrigin, direction, hitboxRadius)
   local leftOrigin = horizontalRayOrigins[2]
   local rightOrigin = horizontalRayOrigins[3]

   local raycastResult = RaycastsUtility.raycastProjectileObstruction(rayOrigin, direction, rayDistance, raycastParams)
   if raycastResult then
      updateRaycastVisualizers(weaponData, rayOrigin, direction, rayDistance, hitboxRadius, raycastResult, nil)
      return raycastResult
   end

   raycastResult = RaycastsUtility.raycastProjectileObstruction(leftOrigin, direction, rayDistance, raycastParams)
   if raycastResult then
      updateRaycastVisualizers(weaponData, rayOrigin, direction, rayDistance, hitboxRadius, raycastResult, nil)
      return raycastResult
   end

   local finalResult = RaycastsUtility.raycastProjectileObstruction(rightOrigin, direction, rayDistance, raycastParams)
   if finalResult then
      updateRaycastVisualizers(weaponData, rayOrigin, direction, rayDistance, hitboxRadius, nil, finalResult)
   end
   return finalResult
end

local function spherecastCharacterHitbox(rayOrigin: Vector3, direction: Vector3, rayDistance: number, hitboxRadius: number): {Model}
   if rayDistance <= 0 then
      return {}
   end

   local characterRaycastParams = RaycastParams.new()
   characterRaycastParams.FilterType = Enum.RaycastFilterType.Include
   characterRaycastParams.FilterDescendantsInstances = {Characters}
   characterRaycastParams.IgnoreWater = true
   characterRaycastParams.CollisionGroup = WEAPON_RAYCAST_COLLISION_GROUP

   local hitModels = {}
   local spherecastResult = workspace:Spherecast(rayOrigin, hitboxRadius, direction * rayDistance, characterRaycastParams)
   if spherecastResult then
      local hitModel = spherecastResult.Instance:FindFirstAncestorOfClass("Model")
      if hitModel then
         local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
         if humanoid and humanoid.Health > 0 then
            table.insert(hitModels, hitModel)
         end
      end
   end

   return hitModels
end

local function isFullyVisibleObstruction(hitInstance: Instance): boolean
   if hitInstance:IsA("BasePart") then
      -- Exclude transparent geometry from obstruction checks.
      return (hitInstance.Transparency + hitInstance.LocalTransparencyModifier) <= 0
   end

   return true
end

local function isCameraObstructedToPoint(cameraPosition: Vector3, targetPosition: Vector3, filter: {Instance}?): boolean
   local toTarget = targetPosition - cameraPosition
   local distance = toTarget.Magnitude
   if distance <= 1e-5 then
      return false
   end

   local direction = toTarget.Unit
   local raycastParams = RaycastParams.new()
   raycastParams.FilterType = Enum.RaycastFilterType.Exclude
   raycastParams.IgnoreWater = true

   local excludedInstances = filter or {}
   for _ = 1, 12 do
      local raycastResult = workspace:Raycast(cameraPosition, direction * distance, raycastParams)
      if not raycastResult then
         return false
      end

      if isFullyVisibleObstruction(raycastResult.Instance) then
         return true
      end

      table.insert(excludedInstances, raycastResult.Instance)
   end

   return false
end

local function damagedPlayer(player: Player, boomerangId: string, thrownWeaponData: ThrownWeapons.Data, victimModel: Model): boolean
   local victimPlayer = game.Players:GetPlayerFromCharacter(victimModel)
   if not victimPlayer or victimPlayer == player then
      return false
   end

   if not victimPlayer.Team or (victimPlayer.Team == player.Team and victimPlayer.Team:GetAttribute("FriendlyFire") ~= true) then
      return false
   end

   if not thrownWeaponData.HitPlayers then
      thrownWeaponData.HitPlayers = {}
   end

   local now = workspace:GetServerTimeNow()
   local previousHitAt = thrownWeaponData.HitPlayers[victimPlayer]
   local hitCooldownSeconds = GlobalConfig.BoomerangHitThrottle or .5
   if previousHitAt and (now - previousHitAt) < hitCooldownSeconds then
      return false
   end

   thrownWeaponData.HitPlayers[victimPlayer] = now

   local Humanoid = victimModel:FindFirstChildOfClass("Humanoid")
   if Humanoid and Humanoid.Health > 0 then
      local healthBeforeDamage = Humanoid.Health
      CombatLibrary.attackHitPlayer(player, boomerangId, victimPlayer, Humanoid, 100000)
      if isServer and WeaponService and healthBeforeDamage > 0 and Humanoid.Health <= 0 then
         WeaponService.WeaponKilledPlayer:Execute("parallel", player, victimPlayer, thrownWeaponData.ToolId)
      end
      return true
   end

   return false
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

   if AnimationController then
      AnimationController.playCoreAnimation(player, "Throw")
   end

   local boomerangInstanceId = (options and options.InstanceId) or HttpService:GenerateGUID(false)
   thrownWeaponData.InstanceId = boomerangInstanceId

   local direction = getHorizontalDirection((options and options.Direction) or character.PrimaryPart.CFrame.LookVector)
   local defaultSpeed = toolData.Boomerang.Speed
   local speed = (options and options.Speed) or defaultSpeed
   local aimStrengthAlpha = math.clamp((options and options.AimStrengthAlpha) or 0, 0, 1)
   if aimStrengthAlpha > 0 and (not options or options.Speed == nil) then
      speed = defaultSpeed * (1 + aimStrengthAlpha * AIM_START_SPEED_BONUS_MULTIPLIER)
   end 
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local bounceDistance = toolData.Boomerang.ThrowDistance
   local initThrowDistance = bounceDistance * (1 + aimStrengthAlpha)
   local energy = toolData.Boomerang.Bounces

   local startPosition = (options and options.StartPosition) or (character.PrimaryPart.Position + character.PrimaryPart.CFrame.LookVector * 3)
   
   --[[if startPosition then
      local StartPartRep = Instance.new("Part")
      StartPartRep.Name = "OptionsStartPosition"
      StartPartRep.Shape = Enum.PartType.Ball
      StartPartRep.Size = Vector3.new(3, 3, 3)
      StartPartRep.Material = "Neon"
      StartPartRep.Anchored = true
      StartPartRep.CanCollide = false
      StartPartRep.CanQuery = false
      StartPartRep.CanTouch = false
      StartPartRep.Parent = game.Workspace
      StartPartRep.Position = startPosition
   end]]
   
   local startCFrame = CFrame.new(startPosition)
   local throwOrigin = startPosition
   local throwServerTime = (options and options.ThrowServerTime) or workspace:GetServerTimeNow()
   local lastBounceOrigin = throwOrigin
   local bounced = false
   thrownWeaponData.LastPosition = startPosition
   thrownWeaponData.CFrame = startCFrame
   thrownWeaponData.VisualRotation = math.random() * math.pi * 2

   --[[local OriginRep = Instance.new("Part")
   OriginRep.Name = "Origin"
   OriginRep.Shape = Enum.PartType.Ball
   OriginRep.Color = Color3.new(1, 0, 0)
   OriginRep.Size = Vector3.new(3, 3, 3)
   OriginRep.Material = "Neon"
   OriginRep.Anchored = true
   OriginRep.CanCollide = false
   OriginRep.CanQuery = false
   OriginRep.CanTouch = false
   OriginRep.Parent = game.Workspace
   OriginRep.Position = throwOrigin]]

   if isServer then
      fireSpawned(player.UserId, boomerangId, boomerangInstanceId, startPosition, direction, speed, throwServerTime)
      thrownWeaponData.State = ThrownWeapons.StateEnum.Outgoing
      if PROJECTILE_HITBOX_VISUALIZER_ENABLED then
         -- Server creates and monitors a simple representation part for debugging.
         local partHost = ThrownWeaponReplicationPart:Clone()
         partHost.Name = `BoomerangReplication_{player.Name}`
         partHost.Position = startPosition
         partHost.Transparency = 0
         partHost.Parent = WeaponsFolder
         thrownWeaponData.Host = partHost
      else
         thrownWeaponData.LastPosition = startPosition
         thrownWeaponData.CFrame = startCFrame
      end
   else
      local boomerangModel = options and options.ExistingHost
      if boomerangModel and boomerangModel.Parent then
         thrownWeaponData.ReuseEquippedHost = true
         boomerangModel.Name = `Boomerang_{player.Name}`
      else
		 local equippedToolId = GlobalConfig.ForceEquippedTool
		 if equippedToolId == nil then
			warn("Boomerang: GlobalConfig.ForceEquippedTool is nil; cannot clone thrown weapon model")
			return
		 end

         -- Client creates and monitors the actual 3D model of the projectile
         boomerangModel = ReplicatedStorage.Shared.Assets.Tools[equippedToolId]:Clone()
         boomerangModel.Name = `Boomerang_{player.Name}`
      end
      SoundLibrary.play(boomerangInstanceId, Sounds.Data.Throw.Name, boomerangModel.PrimaryPart, nil, true)
      SoundLibrary.play(boomerangInstanceId, Sounds.Data.BoomerangLoop.Name, boomerangModel.PrimaryPart, nil, true)

      for _, descendant in ipairs(boomerangModel:GetDescendants()) do
         if descendant:IsA("BasePart") then
            descendant.Anchored = true
         end
      end

      boomerangModel:PivotTo(startCFrame)
      boomerangModel.Parent = WeaponsFolder
      thrownWeaponData.Host = boomerangModel
   end

   local obstructionFilter = {Characters, character}
   if thrownWeaponData.Host then
      table.insert(obstructionFilter, 1, thrownWeaponData.Host)
   end
   local raycastParams = RaycastsUtility.getProjectileObstructionParams(obstructionFilter)
   local nextReplicationAt = 0

   -- // Simulate a frame of boomerang movement
   local function simulateStep(deltaTime: number, shouldRecallTransitions: boolean)
      local pivot = getWeaponCFrame(thrownWeaponData)
      if not pivot then
         return false
      end

      --[[if not thrownWeaponData.DisplayedFirstPivot then
         thrownWeaponData.DisplayedFirstPivot  = true
         local OriginRep = Instance.new("Part")
         OriginRep.Name = "FirstPivot"
         OriginRep.Shape = Enum.PartType.Ball
         OriginRep.Color = Color3.new(1, 0, 0)
         OriginRep.Size = Vector3.new(3, 3, 3)
         OriginRep.Material = "Neon"
         OriginRep.Anchored = true
         OriginRep.CanCollide = false
         OriginRep.CanQuery = false
         OriginRep.CanTouch = false
         OriginRep.Parent = game.Workspace
         OriginRep.CFrame = pivot
      end]]

      if isServer then
         if PROJECTILE_HITBOX_VISUALIZER_ENABLED then
            if not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
               return false
            end
         end
      else
         if not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
            return false
         end
         if ToolController then
            local camera = workspace.CurrentCamera
            if camera then
               local isObstructed = isCameraObstructedToPoint(camera.CFrame.Position, pivot.Position, {character, thrownWeaponData.Host})
               ToolController.applyHighlight(isObstructed)
            else
               ToolController.applyHighlight(false)
            end
         end
      end

      if energy > 0 and speed > defaultSpeed then
         local fadeAlpha = math.clamp(deltaTime * AIM_SPEED_FADE_RATE, 0, 1)
         speed = speed + (defaultSpeed - speed) * fadeAlpha
      end

      -- Exhaustion
      if energy <= 0 then
         thrownWeaponData.State = ThrownWeapons.StateEnum.Exhausted
         speed = speed - (speed * SLOW_RATE * deltaTime)
         if speed <= .1 then
            return false
         end
      end

      local rayOrigin = pivot.Position
      local rayDistance = speed * deltaTime

      -- Distance-based recall
      if (rayOrigin - lastBounceOrigin).Magnitude >= (if bounced then bounceDistance else initThrowDistance) then
         if shouldRecallTransitions then
            if isServer and WeaponService then
               WeaponService.WeaponReachedEventPoint:Execute("parallel", player, thrownWeaponData.ToolId, rayOrigin)
            end
            Boomerang.recall(player, boomerangId, toolData, thrownWeaponData)
            return true
         end
      end

      local victimModels = spherecastCharacterHitbox(rayOrigin, direction, rayDistance, hitboxRadius)
      local playerDamaged = false
      for _, victimModel in ipairs(victimModels) do
         if damagedPlayer(player, boomerangId, thrownWeaponData, victimModel) then
            playerDamaged = true
         end
      end

      --if playerDamaged then
      --  if shouldRecallTransitions then
      --      Boomerang.recall(player, boomerangId, toolData, thrownWeaponData)
      --      return true
      --   end
      --end

      local obstructionRaycastResult = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams, thrownWeaponData)
      if obstructionRaycastResult then
         if isServer and WeaponService then
            WeaponService.WeaponStruckObject:Execute("parallel", player, thrownWeaponData.ToolId, obstructionRaycastResult)
         end
         energy -= 1
         bounced = true
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

      local currentCFrame = pivot
      setWeaponCFrame(thrownWeaponData, currentCFrame + direction * speed * deltaTime, deltaTime)
      thrownWeaponData.Direction = direction
      thrownWeaponData.Speed = speed
      return true
   end

   -- Fast-forward newly replicated boomerangs to the best estimate of where they should be now
   -- DISABLED; this cannot be disabled in its current state as it causes significant jumping of the boomerang on the client upon spawn
   -- The boomerang's position does appear to correctly catch up immediately after, so this doesn't seem to be of significance to remove
  --[[if not isServer and options and options.ThrowServerTime then
      local catchup = math.clamp(workspace:GetServerTimeNow() - options.ThrowServerTime, 0, MAX_CATCHUP_SECONDS)
      while catchup > 0 do
         local dt = math.min(CATCHUP_STEP, catchup)
         if not simulateStep(dt, false) then
            break
         end
         catchup -= dt
      end
   end]]

   thrownWeaponData.MovementConnection = RunService.Stepped:Connect(function(time, deltaTime)
      if not simulateStep(deltaTime, true) then
         local movementConnection = thrownWeaponData.MovementConnection
         if movementConnection then
            movementConnection:Disconnect()
            thrownWeaponData.MovementConnection = nil
         end
         return
      end

      if ThrownWeapons.Data[player] ~= thrownWeaponData then
         return
      end

      local currentPivot = getWeaponCFrame(thrownWeaponData)
      if isServer and PROJECTILE_HITBOX_VISUALIZER_ENABLED then
         if not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
            local movementConnection = thrownWeaponData.MovementConnection
            if movementConnection then
               movementConnection:Disconnect()
               thrownWeaponData.MovementConnection = nil
            end
            return
         end
      elseif not currentPivot then
         local movementConnection = thrownWeaponData.MovementConnection
         if movementConnection then
            movementConnection:Disconnect()
            thrownWeaponData.MovementConnection = nil
         end
         return
      end

      SharedTasks.ThrownWeaponMoved:Execute("serial", player, thrownWeaponData.ToolId, currentPivot.Position, false)

      if isServer and time >= nextReplicationAt and currentPivot then
         nextReplicationAt = time + REPLICATION_RATE
         fireSnapshot(player.UserId, currentPivot.Position, direction, speed, thrownWeaponData.State)
      end
   end)
end

-- // Restore to player / remove from field
function Boomerang.removeFromField(player: Player, thrownWeaponData: ThrownWeapons.Data, options: RemoveFromFieldOptions?)
   local returnToPlayer = options == nil or options.ReturnToPlayer ~= false
   local shouldReattachLocally = returnToPlayer and (not isServer) and thrownWeaponData.ReuseEquippedHost == true

   if returnToPlayer and AnimationController then
      AnimationController.playCoreAnimation(player, "Catch")
   end

   if thrownWeaponData.Host then
      if not shouldReattachLocally then
         thrownWeaponData.Host:Destroy()
      end
   end
   if isServer then
      fireDespawned(player.UserId, returnToPlayer)
      SharedTasks.ThrownWeaponRemoved:Execute("serial", player, thrownWeaponData.ToolId)
      if returnToPlayer then
         WeaponService.WeaponReturnedTasks:Execute("parallel", player, thrownWeaponData.ToolId)
      end
   elseif returnToPlayer then
      SoundLibrary.play(thrownWeaponData.InstanceId, Sounds.Data.BoomerangCatch.Name, player.Character)
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
   thrownWeaponData.CFrame = nil
   ThrownWeapons.Data[player] = nil

   if thrownWeaponData.TrailObject then
      if thrownWeaponData.TrailObject.TrailHost and thrownWeaponData.TrailObject.TrailHost.Parent then
         thrownWeaponData.TrailObject.TrailHost:Destroy()
      end
      if thrownWeaponData.TrailObject.Trail and thrownWeaponData.TrailObject.Trail.Parent then
         thrownWeaponData.TrailObject.Trail:Destroy()
      end
      if thrownWeaponData.TrailObject.Attachment0 and thrownWeaponData.TrailObject.Attachment0.Parent then
         thrownWeaponData.TrailObject.Attachment0:Destroy()
      end
      if thrownWeaponData.TrailObject.Attachment1 and thrownWeaponData.TrailObject.Attachment1.Parent then
         thrownWeaponData.TrailObject.Attachment1:Destroy()
      end
   end

   if shouldReattachLocally and ToolController then
      ToolController.finishToolThrow(player)
   end
end

function Boomerang.setDead(player: Player, thrownWeaponData: ThrownWeapons.Data, position: Vector3?)
   local isClientClashFall = not isServer and thrownWeaponData.State == ThrownWeapons.StateEnum.Clashed
   if thrownWeaponData.MovementConnection and not isClientClashFall then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end

   local pivot = getWeaponCFrame(thrownWeaponData)
   if not pivot then
      return
   end
   if position then
      local deadPosition = Vector3.new(position.X, pivot.Position.Y, position.Z)
      setWeaponCFrame(thrownWeaponData, (pivot - pivot.Position) + deadPosition)
   end

   thrownWeaponData.State = ThrownWeapons.StateEnum.Dead
   thrownWeaponData.Speed = 0
   thrownWeaponData.SyncTargetPosition = nil

   if isServer then
      local deadPivot = getWeaponCFrame(thrownWeaponData)
      if deadPivot then
         fireSnapshot(player.UserId, deadPivot.Position, thrownWeaponData.Direction or Vector3.zero, 0, thrownWeaponData.State)
      end

      thrownWeaponData.MovementConnection = RunService.Heartbeat:Connect(function()
         if ThrownWeapons.Data[player] ~= thrownWeaponData then
            if thrownWeaponData.MovementConnection then
               thrownWeaponData.MovementConnection:Disconnect()
               thrownWeaponData.MovementConnection = nil
            end
            return
         end

         local currentPivot = getWeaponCFrame(thrownWeaponData)
         local character = player.Character
         local rootPart = character and character.PrimaryPart
         if currentPivot and rootPart and getHorizontalDistance(currentPivot.Position, rootPart.Position) <= DEAD_PICKUP_DISTANCE then
            Boomerang.removeFromField(player, thrownWeaponData)
         end
      end)
   end
end

function Boomerang.clash(player: Player, thrownWeaponData: ThrownWeapons.Data, options: ClashInitOptions)
   if thrownWeaponData.State == ThrownWeapons.StateEnum.Clashed or thrownWeaponData.State == ThrownWeapons.StateEnum.Dead then
      return
   end

   local pivot = getWeaponCFrame(thrownWeaponData)
   if not pivot then
      return
   end
   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end

   local direction = getHorizontalDirection(options.Direction)
   local speed = options.Speed or math.max((thrownWeaponData.Speed or 0) * CLASH_SPEED_SCALE, CLASH_MINIMUM_SPEED)
   local nextReplicationAt = 0
   local fallSpeed = 0
   local isGrounded = false
   local groundRaycastParams
   if not isServer then
      groundRaycastParams = RaycastParams.new()
      groundRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
      groundRaycastParams.FilterDescendantsInstances = {thrownWeaponData.Host, Characters}
      groundRaycastParams.IgnoreWater = true
      groundRaycastParams.CollisionGroup = CollisionGroupConstants.Camera
   end
   thrownWeaponData.State = ThrownWeapons.StateEnum.Clashed
   thrownWeaponData.Direction = direction
   thrownWeaponData.Speed = speed
   thrownWeaponData.SyncTargetPosition = nil

   if options.Position then
      local initialPosition = Vector3.new(options.Position.X, pivot.Position.Y, options.Position.Z)
      setWeaponCFrame(thrownWeaponData, (pivot - pivot.Position) + initialPosition)
   end

   if isServer then
      local initialPivot = getWeaponCFrame(thrownWeaponData)
      if initialPivot then
         fireSnapshot(player.UserId, initialPivot.Position, direction, speed, thrownWeaponData.State)
      end
   end

   thrownWeaponData.MovementConnection = RunService.Stepped:Connect(function(time, deltaTime)
      if ThrownWeapons.Data[player] ~= thrownWeaponData then
         return
      end

      local currentPivot = getWeaponCFrame(thrownWeaponData)
      if not currentPivot then
         return
      end

      local nextSpeed = math.max(0, speed - CLASH_DECELERATION * deltaTime)
      local travelDistance = (speed + nextSpeed) * 0.5 * deltaTime
      speed = nextSpeed
      local nextPosition = currentPivot.Position + direction * travelDistance

      if not isServer and not isGrounded and groundRaycastParams then
         fallSpeed = math.min(CLASH_MAX_FALL_SPEED, fallSpeed + CLASH_FALL_ACCELERATION * deltaTime)
         local restingY = getClashRestingY(thrownWeaponData, nextPosition, groundRaycastParams)
         local nextY = nextPosition.Y - fallSpeed * deltaTime
         if restingY and nextY <= restingY then
            nextY = restingY
            fallSpeed = 0
            isGrounded = true
         end
         nextPosition = Vector3.new(nextPosition.X, nextY, nextPosition.Z)
      end

      setWeaponCFrame(thrownWeaponData, (currentPivot - currentPivot.Position) + nextPosition, deltaTime)
      thrownWeaponData.Speed = speed

      if isServer and time >= nextReplicationAt then
         nextReplicationAt = time + REPLICATION_RATE
         fireSnapshot(player.UserId, nextPosition, direction, speed, thrownWeaponData.State)
      end

      if speed <= 0 then
         if isServer then
            Boomerang.setDead(player, thrownWeaponData)
         elseif isGrounded then
            if thrownWeaponData.MovementConnection then
               thrownWeaponData.MovementConnection:Disconnect()
               thrownWeaponData.MovementConnection = nil
            end
         end
      end
   end)
end

function Boomerang.recall(player: Player, boomerangId: string, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data, options: RecallInitOptions?)
   if not toolData.Boomerang then
      warn(`this is not a boomerang`)
      return
   end
   local hostPart = thrownWeaponData.Host
   local hostPivot = getWeaponCFrame(thrownWeaponData)
   if not hostPart and not hostPivot then
      warn(`no host position found for thrown tool`)
      return
   end
   if thrownWeaponData.State == ThrownWeapons.StateEnum.Returning
      or thrownWeaponData.State == ThrownWeapons.StateEnum.Clashed
      or thrownWeaponData.State == ThrownWeapons.StateEnum.Dead
   then
      return
   end

   thrownWeaponData.State = ThrownWeapons.StateEnum.Returning
   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end

   local maximumSpeed = toolData.Boomerang.Speed
   local speed = math.max((options and options.InitialSpeed) or 0, thrownWeaponData.Speed or 0)
   local slideSpeed = 0
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local catchRadius = math.max(RECALL_CATCH_RADIUS_MIN, hitboxRadius * 1.25)
   local raycastParams = RaycastsUtility.getProjectileObstructionParams({hostPart, Characters})
   local nextReplicationAt = 0

   local slideDirection = Vector3.new()
   local slideMomentum = 0 -- momentum carried by the slide
   local carriedDirection = thrownWeaponData.Direction
   local travelVelocity = Vector3.new()
   if carriedDirection and carriedDirection.Magnitude > 1e-5 and speed > 0 then
      travelVelocity = getHorizontalDirection(carriedDirection) * speed
   end

   thrownWeaponData.MovementConnection = RunService.Stepped:Connect(function(_, deltaTime)
      if isServer and PROJECTILE_HITBOX_VISUALIZER_ENABLED then
         if not hostPart or not hostPart.Parent then
            thrownWeaponData.MovementConnection:Disconnect()
            thrownWeaponData.MovementConnection = nil
            return
         end
      elseif not getWeaponCFrame(thrownWeaponData) then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
         return
      end

      local currentCharacter = player.Character
      local rootPart = currentCharacter and currentCharacter.PrimaryPart
      if not rootPart then
         if isServer then
            Boomerang.removeFromField(player, thrownWeaponData)
         else
            thrownWeaponData.MovementConnection:Disconnect()
            thrownWeaponData.MovementConnection = nil
         end
         return
      end

      -- // Prioritize movement towards the player
      local hostPivot = getWeaponCFrame(thrownWeaponData)
      if not hostPivot then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
         return
      end

      if not isServer and ToolController then
         local camera = workspace.CurrentCamera
         if camera then
            local isObstructed = isCameraObstructedToPoint(camera.CFrame.Position, hostPivot.Position, {currentCharacter, hostPart})
            ToolController.applyHighlight(isObstructed)
         else
            ToolController.applyHighlight(false)
         end
      end

      local toPlayer = (rootPart.Position - hostPivot.Position)
      local horizontalDistance = getHorizontalDistance(hostPivot.Position, rootPart.Position)
      if horizontalDistance <= catchRadius then
         Boomerang.removeFromField(player, thrownWeaponData)
         return
      end
      local targetDirection = getHorizontalDirection(toPlayer)

      if travelVelocity.Magnitude <= 1e-5 then
         travelVelocity = targetDirection * speed
      end

      local alignment = travelVelocity.Unit:Dot(targetDirection)
      local transitionRate = if alignment < -0.25 then 11 elseif alignment < 0.5 then 8 else 5
      local targetVelocity = targetDirection * maximumSpeed
      local transitionAlpha = 1 - math.exp(-transitionRate * deltaTime)
      travelVelocity = travelVelocity:Lerp(targetVelocity, transitionAlpha)

      local velocityMagnitude = travelVelocity.Magnitude
      speed = math.clamp(velocityMagnitude, 0, maximumSpeed)
      local direction = if velocityMagnitude > 1e-5 then getHorizontalDirection(travelVelocity.Unit) else targetDirection

      -- // Raycast in that direction for an obstruction
      local rayOrigin = hostPivot.Position
      local rayDistance = (math.max(speed, hitboxRadius)) * deltaTime
      local raycastResult = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams, thrownWeaponData)
      local sliding = false

      -- // If we hit something, adjust movement direction to move perpendicular to the obstruction
      if raycastResult and raycastResult.Instance then
         if isServer and WeaponService then
            WeaponService.WeaponStruckObject:Execute("parallel", player, thrownWeaponData.ToolId, raycastResult)
         end
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
         local slideDistance = math.min(slideSpeed * deltaTime, horizontalDistance)

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

         setWeaponCFrame(thrownWeaponData, hostPivot + slideDirection * slideDistance, deltaTime)
         travelVelocity = slideDirection * slideSpeed
      else
         slideMomentum = math.clamp(slideMomentum - (deltaTime * 10), 0, 1)
         local blendedDirection = slideDirection * slideMomentum + direction * (1 - slideMomentum)
         blendedDirection = blendedDirection.Unit
         local blendedSpeed = slideSpeed * slideMomentum + speed * (1 - slideMomentum)
         local blendedDistance = math.min(blendedSpeed * deltaTime, horizontalDistance)

         slideSpeed = math.max(speed, slideSpeed * slideMomentum)
         setWeaponCFrame(thrownWeaponData, hostPivot + blendedDirection * blendedDistance, deltaTime)
         travelVelocity = blendedDirection * blendedSpeed
      end

      local characterDirection = if sliding then slideDirection else direction
      local characterRayDistance = (if sliding then slideSpeed else speed) * deltaTime
      local victimModels = spherecastCharacterHitbox(rayOrigin, characterDirection, characterRayDistance, hitboxRadius)
      for _, victimModel in ipairs(victimModels) do
         damagedPlayer(player, boomerangId, thrownWeaponData, victimModel)
      end

      thrownWeaponData.Direction = direction
      thrownWeaponData.Speed = math.max(speed, slideSpeed)

      local currentPivot = getWeaponCFrame(thrownWeaponData)
      if currentPivot then
         SharedTasks.ThrownWeaponMoved:Execute("serial", player, thrownWeaponData.ToolId, currentPivot.Position, true)
      end
      if isServer and os.clock() >= nextReplicationAt and currentPivot then
         nextReplicationAt = os.clock() + REPLICATION_RATE
         fireSnapshot(player.UserId, currentPivot.Position, direction, thrownWeaponData.Speed, thrownWeaponData.State)
      end

      local newPivot = getWeaponCFrame(thrownWeaponData)
      if newPivot and getHorizontalDistance(newPivot.Position, rootPart.Position) <= catchRadius then
         Boomerang.removeFromField(player, thrownWeaponData)
         return
      end
   end)

   local currentPivot = getWeaponCFrame(thrownWeaponData)
   if isServer and currentPivot then
      local currentCharacter = player.Character
      local rootPart = currentCharacter and currentCharacter.PrimaryPart
      local immediateDirection = thrownWeaponData.Direction or Vector3.zero
      if rootPart then
         immediateDirection = getHorizontalDirection(rootPart.Position - currentPivot.Position)
      end
      fireSnapshot(player.UserId, currentPivot.Position, immediateDirection, thrownWeaponData.Speed or speed, thrownWeaponData.State)
   end
end

return Boomerang