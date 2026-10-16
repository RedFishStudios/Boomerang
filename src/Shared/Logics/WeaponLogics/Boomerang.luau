-- // Regulates boomerang functionality

local Boomerang = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local isServer = RunService:IsServer()

local ReplicatedStorage = game.ReplicatedStorage
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local AuthorityViewLibrary = require(ReplicatedStorage.Shared.Library.AuthorityViewLibrary)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local GameTeamLibrary = require(ReplicatedStorage.Shared.Library.GameTeamLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local DynamicCollisionLibrary = require(ReplicatedStorage.Shared.Library.DynamicCollisionLibrary)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local HomingBoomerang = require(ReplicatedStorage.Shared.Logics.PickupLogics.HomingBoomerang)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local Portal = require(ReplicatedStorage.Shared.Logics.Environment.Portal)
local ClashedWeapons = require(ReplicatedStorage.Shared.Referential.ClashedWeapons)
local ClashedWeaponLogic = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Clashed)
local HttpService = game:GetService("HttpService")

local AnimationController

-- // Context-Specific Modules
local WeaponService, ToolController, BotService
if isServer then
   WeaponService = require(game.ServerStorage.Server.Core.WeaponService)
   BotService = require(game.ServerStorage.Server.Core.BotService)
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
local AIM_START_SPEED_BONUS_MULTIPLIER = 1.0
local AIM_SPEED_FADE_RATE = 2.0
local RECALL_CATCH_RADIUS_MIN = 1.5
-- // The server catches a returning boomerang at a slightly larger radius than the client. The server can keep the
-- // boomerang orbiting a hair outside the catch radius (it appears to graze the player and circle) while the client
-- // already caught it; this small server-only bonus closes that gap so the two agree. Tunable.
local SERVER_RECALL_CATCH_BONUS = 0.5
local RETURN_STEER_TIGHTNESS = 3 -- // How sharply a returning boomerang turns into the player up close (1 = circles them; higher = more direct)
local CLASH_SPEED_SCALE = 0.5
local CLASH_MINIMUM_SPEED = 12
local OBSTRUCTION_BLOCKCAST_HEIGHT = 1
local OBSTRUCTION_BLOCKCAST_DEPTH = 0.2
local OBSTRUCTION_BLOCKCAST_WIDTH_SCALE = 1.4
local OBSTRUCTION_BLOCKCAST_SKIN = 1
local BLOCKCAST_VISUALIZER_LIFETIME = 0.05

local WEAPON_UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable
local WEAPON_RAYCAST_COLLISION_GROUP = CollisionGroupConstants.ThrownWeapons

local SPAWN_PACKET_SIZE = 8 + 12 + 12 + 4 + 8
local DESPAWN_PACKET_SIZE = 8 + 1
local SNAPSHOT_PACKET_SIZE = 1 + 8 + 12 + 12 + 4 + 1 + 8
local RAYCAST_VISUALIZERS_ENABLED = GlobalConfig.RaycastVisualizersEnabled
local PROJECTILE_HITBOX_VISUALIZER_ENABLED = GlobalConfig.ProjectileHitboxVisualizerEnabled

local BOOMERANG_SPIN_SPEED = math.rad(1080)
local RECALL_FROM_DEAD_LIFT_RATE = 8 -- // How fast a boomerang recalled off the ground rises to hand height
local MANUAL_RECALL_TILT_HEIGHT = 2 -- // Height still to rise (studs) at which the manual-recall tilt is at its maximum
local MANUAL_RECALL_TILT_RESPONSE = 6 -- // How quickly the tilt eases toward its target

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

local function getDynamicCollisionResponse(raycastResult: RaycastResult, velocity: Vector3): Vector3?
   local surfaceVelocity = DynamicCollisionLibrary.getPointVelocity(raycastResult.Instance, raycastResult.Position)
   if not surfaceVelocity then
      return nil
   end

   local relativeVelocity = velocity - surfaceVelocity
   local reflectedRelativeVelocity = relativeVelocity - 2 * relativeVelocity:Dot(raycastResult.Normal) * raycastResult.Normal
   return reflectedRelativeVelocity + surfaceVelocity
end

local function getDynamicDisplacement(position: Vector3, radius: number, deltaTime: number): Vector3
   local velocity = DynamicCollisionLibrary.getOverlappingVelocity(position, radius)
   if not velocity then
      return Vector3.zero
   end
   return velocity * deltaTime
end

local function getNearestEnemyDirection(player: Player, position: Vector3): Vector3?
   local nearestDirection = nil
   local nearestDistance = math.huge

   for _, otherPlayer in ipairs(Players:GetPlayers()) do
      if otherPlayer == player or not GameTeamLibrary.areEnemies(player, otherPlayer) then
         continue
      end

      local character = otherPlayer.Character
      local humanoid = character and character:FindFirstChildOfClass("Humanoid")
      local rootPart = character and character.PrimaryPart
      if not humanoid or humanoid.Health <= 0 or not rootPart then
         continue
      end

      local toTarget = Vector3.new(
         rootPart.Position.X - position.X,
         0,
         rootPart.Position.Z - position.Z
      )
      local distance = toTarget.Magnitude
      if distance > 1e-5 and distance < nearestDistance then
         nearestDistance = distance
         nearestDirection = toTarget.Unit
      end
   end

   return nearestDirection
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

-- // Leave the current trail where it is so it fades out over its Lifetime, and let addTrail start a fresh one
-- // (used when the boomerang teleports, e.g. through a portal, so the trail doesn't stretch across the jump)
local function retireTrail(thrownWeaponData: ThrownWeapons.Data)
   local trailObject = thrownWeaponData.TrailObject
   if not trailObject then
      return
   end
   thrownWeaponData.TrailObject = nil
   thrownWeaponData.LastMovementPositions = nil
   if trailObject.Trail then
      trailObject.Trail.Enabled = false
   end
   if trailObject.TrailHost then
      Debris:AddItem(trailObject.TrailHost, GlobalConfig.ThrownWeaponTrailLifetime + 0.2)
   end
end

Boomerang.retireTrail = retireTrail

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
      print(team.TeamColor)
      trail.Color = ColorSequence.new(if team then team.TeamColor.Color else GlobalConfig.EnemyBoomerangTrailColor)
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

-- // True if nothing solid is between the position and the player (the same obstructions the boomerang collides with;
-- // characters are ignored) (T-063)
local function hasLineOfSightToPlayer(player: Player, position: Vector3, thrownWeaponData: ThrownWeapons.Data): boolean
   local character = player.Character
   local rootPart = character and character.PrimaryPart
   if not rootPart then
      return false
   end
   local toPlayer = rootPart.Position - position
   local filter: {Instance} = {Characters, character}
   if thrownWeaponData.Host then
      table.insert(filter, thrownWeaponData.Host)
   end
   local raycastParams = RaycastsUtility.getProjectileObstructionParams(filter)
   return RaycastsUtility.raycastProjectileObstruction(position, toPlayer, toPlayer.Magnitude, raycastParams) == nil
end

-- // CFrame for a flat, horizontal blockcast oriented towards the travel direction
local function getObstructionBlockcastCFrame(rayOrigin: Vector3, direction: Vector3): CFrame
   return CFrame.lookAt(rayOrigin, rayOrigin + direction, UP_VECTOR)
end

local function getWeaponCFrame(thrownWeaponData: ThrownWeapons.Data): CFrame?
   local host = thrownWeaponData.Host
   if host and host.Parent then
      return host:GetPivot()
   end
   return thrownWeaponData.CFrame
end

local function setWeaponCFrame(thrownWeaponData: ThrownWeapons.Data, cframe: CFrame, deltaTime: number?)
   thrownWeaponData.LastPosition = thrownWeaponData.CFrame.Position
   thrownWeaponData.CFrame = cframe
   AuthorityViewLibrary.update(thrownWeaponData.OwnerUserId, thrownWeaponData.ToolId, cframe.Position) -- // Server only (no-op elsewhere)

   local host = thrownWeaponData.Host
   if host and host.Parent then
      if not isServer then
         -- Spin is constant and flat regardless of movement direction, speed, or state
         local visualRotation = (thrownWeaponData.VisualRotation or 0) + (BOOMERANG_SPIN_SPEED * (deltaTime or 0))
         thrownWeaponData.VisualRotation = visualRotation
         -- // RecallTilt: visual tilt while a manual recall drags it up off the ground (set in Boomerang.recall)
         host:PivotTo(CFrame.new(cframe.Position) * (thrownWeaponData.RecallTilt or CFrame.identity) * CFrame.Angles(0, visualRotation, 0))
      else
         host:PivotTo(cframe)
      end
      addTrail(thrownWeaponData)
     -- registerBeamSegment(thrownWeaponData, cframe.Position)
      --addNewBeam(thrownWeaponData)
   end
end

-- // Spawns temporary parts showing the swept blockcast volume and, if any, the hit position; both self-destruct after a frame
local function updateRaycastVisualizers(castCFrame: CFrame, castSize: Vector3, rayDistance: number, result: RaycastResult?)
   if not RAYCAST_VISUALIZERS_ENABLED then
      return
   end

   local sweepLength = castSize.Z + rayDistance
   local sweepPart = Instance.new("Part")
   sweepPart.Name = "BlockcastVisualizer"
   sweepPart.Anchored = true
   sweepPart.CanCollide = false
   sweepPart.CanQuery = false
   sweepPart.CanTouch = false
   sweepPart.Transparency = 0.85
   sweepPart.Color = if result then Color3.fromRGB(255, 0, 0) else Color3.fromRGB(0, 255, 0)
   sweepPart.Size = Vector3.new(castSize.X, castSize.Y, sweepLength)
   sweepPart.CFrame = castCFrame * CFrame.new(0, 0, -sweepLength / 2)
   sweepPart.Parent = workspace
   Debris:AddItem(sweepPart, BLOCKCAST_VISUALIZER_LIFETIME)

   if result then
      local hitPart = Instance.new("Part")
      hitPart.Name = "BlockcastHitVisualizer"
      hitPart.Shape = Enum.PartType.Ball
      hitPart.Anchored = true
      hitPart.CanCollide = false
      hitPart.CanQuery = false
      hitPart.CanTouch = false
      hitPart.Material = Enum.Material.Neon
      hitPart.Color = Color3.fromRGB(255, 0, 0)
      hitPart.Size = Vector3.new(0.5, 0.5, 0.5)
      hitPart.Position = result.Position
      hitPart.Parent = workspace
      Debris:AddItem(hitPart, BLOCKCAST_VISUALIZER_LIFETIME)
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

-- // Sweeping a single flat, horizontal block for obstructions along the boomerang's path
-- The cast origin is pulled back by a skin margin so consecutive frames overlap, preventing tunneling through thin/concave corners
local function blockcastWithHorizontalHitbox(
   rayOrigin: Vector3,
   direction: Vector3,
   rayDistance: number,
   hitboxRadius: number,
   raycastParams: RaycastParams
): RaycastResult?
   rayDistance = math.max(rayDistance, hitboxRadius)

   local castOrigin = rayOrigin - direction * OBSTRUCTION_BLOCKCAST_SKIN
   local castDistance = rayDistance + OBSTRUCTION_BLOCKCAST_SKIN
   local castCFrame = getObstructionBlockcastCFrame(castOrigin, direction)
   local castSize = Vector3.new(hitboxRadius * OBSTRUCTION_BLOCKCAST_WIDTH_SCALE, OBSTRUCTION_BLOCKCAST_HEIGHT, OBSTRUCTION_BLOCKCAST_DEPTH)

   local result = RaycastsUtility.blockcastProjectileObstruction(castCFrame, castSize, direction, castDistance, raycastParams)
   updateRaycastVisualizers(castCFrame, castSize, castDistance, result)
   return result
end

local function spherecastCharacterHitbox(rayOrigin: Vector3, direction: Vector3, rayDistance: number, hitboxRadius: number): {Model}
   if rayDistance <= 0 then
      return {}
   end

   local characterRaycastParams = RaycastParams.new()
   characterRaycastParams.FilterType = Enum.RaycastFilterType.Include
   local hitFilter = {Characters}
   local botsFolder = workspace:FindFirstChild("Bots") -- // bots (e.g. the decoy) live here, not under Characters
   if botsFolder then
      table.insert(hitFilter, botsFolder)
   end
   characterRaycastParams.FilterDescendantsInstances = hitFilter
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
   raycastParams.CollisionGroup = CollisionGroupConstants.Camera
   raycastParams.IgnoreWater = true

   local excludedInstances = filter or {}
   raycastParams.FilterDescendantsInstances = excludedInstances
   for _ = 1, 12 do
      local raycastResult = workspace:Raycast(cameraPosition, direction * distance, raycastParams)
      if not raycastResult then
         return false
      end

      if isFullyVisibleObstruction(raycastResult.Instance) then
         return true
      end

      table.insert(excludedInstances, raycastResult.Instance)
      raycastParams.FilterDescendantsInstances = excludedInstances
   end

   return false
end

local function updateOwnWeaponHighlight(player: Player, thrownWeaponData: ThrownWeapons.Data, position: Vector3, isClashedOrDead: boolean?, fadeOutSeconds: number?)
   if isServer or not ToolController or player ~= Players.LocalPlayer then
      return
   end

   local camera = workspace.CurrentCamera
   local host = thrownWeaponData.Host
   local character = player.Character
   local obstructionFilter = {}
   if character then
      table.insert(obstructionFilter, character)
   end
   if host then
      table.insert(obstructionFilter, host)
   end
   local isObstructed = camera ~= nil and host ~= nil
      and isCameraObstructedToPoint(camera.CFrame.Position, position, obstructionFilter)
      or false
   ToolController.applyHighlight(isObstructed, isClashedOrDead, fadeOutSeconds)
end

local function damagedPlayer(player: Player, boomerangId: string, thrownWeaponData: ThrownWeapons.Data, victimModel: Model): boolean
   -- // Bots (e.g. the decoy) aren't players. Route them to the bot layer, which applies the
   --    behavior's hit rules and eliminates server-side (T-081). No stat crediting for bot kills.
   if victimModel:GetAttribute("BotId") ~= nil then
      if isServer and BotService then
         return BotService.onWeaponHit(player, victimModel)
      end
      return false
   end

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
      -- // A thrown boomerang loses energy for each player it strikes. Server only: the client's prediction keeps a little more
      -- // energy than the server and the server's Returning / Clashed snapshot decides the rest. (A returning boomerang has none.)
      if isServer and thrownWeaponData.Energy and thrownWeaponData.State ~= ThrownWeapons.StateEnum.Returning then
         thrownWeaponData.Energy -= BoomerangTuningLibrary.get(thrownWeaponData.ToolId, "PlayerHitEnergyCost")
      end
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
      task.spawn(AnimationController.playCoreAnimation, player, "Throw")
   end

   local boomerangInstanceId = (options and options.InstanceId) or HttpService:GenerateGUID(false)
   thrownWeaponData.InstanceId = boomerangInstanceId

   local direction = getHorizontalDirection((options and options.Direction) or character.PrimaryPart.CFrame.LookVector)
   local tuningToolId = thrownWeaponData.ToolId or boomerangId
   local defaultSpeed = BoomerangTuningLibrary.get(tuningToolId, "ThrowSpeed") -- // Tools value unless changed with Cmdr (T-054)
   local speed = (options and options.Speed) or defaultSpeed
   local aimStrengthAlpha = math.clamp((options and options.AimStrengthAlpha) or 0, 0, 1)
   if aimStrengthAlpha > 0 and (not options or options.Speed == nil) then
      speed = defaultSpeed * (1 + aimStrengthAlpha * AIM_START_SPEED_BONUS_MULTIPLIER)
   end 
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local isRetuning = false -- // True after a live Cmdr change of ThrowSpeed, until the speed has reached the new value (T-054)
   -- // Energy: MinEnergy for a tap up to MaxEnergy for a full charge (aimStrengthAlpha 0..1, the same charge that drives the aim
   -- // arrow). It drains as the boomerang flies (see simulateStep); at 0 it recalls itself if it can see its player, else dies.
   local minEnergy = BoomerangTuningLibrary.get(tuningToolId, "MinEnergy")
   local maxEnergy = math.max(BoomerangTuningLibrary.get(tuningToolId, "MaxEnergy"), minEnergy)
   thrownWeaponData.Energy = minEnergy + (maxEnergy - minEnergy) * aimStrengthAlpha
   thrownWeaponData.EnergyDepletedHandled = false

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
   local throwServerTime = (options and options.ThrowServerTime) or workspace:GetServerTimeNow()
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
		 local modelName = SkinLibrary.getModelName(player) -- // The thrower's equipped skin
		 if modelName == nil then
			warn("Boomerang: GlobalConfig.ForceEquippedTool is nil; cannot clone thrown weapon model")
			return
		 end

         -- Client creates and monitors the actual 3D model of the projectile
         boomerangModel = ReplicatedStorage.Shared.Assets.Tools[modelName]:Clone()
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
         updateOwnWeaponHighlight(player, thrownWeaponData, pivot.Position)
      end

      -- // Live tuning (T-054): pick up Cmdr changes while the boomerang is in flight
      local tunedSpeed = BoomerangTuningLibrary.get(tuningToolId, "ThrowSpeed")
      if tunedSpeed ~= defaultSpeed then
         defaultSpeed = tunedSpeed
         isRetuning = true
      end
      -- // A clash knocked it onto a new direction (server: Boomerang.clash; clients: the server's Deflected snapshot)
      if thrownWeaponData.PendingDirection then
         direction = thrownWeaponData.PendingDirection
         thrownWeaponData.PendingDirection = nil
      end

      if (thrownWeaponData.Energy or 0) > 0 and (speed > defaultSpeed or isRetuning) then
         local fadeAlpha = math.clamp(deltaTime * AIM_SPEED_FADE_RATE, 0, 1)
         speed = speed + (defaultSpeed - speed) * fadeAlpha
         if isRetuning and math.abs(defaultSpeed - speed) < 0.5 then
            speed = defaultSpeed
            isRetuning = false
         end
      end

      -- // Out of energy: the one decision. A clear line of sight to its player: it returns on its own. None: it dies.
      -- // The server decides both. A client that can see its player predicts the return; one that can't just slows down
      -- // (Exhausted) and waits for the server's verdict (a Returning or Clashed snapshot).
      if (thrownWeaponData.Energy or 0) <= 0 then
         if shouldRecallTransitions and not thrownWeaponData.EnergyDepletedHandled then
            thrownWeaponData.EnergyDepletedHandled = true
            if isServer and WeaponService then
               -- // The end of its flight (Explosive / Teleport boomerang effects fire here)
               WeaponService.WeaponReachedEventPoint:Execute("parallel", player, thrownWeaponData.ToolId, pivot.Position)
            end
            if ThrownWeapons.Data[player] ~= thrownWeaponData then
               return true -- // Removed by an event-point effect (e.g. explosive boomerang)
            end
            if Boomerang.autoRecallOrDie(player, boomerangId, toolData, thrownWeaponData, pivot.Position, direction, speed) then
               return true
            end
         end
         thrownWeaponData.State = ThrownWeapons.StateEnum.Exhausted
         speed = speed - (speed * SLOW_RATE * deltaTime)
         if speed <= .1 then
            return false
         end
      end

      local rayOrigin = pivot.Position
      local dynamicDisplacement = getDynamicDisplacement(rayOrigin, hitboxRadius, deltaTime)
      rayOrigin += dynamicDisplacement

      if isServer and thrownWeaponData.Homing then
         local targetDirection = getNearestEnemyDirection(player, rayOrigin)
         if targetDirection then
            local homingAlpha = math.clamp(HomingBoomerang.HOMING_INFLUENCE * deltaTime, 0, 1)
            direction = getHorizontalDirection(direction:Lerp(targetDirection, homingAlpha))
         end
      end

      -- // T-077 Telekinesis: steer toward the owner's live aim (streamed from the owning client, or predicted
      -- // locally on that client). A gentle bias, not full control. Runs on the server (authoritative) and the
      -- // owner's client (prediction); remote clients never set TelekinesisBias and just follow snapshots.
      if thrownWeaponData.TelekinesisBias then
         local telekinesisInfluence = BoomerangTuningLibrary.getForAnyTool(tuningToolId, "TelekinesisInfluence")
         local telekinesisAlpha = math.clamp(telekinesisInfluence * deltaTime, 0, 1)
         direction = getHorizontalDirection(direction:Lerp(thrownWeaponData.TelekinesisBias, telekinesisAlpha))
      end

      local rayDistance = speed * deltaTime

      -- // Portals: the boomerang passes through and comes out of the paired portal (same on server and client)
      local portalExit = Portal.getProjectileExit(rayOrigin, direction, rayDistance, hitboxRadius, thrownWeaponData.PortalExitAt, thrownWeaponData.PortalExitPart)
      if portalExit then
         direction = portalExit.Direction
         thrownWeaponData.PortalExitAt = os.clock()
         thrownWeaponData.PortalExitPart = portalExit.ExitPart
         if not isServer then
            retireTrail(thrownWeaponData)
            thrownWeaponData.SyncTargetPosition = nil -- // A pre-crossing smoothing target would drag it back toward the entry portal
         end
         setWeaponCFrame(thrownWeaponData, CFrame.new(portalExit.Position), deltaTime)
         -- // Only the part flown before entering costs energy; the jump isn't flight
         thrownWeaponData.Energy = (thrownWeaponData.Energy or 0) - portalExit.EntryDistance * BoomerangTuningLibrary.get(tuningToolId, "EnergyPerStud")
         thrownWeaponData.Direction = direction
         thrownWeaponData.Speed = speed
         return true
      end

      local victimModels = spherecastCharacterHitbox(rayOrigin, direction, rayDistance, hitboxRadius)
      for _, victimModel in ipairs(victimModels) do
         damagedPlayer(player, boomerangId, thrownWeaponData, victimModel)
      end

      --if playerDamaged then
      --  if shouldRecallTransitions then
      --      Boomerang.recall(player, boomerangId, toolData, thrownWeaponData)
      --      return true
      --   end
      --end

      local obstructionRaycastResult = blockcastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams)
      if obstructionRaycastResult then
         if isServer and WeaponService then
            WeaponService.WeaponStruckObject:Execute("parallel", player, thrownWeaponData.ToolId, obstructionRaycastResult)
         end
         thrownWeaponData.Energy = (thrownWeaponData.Energy or 0) - BoomerangTuningLibrary.get(tuningToolId, "BounceEnergyCost")
         local dynamicResponse = getDynamicCollisionResponse(obstructionRaycastResult, direction * speed)
         if dynamicResponse then
            local horizontalResponse = getHorizontalDirection(dynamicResponse)
            direction = horizontalResponse
            speed = math.max(Vector3.new(dynamicResponse.X, 0, dynamicResponse.Z).Magnitude, 0.1)
         else
            direction = direction - 2 * direction:Dot(obstructionRaycastResult.Normal) * obstructionRaycastResult.Normal
            direction = getHorizontalDirection(direction)
         end
         setWeaponCFrame(thrownWeaponData, pivot + dynamicDisplacement, deltaTime)
         SharedTasks.ThrownWeaponHitObject:Execute("parallel", player, thrownWeaponData.ToolId, obstructionRaycastResult.Instance, obstructionRaycastResult.Position)
         thrownWeaponData.Direction = direction
         thrownWeaponData.Speed = speed
         return true
      end

      local currentCFrame = pivot
      setWeaponCFrame(thrownWeaponData, currentCFrame + dynamicDisplacement + direction * rayDistance, deltaTime)
      thrownWeaponData.Energy = (thrownWeaponData.Energy or 0) - rayDistance * BoomerangTuningLibrary.get(tuningToolId, "EnergyPerStud")
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

   if not isServer and ToolController and player == Players.LocalPlayer then
      ToolController.applyHighlight(false, false)
   end

   if returnToPlayer and AnimationController then
      AnimationController.playCoreAnimation(player, "Catch")
   end

   if thrownWeaponData.Host then
      if not shouldReattachLocally then
         thrownWeaponData.Host:Destroy()
      end
   end
   AuthorityViewLibrary.clear(thrownWeaponData.OwnerUserId)
   if isServer then
      fireDespawned(player.UserId, returnToPlayer)
      SharedTasks.ThrownWeaponRemoved:Execute("serial", player, thrownWeaponData.ToolId)
      if returnToPlayer then
         SharedTasks.WeaponReturnedTasks:Execute("parallel", player, thrownWeaponData.ToolId)
      end
   elseif returnToPlayer then
      SoundLibrary.play(thrownWeaponData.InstanceId, Sounds.Data.BoomerangCatch.Name, player.Character)
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

-- // A thrown boomerang that has run out of energy: returns on its own if there is a clear line of sight to its player (one
-- // ray, T-063), otherwise loses momentum and drops into the dead state (the clash path) and must be manually recalled.
-- // Distance from the player plays no part, and this is the only way a thrown boomerang dies.
-- // Only the server decides death: with no line of sight on the client, nothing happens (returns false) and the boomerang
-- // keeps flying until the server's Clashed snapshot arrives (WeaponController.onSnapshot then calls die), so a
-- // disagreement can't leave the client showing a dead boomerang the server is recalling.
function Boomerang.autoRecallOrDie(player: Player, boomerangId: string, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data, position: Vector3, direction: Vector3, speed: number): boolean
   if hasLineOfSightToPlayer(player, position, thrownWeaponData) then
      Boomerang.recall(player, boomerangId, toolData, thrownWeaponData)
      return true
   end
   if not isServer then
      return false
   end
   Boomerang.die(player, thrownWeaponData, {
      Direction = direction,
      Speed = speed,
      Position = position,
   })
   return true
end

-- // Manual recall of a dying (Clashed) or dead boomerang: it becomes a thrown boomerang again and returns.
-- // requiresHold: it keeps returning only while the player holds recall (Boomerang.stopRecallFromDead puts it back).
-- // Server: called from WeaponService on recall press (and by the out-of-bounds failsafe / sliding-away hooks, without hold).
-- // Client: called from WeaponController.onSnapshot when the server's snapshot says it is Returning.
function Boomerang.recallFromClashed(player: Player, clashedWeaponData: ClashedWeapons.Data, requiresHold: boolean)
   if ThrownWeapons.Data[player] or ClashedWeapons.Data[player] ~= clashedWeaponData then
      return
   end
   local toolData = Tools[clashedWeaponData.ToolId]
   if not toolData or not toolData.Boomerang then
      return
   end
   local host = clashedWeaponData.Host
   local pivot = if host and host.Parent then host:GetPivot() else clashedWeaponData.CFrame
   if not pivot then
      return
   end

   if clashedWeaponData.MovementConnection then
      clashedWeaponData.MovementConnection:Disconnect()
      clashedWeaponData.MovementConnection = nil
   end

   local thrownWeaponData: ThrownWeapons.Data = {
      ToolId = clashedWeaponData.ToolId,
      State = ThrownWeapons.StateEnum.Exhausted, -- // recall() switches it to Returning
      InstanceId = clashedWeaponData.InstanceId,
      OwnerUserId = clashedWeaponData.OwnerUserId,
      Host = host,
      LastPosition = pivot.Position,
      CFrame = pivot,
      Direction = clashedWeaponData.Direction,
      Speed = 0,
      ReuseEquippedHost = clashedWeaponData.ReuseEquippedHost,
      ExistingHost = clashedWeaponData.ExistingHost,
      VisualRotation = clashedWeaponData.VisualRotation,
      RecallFromDead = requiresHold,
   } :: any

   ClashedWeapons.Data[player] = nil
   ThrownWeapons.Data[player] = thrownWeaponData

   if not isServer and host and host.PrimaryPart then
      SoundLibrary.play(thrownWeaponData.InstanceId, Sounds.Data.BoomerangLoop.Name, host.PrimaryPart, nil, true)
   end

   Boomerang.recall(player, thrownWeaponData.ToolId, toolData, thrownWeaponData, { InitialSpeed = 0 })
end

-- // Recall button released while recalling a boomerang that was dead: it loses momentum and drops again (server only;
-- // clients follow the Clashed snapshot). Ignored for boomerangs that weren't recalled from the dead state.
function Boomerang.stopRecallFromDead(player: Player, thrownWeaponData: ThrownWeapons.Data)
   if not isServer or not thrownWeaponData.RecallFromDead or thrownWeaponData.State ~= ThrownWeapons.StateEnum.Returning then
      return
   end
   if ThrownWeapons.Data[player] ~= thrownWeaponData then
      return
   end
   local direction = thrownWeaponData.Direction
   if not direction or direction.Magnitude < 1e-5 then
      direction = Vector3.new(0, 0, -1)
   end
   Boomerang.die(player, thrownWeaponData, {
      Direction = direction,
      Speed = thrownWeaponData.Speed or 0,
   })
end

-- // Two thrown boomerangs struck each other mid-air (server only: ClashService > WeaponService.clashWeapon). It costs
-- // ClashEnergyCost and knocks the boomerang away along options.Direction; it does NOT kill it. If that was the last of its
-- // energy, the usual 0-energy decision (recall or die) follows on its next step. A returning boomerang isn't affected: it
-- // has no energy left to lose. Clients learn of the new direction from the Deflected snapshot (Boomerang.deflect).
function Boomerang.clash(player: Player, thrownWeaponData: ThrownWeapons.Data, options: ClashInitOptions)
   if not isServer or ThrownWeapons.Data[player] ~= thrownWeaponData then
      return
   end
   if thrownWeaponData.State == ThrownWeapons.StateEnum.Returning or thrownWeaponData.Energy == nil then
      return
   end
   if not getWeaponCFrame(thrownWeaponData) then
      return
   end

   local newDirection = getHorizontalDirection(options.Direction)
   thrownWeaponData.Energy -= BoomerangTuningLibrary.get(thrownWeaponData.ToolId, "ClashEnergyCost")
   thrownWeaponData.PendingDirection = newDirection

   -- // Snapshots are unreliable, so the event is sent a few times; the client applies the same direction each time
   local function sendDeflection()
      if ThrownWeapons.Data[player] ~= thrownWeaponData then
         return
      end
      local pivot = getWeaponCFrame(thrownWeaponData)
      if pivot then
         fireSnapshot(player.UserId, pivot.Position, newDirection, thrownWeaponData.Speed or 0, ThrownWeapons.StateEnum.Deflected)
      end
   end
   sendDeflection()
   task.delay(0.05, sendDeflection)
   task.delay(0.1, sendDeflection)
end

-- // Client: the server's Deflected snapshot (the boomerang clashed with another): fly off in the direction it says
function Boomerang.deflect(player: Player, thrownWeaponData: ThrownWeapons.Data, direction: Vector3)
   if ThrownWeapons.Data[player] ~= thrownWeaponData or thrownWeaponData.State == ThrownWeapons.StateEnum.Returning then
      return
   end
   thrownWeaponData.PendingDirection = getHorizontalDirection(direction)
end

-- // A thrown boomerang dies: it loses its flight and drops into the dying/dead state (Clashed.luau)
function Boomerang.die(player: Player, thrownWeaponData: ThrownWeapons.Data, options: ClashInitOptions)
   if ClashedWeapons.Data[player] then
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

   if thrownWeaponData.TrailObject then
      if thrownWeaponData.TrailObject.TrailHost and thrownWeaponData.TrailObject.TrailHost.Parent then
         thrownWeaponData.TrailObject.TrailHost:Destroy()
      end
      thrownWeaponData.TrailObject = nil
   end

   local clashedWeaponData = {
      OwnerUserId = thrownWeaponData.OwnerUserId,
      ToolId = thrownWeaponData.ToolId,
      State = ClashedWeapons.StateEnum.Clashed,
      InstanceId = thrownWeaponData.InstanceId,
      Host = thrownWeaponData.Host,
      LastPosition = thrownWeaponData.LastPosition,
      CFrame = pivot,
      Direction = direction,
      Speed = speed,
      ReuseEquippedHost = thrownWeaponData.ReuseEquippedHost,
      ExistingHost = thrownWeaponData.ExistingHost,
      VisualRotation = thrownWeaponData.VisualRotation,
   }

   thrownWeaponData.Host = nil
   ThrownWeapons.Data[player] = nil
   ClashedWeapons.Data[player] = clashedWeaponData

   ClashedWeaponLogic.applyClash(player, clashedWeaponData, {
      Direction = direction,
      Speed = speed,
      Position = options.Position,
   })
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
      or ClashedWeapons.Data[player] ~= nil
   then
      return
   end

   thrownWeaponData.State = ThrownWeapons.StateEnum.Returning
   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end

   local tuningToolId = thrownWeaponData.ToolId or boomerangId
   -- // Explosive boomerang returns faster while its effect is active (effect state is replicated, so both sides agree)
   local returnSpeedMultiplier = if PickupLibrary.hasPickupEffectActive(player.UserId, "ExplosiveBoomerang") then GlobalConfig.ExplosiveBoomerangReturnSpeedMultiplier else 1
   -- // Held manual recall of a dying/dead boomerang: capped speed and heavy momentum
   local isManualRecallFromDead = thrownWeaponData.RecallFromDead == true
   local liftRate = if isManualRecallFromDead then GlobalConfig.ManualRecallLiftRate else RECALL_FROM_DEAD_LIFT_RATE
   local maximumSpeed, momentumMultiplier = 0, 1
   local rampSeconds, rampPower = GlobalConfig.ManualRecallRampSeconds, GlobalConfig.ManualRecallRampPower
   local rampElapsed = 0 -- // Seconds since this recall started (drives the manual recall's speed-up curve)
   -- // Tools/GlobalConfig values unless changed with Cmdr; re-read every frame so live changes apply mid-recall (T-054)
   local function updateRecallTuning()
      if isManualRecallFromDead then
         maximumSpeed = BoomerangTuningLibrary.get(tuningToolId, "RecallSpeed") * returnSpeedMultiplier
         momentumMultiplier = BoomerangTuningLibrary.get(tuningToolId, "RecallAcceleration")
         rampSeconds = math.max(BoomerangTuningLibrary.get(tuningToolId, "RecallRampTime"), 0.01)
         rampPower = BoomerangTuningLibrary.get(tuningToolId, "RecallRampPower")
      else
         maximumSpeed = BoomerangTuningLibrary.get(tuningToolId, "ThrowSpeed") * returnSpeedMultiplier
         momentumMultiplier = 1
      end
   end
   updateRecallTuning()
   local speed = math.max((options and options.InitialSpeed) or 0, thrownWeaponData.Speed or 0)
   local slideSpeed = 0
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local catchRadius = math.max(RECALL_CATCH_RADIUS_MIN, hitboxRadius * 1.25) + (if isServer then SERVER_RECALL_CATCH_BONUS else 0)
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

      updateRecallTuning()
      rampElapsed += deltaTime

      -- // Prioritize movement towards the player
      local hostPivot = getWeaponCFrame(thrownWeaponData)
      if not hostPivot then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
         return
      end

      -- // Recalled off the ground: rise smoothly to hand height while returning
      if thrownWeaponData.RecallFromDead ~= nil then
         local heightDelta = rootPart.Position.Y - hostPivot.Position.Y
         if math.abs(heightDelta) > 0.05 then
            hostPivot += Vector3.new(0, heightDelta * math.clamp(deltaTime * liftRate, 0, 1), 0)
         end

         -- // Visual only: tilt up toward the player while still being dragged up, easing flat as it reaches hand height
         if not isServer and isManualRecallFromDead then
            -- // The tilt is exactly 0 once the lift stops (the lift above stops within 0.05 studs of hand height)
            local remainingRise = math.max(rootPart.Position.Y - hostPivot.Position.Y, 0)
            local riseAlpha = math.clamp((remainingRise - 0.05) / (MANUAL_RECALL_TILT_HEIGHT - 0.05), 0, 1)
            local targetTilt = math.rad(GlobalConfig.ManualRecallMaxTiltDegrees) * riseAlpha * riseAlpha * (3 - 2 * riseAlpha) -- // smoothstep
            local currentTilt = thrownWeaponData.RecallTiltAngle or 0
            if targetTilt < currentTilt then
               currentTilt = targetTilt -- // Leveling out follows the rise directly (no lag), so it's flat by the peak
            else
               currentTilt += (targetTilt - currentTilt) * (1 - math.exp(-MANUAL_RECALL_TILT_RESPONSE * deltaTime)) -- // Tilting in eases
            end
            thrownWeaponData.RecallTiltAngle = currentTilt
            local towardPlayer = getHorizontalDirection(rootPart.Position - hostPivot.Position)
            local tiltAxis = UP_VECTOR:Cross(towardPlayer)
            -- // Negative angle about (up x towardPlayer) raises the side facing the player
            thrownWeaponData.RecallTilt = if tiltAxis.Magnitude > 1e-4 and currentTilt > 1e-3 then CFrame.fromAxisAngle(tiltAxis.Unit, -currentTilt) else nil
         end
      end

      -- // Leaving the dead state into a manual recall: the dead highlight fades away slowly, matching the sluggish lift
      updateOwnWeaponHighlight(player, thrownWeaponData, hostPivot.Position, nil, if isManualRecallFromDead then GlobalConfig.ManualRecallHighlightFadeOutSeconds else nil)

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
      local transitionRate = (if alignment < -0.25 then 11 elseif alignment < 0.5 then 8 else 5) * momentumMultiplier
      local transitionAlpha = 1 - math.exp(-transitionRate * deltaTime)

      -- // Split the velocity into the part heading at the player and the sideways part. The forward part builds up at
      -- // the normal (momentum-scaled) rate. The sideways part is what makes it circle the player, so it's removed at
      -- // least fast enough to close in: a turn rate of speed/distance is exactly a circle around the player, so
      -- // RETURN_STEER_TIGHTNESS times that always spirals inward, even if the player runs in circles (T-073).
      -- // Far away this changes nothing (the normal rate is already higher); it only tightens the turn up close.
      local forwardSpeed = travelVelocity:Dot(targetDirection)
      local sidewaysVelocity = travelVelocity - targetDirection * forwardSpeed
      if isManualRecallFromDead then
         -- // Manual recall: visibly slow at first, then a steep surge up to full speed (convex curve over time, not a lag toward max)
         local rampAlpha = math.clamp(rampElapsed / rampSeconds, 0, 1)
         local startFraction = GlobalConfig.ManualRecallRampStartFraction
         forwardSpeed = maximumSpeed * (startFraction + (1 - startFraction) * rampAlpha ^ rampPower)
      else
         forwardSpeed += (maximumSpeed - forwardSpeed) * transitionAlpha
      end
      local steerRate = math.max(transitionRate, RETURN_STEER_TIGHTNESS * travelVelocity.Magnitude / math.max(horizontalDistance, catchRadius))
      sidewaysVelocity *= math.exp(-steerRate * deltaTime)
      travelVelocity = targetDirection * forwardSpeed + sidewaysVelocity

      local velocityMagnitude = travelVelocity.Magnitude
      speed = math.clamp(velocityMagnitude, 0, maximumSpeed)
      local direction = if velocityMagnitude > 1e-5 then getHorizontalDirection(travelVelocity.Unit) else targetDirection

      -- // Raycast in that direction for an obstruction
      local rayOrigin = hostPivot.Position
      local dynamicDisplacement = getDynamicDisplacement(rayOrigin, hitboxRadius, deltaTime)
      rayOrigin += dynamicDisplacement
      local rayDistance = (math.max(speed, hitboxRadius)) * deltaTime
      local raycastResult = blockcastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams)
      local sliding = false

      -- // If we hit something, adjust movement direction to move perpendicular to the obstruction
      if raycastResult and raycastResult.Instance then
         local incomingVelocity = direction * speed
         if isServer and WeaponService then
            WeaponService.WeaponStruckObject:Execute("parallel", player, thrownWeaponData.ToolId, raycastResult)
         end
         sliding = true
         speed = 0
         slideMomentum = 1

         -- Determine new movement direction adjacent to the obstructing surface
         -- Prioritize whichever direction brings the boomerang closer to the player
         local normal = raycastResult.Normal
         local dynamicResponse = getDynamicCollisionResponse(raycastResult, incomingVelocity)
         if dynamicResponse then
            local horizontalResponse = Vector3.new(dynamicResponse.X, 0, dynamicResponse.Z)
            if horizontalResponse.Magnitude > 0.01 then
               direction = horizontalResponse.Unit
               speed = horizontalResponse.Magnitude
               sliding = false
               slideMomentum = 0
            end
         end

         slideDirection = direction - normal * direction:Dot(normal)
         local slideMagnitude = slideDirection.Magnitude

         if slideMagnitude < 0.01 then
            -- A near head-on hit against a convex corner's tip gives a degenerate (near-zero) tangent
            -- off the normal; fall back to the tangents of the travel direction itself so the
            -- boomerang isn't stuck forever waiting on a usable slide direction
            local rightTangent = direction:Cross(UP_VECTOR).Unit
            local rightBlocked = blockcastWithHorizontalHitbox(rayOrigin, rightTangent, rayDistance, hitboxRadius*.5, raycastParams)
            local leftBlocked = blockcastWithHorizontalHitbox(rayOrigin, -rightTangent, rayDistance, hitboxRadius*.5, raycastParams)

            if not rightBlocked then
               slideDirection = rightTangent
            elseif not leftBlocked then
               slideDirection = -rightTangent
            else
               speed = 0
               return
            end
            slideMagnitude = 1
         else
            slideDirection = slideDirection.Unit
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
         local slideHit = blockcastWithHorizontalHitbox(rayOrigin, slideDirection, rayDistance, hitboxRadius*.5, raycastParams)

         if slideHit and not slideHit.Instance:IsDescendantOf(Characters) then
            -- The chosen slide direction is itself obstructed (common at convex corners); try the
            -- opposite tangent instead of getting stuck
            slideDirection = -slideDirection
            slideHit = blockcastWithHorizontalHitbox(rayOrigin, slideDirection, rayDistance, hitboxRadius*.5, raycastParams)

            if slideHit and not slideHit.Instance:IsDescendantOf(Characters) then
               speed = 0
               return
            end
         end

         setWeaponCFrame(thrownWeaponData, hostPivot + dynamicDisplacement + slideDirection * slideDistance, deltaTime)
         travelVelocity = slideDirection * slideSpeed
      else
         slideMomentum = math.clamp(slideMomentum - (deltaTime * 10), 0, 1)
         local blendedDirection = slideDirection * slideMomentum + direction * (1 - slideMomentum)
         blendedDirection = blendedDirection.Unit
         local blendedSpeed = slideSpeed * slideMomentum + speed * (1 - slideMomentum)
         local blendedDistance = math.min(blendedSpeed * deltaTime, horizontalDistance)

         -- blendedDirection can diverge from the already-tested `direction` while momentum decays;
         -- re-check it so the boomerang can't clip into a corner along the untested blend
         local blendedObstruction = blockcastWithHorizontalHitbox(rayOrigin, blendedDirection, blendedDistance, hitboxRadius, raycastParams)
         if blendedObstruction then
            blendedDistance = math.max((blendedObstruction.Position - rayOrigin).Magnitude - hitboxRadius, 0)
            blendedSpeed = 0
            slideMomentum = 0
         end

         slideSpeed = math.max(speed, slideSpeed * slideMomentum)
         setWeaponCFrame(thrownWeaponData, hostPivot + dynamicDisplacement + blendedDirection * blendedDistance, deltaTime)
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

-- // Hook: a dying boomerang that keeps sliding with nothing to land on returns on its own (T-062; Clashed.luau can't require this module)
ClashedWeaponLogic.onSlidingAway = function(player: Player, clashedWeaponData: ClashedWeapons.Data)
   Boomerang.recallFromClashed(player, clashedWeaponData, false)
end

return Boomerang
