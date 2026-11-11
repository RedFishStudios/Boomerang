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
local ThrowTargetLibrary = require(ReplicatedStorage.Shared.Library.ThrowTargetLibrary)
local BoomerangCurveLibrary = require(ReplicatedStorage.Shared.Library.BoomerangCurveLibrary)
local ObstructionCastLibrary = require(ReplicatedStorage.Shared.Library.ObstructionCastLibrary)
local LagCompensationLibrary = require(ReplicatedStorage.Shared.Library.LagCompensationLibrary)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local BoomerangColorUtil = require(ReplicatedStorage.Shared.Utils.BoomerangColorUtil)
local FanTrails = require(ReplicatedStorage.Shared.Utils.FanTrails)
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
local Telekinesis = require(ReplicatedStorage.Shared.Logics.PickupLogics.Telekinesis)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local Portal = require(ReplicatedStorage.Shared.Logics.Environment.Portal)
local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)
local DeadWeaponLogic = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Dead)
local CatchLibrary = require(ReplicatedStorage.Shared.Library.CatchLibrary)
local BoomerangDebugLibrary = require(ReplicatedStorage.Shared.Library.BoomerangDebugLibrary)
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
local REPLICATION_RATE = 1 / 30 -- // Seconds between snapshots (bounces, portals, recalls and clashes also send one immediately)
local FIXED_STEP = 1 / 60 -- // Fixed simulation step (seconds), identical on server and clients
local MAX_STEPS_PER_FRAME = 4 -- // Max steps per frame after a hitch; remaining time is dropped
local MAX_SPAWN_CATCHUP = 0.35 -- // Max seconds a new boomerang is eased forward to the server's position
local AIM_START_SPEED_BONUS_MULTIPLIER = 1.0
local AIM_SPEED_FADE_RATE = 2.0
local RECALL_CATCH_RADIUS_MIN = 1.5
-- // Extra server-only catch radius so server and client agree on catches (the server could otherwise orbit just
-- // outside the client's radius)
local SERVER_RECALL_CATCH_BONUS = 0.5
local PENDING_CATCH_TIMEOUT = 1.5 -- // Seconds a client waits for the server to confirm a predicted catch
local RELEASE_CATCH_GRACE_STUDS = 1 -- // Studs: a manual recall released this close to being caught (plus ping distance) counts as caught
local RELEASE_CATCH_GRACE_MAX_PING = 0.3 -- // Max owner ping (seconds) used for that grace distance

-- // Forward-declared; defined in CATCHING
local setHostHidden: (thrownWeaponData: ThrownWeapons.Data, hidden: boolean) -> ()
local catchWeapon: (player: Player, thrownWeaponData: ThrownWeapons.Data) -> boolean
local RETURN_STEER_TIGHTNESS = 3 -- // Up-close turn sharpness of a returning boomerang (1 = circles the player; higher = more direct)
local DEATH_SPEED_SCALE = 0.5
local DEATH_MINIMUM_SPEED = 12
local OBSTRUCTION_BLOCKCAST_SKIN = ObstructionCastLibrary.BLOCKCAST_SKIN
local BLOCKCAST_VISUALIZER_LIFETIME = 0.05
local RECALL_BOUNCE_MIN_SPEED_FRACTION = 0.5 -- // Min fraction of max recall speed a returning boomerang keeps after a bounce
local LOS_VISUALIZER_LIFETIME = 3 -- // Seconds a line-of-sight cast stays drawn

local WEAPON_UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable
local WEAPON_RAYCAST_COLLISION_GROUP = CollisionGroupConstants.ThrownWeapons

local SPAWN_PACKET_SIZE = 8 + 12 + 12 + 4 + 8 + 4 -- // ... + the curvature
local DESPAWN_PACKET_SIZE = 8 + 1
local SNAPSHOT_PACKET_SIZE = 1 + 8 + 12 + 12 + 4 + 1 + 8 + 12 + 4 + 4 -- // ... + thrower position + curvature + recall distance flown (Dead.luau snapshots omit these)
local RETURN_PREDICTION_STEP = 1 / 60 -- // Seconds per step when replaying a returning boomerang to catch a snapshot up
local raycastVisualizersEnabled = GlobalConfig.RaycastVisualizersEnabled -- // Server: draws each hit sweep; Cmdr `viewhitbox` toggles it live
local projectileVisualizerEnabled = GlobalConfig.ProjectileHitboxVisualizerEnabled -- // Server only: Cmdr `toggleprojectilevisualizer` toggles it; read when a boomerang is thrown

-- ============================================================================================================================
-- INTERNAL CONFIG (manual recall of a dead boomerang)
-- ============================================================================================================================
-- // Seconds for a manual recall to go from rest to full speed and spin (Cmdr `tune RecallAcceleration` divides it)
local MANUAL_RECALL_FULL_SPEED_SECONDS = 0.2
-- // If true, the timed rise during flight (GlobalConfig.ManualRecallRiseSeconds, with tilt toward the player) also
-- // runs; the recall charge normally lifts the boomerang (Dead.luau)
local MANUAL_RECALL_RISES_DURING_FLIGHT = false

local BOOMERANG_SPIN_SPEED = math.rad(1080)
local RECALL_FROM_DEAD_LIFT_RATE = 8 -- // UNUSED. Rise rate of an automatic recall off the ground
local MANUAL_RECALL_TILT_HEIGHT = 2 -- // Studs of remaining rise at which the recall tilt is maximal
local MANUAL_RECALL_TILT_RESPONSE = 6 -- // How quickly the tilt eases to its target

type ThrowInitOptions = {
   StartPosition: Vector3?,
   Direction: Vector3?,
   Speed: number?,
   InstanceId: string?,
   ThrowServerTime: number?,
   TimeSinceAiming: number?,
   AimStrengthAlpha: number?,
   ExistingHost: Model?,
   TargetPosition: Vector3?, -- // Server: point the player aimed at (clamped); sets how far ahead the curve crosses the aim line
   ClickedTarget: (number | string)?, -- // Server: enemy the PC client reports as clicked (UserId or BotId)
   Curvature: number?, -- // Client: curve decided by the server, from the spawn event
}

type RecallInitOptions = {
   InitialSpeed: number?
}

type RemoveFromFieldOptions = {
   ReturnToPlayer: boolean?
}

-- // A mid-air clash with another boomerang (Boomerang.clash)
type ClashInitOptions = {
   Direction: Vector3,
   Speed: number?,
   Position: Vector3?,
}

-- // A boomerang dying (Boomerang.die)
type DieInitOptions = {
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

   -- // Decoys and other bots count, except the thrower's own or an ally's (ThrowTargetLibrary)
   for _, botRoot in ThrowTargetLibrary.getEnemyBotRoots(player) do
      local toTarget = Vector3.new(botRoot.Position.X - position.X, 0, botRoot.Position.Z - position.Z)
      local distance = toTarget.Magnitude
      if distance > 1e-5 and distance < nearestDistance then
         nearestDistance = distance
         nearestDirection = toTarget.Unit
      end
   end

   return nearestDirection
end

-- // Rotate the trail to match movement so it leaves a full-width streak
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

	-- Perpendicular to the movement: the trail's width direction.
	local perpendicular = Vector3.new(-movement.Z, 0, movement.X)

	-- Position the attachments on either side of the object.
	local width = 1

	thrownWeaponData.TrailObject.Attachment0.Position = perpendicular * -width
	thrownWeaponData.TrailObject.Attachment1.Position = perpendicular * width
end

-- // Skin decorative trail (FanTrails, Skins.TrailStyle), drawn on top of the owner-coloured trail. Client only.
-- // It follows the TrailHost (the drawn position, not the spinning model), so addTrail moves it to each new TrailHost.
local FAN_TRAIL_MAX_FADE = 3 -- // Seconds a stopped fan trail may keep fading before it's destroyed anyway

local function startFanTrail(thrownWeaponData: ThrownWeapons.Data, trailHost: BasePart)
   local fanTrail = thrownWeaponData.FanTrail
   if fanTrail then
      fanTrail:SetWeapon(trailHost)
      fanTrail:Start() -- // After a teleport, Start clears the old path instead of joining it to the new position
      return
   end
   local ownerPlayer = Players:GetPlayerByUserId(thrownWeaponData.OwnerUserId)
   local skin = ownerPlayer and SkinLibrary.getSkin(SkinLibrary.getEquippedSkinId(ownerPlayer))
   local styleName = skin and skin.TrailStyle
   local host = thrownWeaponData.Host
   if not styleName or not host then
      return
   end
   fanTrail = FanTrails.new(trailHost, styleName, { Span = FanTrails.measureSpan(host) })
   thrownWeaponData.FanTrail = fanTrail
   fanTrail:Start()
end

-- // The throw is over (caught, removed, died): stop adding to the fan trail and destroy it once it has faded
local function finishFanTrail(thrownWeaponData: ThrownWeapons.Data)
   local fanTrail = thrownWeaponData.FanTrail
   if not fanTrail then
      return
   end
   thrownWeaponData.FanTrail = nil
   fanTrail:Stop()
   task.spawn(function()
      local giveUpAt = os.clock() + FAN_TRAIL_MAX_FADE
      while fanTrail:IsBusy() and os.clock() < giveUpAt do
         task.wait(0.25)
      end
      fanTrail:Destroy()
   end)
end

Boomerang.finishFanTrail = finishFanTrail

-- // Detach the current trail so it fades over its Lifetime and let addTrail start a new one (used on teleports so it
-- // doesn't stretch)
local function retireTrail(thrownWeaponData: ThrownWeapons.Data)
   if thrownWeaponData.FanTrail then
      thrownWeaponData.FanTrail:Stop()
   end
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
local getVisualYOffset: (thrownWeaponData: ThrownWeapons.Data) -> number -- // Defined below

-- // Where the boomerang is drawn: physics position plus getVisualYOffset. The trail follows this.
local function getDrawnPosition(thrownWeaponData: ThrownWeapons.Data): Vector3
   return thrownWeaponData.CFrame.Position + Vector3.new(0, getVisualYOffset(thrownWeaponData), 0)
end

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
      thrownWeaponData.TrailObject.TrailHost:PivotTo(CFrame.new(getDrawnPosition(thrownWeaponData)))
      updateTrailOrientation(thrownWeaponData)
      -- // A predicted catch the server turned down: the boomerang shows again, so its fan trail resumes
      local fanTrail = thrownWeaponData.FanTrail
      if fanTrail and not fanTrail.emitting and not thrownWeaponData.HostHidden then
         startFanTrail(thrownWeaponData, thrownWeaponData.TrailObject.TrailHost)
      end
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
   trailHost:PivotTo(CFrame.new(getDrawnPosition(thrownWeaponData)))

   local attachment0 = Instance.new("Attachment")
   attachment0.Parent = trailHost

   local attachment1 = Instance.new("Attachment")
   attachment1.Parent = trailHost

   local trail = Instance.new("Trail")
   trail.Attachment0 = attachment0
   trail.Attachment1 = attachment1
   trail.Parent = trailHost

   -- // Same color rule as the recall SelectionRing (BoomerangColorUtil)
   local ownerPlayer = game.Players:GetPlayerByUserId(thrownWeaponData.OwnerUserId)
   trail.Color = ColorSequence.new(BoomerangColorUtil.getColor(ownerPlayer))

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
   if not thrownWeaponData.HostHidden then -- // Hidden while a predicted catch waits for the server: no new fan trail
      startFanTrail(thrownWeaponData, trailHost)
   end

	updateTrailOrientation(thrownWeaponData)
end

-- // Get distance between two points flattened on the Y axis
local function getHorizontalDistance(fromPosition: Vector3, toPosition: Vector3): number
   local delta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
   return delta.Magnitude
end

-- // CFrame for a flat, horizontal blockcast oriented towards the travel direction
local function getObstructionBlockcastCFrame(rayOrigin: Vector3, direction: Vector3): CFrame
   return ObstructionCastLibrary.getCastCFrame(rayOrigin, direction)
end

-- // Flat block used by all obstruction casts (flight bounces, line of sight); height is
-- // GlobalConfig.BoomerangRaycastHeight (Cmdr `setboomerangcastheight`)
local function getObstructionCastSize(hitboxRadius: number): Vector3
   return ObstructionCastLibrary.getCastSize(hitboxRadius)
end

-- // Part standing for a player's position in line-of-sight checks: their replicated Hitbox (HitboxService), else the
-- // HumanoidRootPart
local function getPlayerTargetPart(character: Model): BasePart?
   local hitbox = character:FindFirstChild("Hitbox")
   if hitbox and hitbox:IsA("BasePart") then
      return hitbox
   end
   local rootPart = character:FindFirstChild("HumanoidRootPart")
   return if rootPart and rootPart:IsA("BasePart") then rootPart else nil
end

-- // Server only. Draws a line-of-sight cast for a few seconds (green = clear, red = blocked, plus hit marker); Cmdr
-- // `togglelosvisualizer`
local function visualizeLineOfSight(castCFrame: CFrame, castSize: Vector3, castDistance: number, result: RaycastResult?)
   if not isServer or not ObstructionCastLibrary.isLosVisualizerEnabled() then
      return
   end

   local sweepLength = castSize.Z + castDistance
   local sweepPart = Instance.new("Part")
   sweepPart.Name = "LineOfSightVisualizer"
   sweepPart.Anchored = true
   sweepPart.CanCollide = false
   sweepPart.CanQuery = false
   sweepPart.CanTouch = false
   sweepPart.CastShadow = false
   sweepPart.Material = Enum.Material.Neon
   sweepPart.Transparency = 0.6
   sweepPart.Color = if result then Color3.fromRGB(255, 0, 0) else Color3.fromRGB(0, 255, 0)
   sweepPart.Size = Vector3.new(castSize.X, castSize.Y, sweepLength)
   sweepPart.CFrame = castCFrame * CFrame.new(0, 0, -sweepLength / 2 + castSize.Z / 2)
   sweepPart.Parent = workspace
   Debris:AddItem(sweepPart, LOS_VISUALIZER_LIFETIME)

   if result then
      local hitPart = Instance.new("Part")
      hitPart.Name = "LineOfSightHitVisualizer"
      hitPart.Shape = Enum.PartType.Ball
      hitPart.Anchored = true
      hitPart.CanCollide = false
      hitPart.CanQuery = false
      hitPart.CanTouch = false
      hitPart.Material = Enum.Material.Neon
      hitPart.Color = Color3.fromRGB(255, 0, 0)
      hitPart.Size = Vector3.new(1, 1, 1)
      hitPart.Position = result.Position
      hitPart.Parent = workspace
      Debris:AddItem(hitPart, LOS_VISUALIZER_LIFETIME)
   end
end

-- // True if a flat block swept from the boomerang to the player's Hitbox, at the boomerang's height, is unobstructed
-- // (characters ignored). Same on client and server.
local function hasLineOfSightToPlayer(player: Player, position: Vector3, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data, skipVisualizer: boolean?): boolean
   if BoomerangDebugLibrary.get("NoReturn") >= 1 then
      return false -- // Dev testing (Cmdr `boomerangdebug noreturn 1`): always die
   end
   local character = player.Character
   local targetPart = character and getPlayerTargetPart(character)
   if not character or not targetPart then
      return false
   end

   -- // Flatten to the boomerang's height (top-down check against walls)
   local targetPosition = targetPart.Position
   local toPlayer = Vector3.new(targetPosition.X - position.X, 0, targetPosition.Z - position.Z)
   local distance = toPlayer.Magnitude
   if distance <= 1e-3 then
      return true
   end
   local direction = toPlayer / distance

   local filter: {Instance} = {Characters, character}
   if thrownWeaponData.Host then
      table.insert(filter, thrownWeaponData.Host)
   end
   local raycastParams = RaycastsUtility.getProjectileObstructionParams(filter)

   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local castSize = getObstructionCastSize(hitboxRadius)
   local castCFrame = getObstructionBlockcastCFrame(position, direction)
   local result = RaycastsUtility.blockcastProjectileObstruction(castCFrame, castSize, direction, distance, raycastParams)
   if not skipVisualizer then
      visualizeLineOfSight(castCFrame, castSize, distance, result)
   end
   return result == nil
end

-- // True if in sight and within GlobalConfig.DyingBoomerangRecallDistance (horizontal) of the player: lets a dying
-- // boomerang resume its recall. No visualizer (runs often).
local function isPlayerInRecallReach(player: Player, position: Vector3, toolData: Tools.Tool, weaponData: any): boolean
   local character = player.Character
   local targetPart = character and getPlayerTargetPart(character)
   if not targetPart then
      return false
   end
   local targetPosition = targetPart.Position
   local horizontalOffset = Vector3.new(targetPosition.X - position.X, 0, targetPosition.Z - position.Z)
   if horizontalOffset.Magnitude > GlobalConfig.DyingBoomerangRecallDistance then
      return false
   end
   return hasLineOfSightToPlayer(player, position, toolData, weaponData, true)
end

-- // Server only. Called before dying: true if it would resume its recall now or during the slide it is about to make
-- // (predicted over DyingBoomerangRecallLookaheadSeconds); then it never dies.
local function canAvoidDying(player: Player, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data, position: Vector3, direction: Vector3, speed: number): boolean
   if not isServer then
      return false
   end
   if isPlayerInRecallReach(player, position, toolData, thrownWeaponData) then
      return true
   end
   local stepSeconds = GlobalConfig.DyingBoomerangRecallCheckSeconds
   local predicted = DeadWeaponLogic.predictSlidePositions(
      position, direction, speed, thrownWeaponData.Host, thrownWeaponData.ToolId,
      GlobalConfig.DyingBoomerangRecallLookaheadSeconds, stepSeconds
   )
   for _, predictedPosition in ipairs(predicted) do
      if isPlayerInRecallReach(player, predictedPosition, toolData, thrownWeaponData) then
         return true
      end
   end
   return false
end

local function getWeaponCFrame(thrownWeaponData: ThrownWeapons.Data): CFrame?
   local host = thrownWeaponData.Host
   if host and host.Parent then
      -- // Client: the simulated position is thrownWeaponData.CFrame; the host model is only drawn from it
      -- // (interpolated), never the source of truth
      if not isServer and thrownWeaponData.CFrame then
         return thrownWeaponData.CFrame
      end
      return host:GetPivot()
   end
   return thrownWeaponData.CFrame
end

-- // Client drawing only: height offset (+/-) of the drawn boomerang from its physics height. Starts at the thrower's
-- // height and eases to 0 within GlobalConfig.BoomerangVisualHeightSyncSeconds.
getVisualYOffset = function(thrownWeaponData: ThrownWeapons.Data): number
   local startOffset = thrownWeaponData.VisualYOffset
   local startedAt = thrownWeaponData.VisualYOffsetStartedAt
   if not startOffset or not startedAt then
      return 0
   end
   -- // Ground approach: a manual recall's drawn height rises with distance flown (smoothstep)
   if thrownWeaponData.VisualYOffsetByDistance then
      local riseAlpha = math.clamp((thrownWeaponData.RecallTravelled or 0) / math.max(GlobalConfig.ManualRecallRiseDistance, 0.01), 0, 1)
      if riseAlpha >= 1 then
         thrownWeaponData.VisualYOffset = nil
         thrownWeaponData.VisualYOffsetStartedAt = nil
         thrownWeaponData.VisualYOffsetByDistance = nil
         return 0
      end
      return startOffset * (1 - riseAlpha * riseAlpha * (3 - 2 * riseAlpha))
   end
   local alpha = (os.clock() - startedAt) / math.max(GlobalConfig.BoomerangVisualHeightSyncSeconds, 0.01)
   if alpha >= 1 then
      thrownWeaponData.VisualYOffset = nil
      thrownWeaponData.VisualYOffsetStartedAt = nil
      return 0
   end
   local remaining = (1 - alpha) * (1 - alpha) -- // Quick at first, then settles
   return startOffset * remaining
end

local function setWeaponCFrame(thrownWeaponData: ThrownWeapons.Data, cframe: CFrame, deltaTime: number?)
   thrownWeaponData.LastPosition = thrownWeaponData.CFrame.Position
   thrownWeaponData.CFrame = cframe
   AuthorityViewLibrary.update(thrownWeaponData.OwnerUserId, thrownWeaponData.ToolId, cframe.Position) -- // Server only

   local host = thrownWeaponData.Host
   if host and host.Parent then
      if not isServer then
         -- Spin is constant and flat regardless of movement direction, speed, or state
         local visualRotation = (thrownWeaponData.VisualRotation or 0) + (BOOMERANG_SPIN_SPEED * (thrownWeaponData.RecallSpinScale or 1) * (deltaTime or 0))
         thrownWeaponData.VisualRotation = visualRotation
         -- // RecallTilt: visual tilt while a manual recall lifts it (set in Boomerang.recall)
         host:PivotTo(CFrame.new(cframe.Position + Vector3.new(0, getVisualYOffset(thrownWeaponData), 0)) * (thrownWeaponData.RecallTilt or CFrame.identity) * CFrame.Angles(0, visualRotation, 0))
      else
         host:PivotTo(cframe)
      end
      addTrail(thrownWeaponData)
     -- registerBeamSegment(thrownWeaponData, cframe.Position)
      --addNewBeam(thrownWeaponData)
   end
end

-- // Temporary parts showing the swept blockcast volume and hit position; destroyed after a frame
local function updateRaycastVisualizers(castCFrame: CFrame, castSize: Vector3, rayDistance: number, result: RaycastResult?)
   if not raycastVisualizersEnabled then
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
local function fireSpawned(ownerUserId: number, boomerangId: string, instanceId: string, position: Vector3, direction: Vector3, speed: number, throwServerTime: number, curvature: number)
   if not isServer then
      return
   end

   local payload = buffer.create(SPAWN_PACKET_SIZE)
   local offset = 0
   offset = BufferUtil.writeUserId(payload, offset, ownerUserId)
   offset = BufferUtil.writeVector3_96(payload, offset, position)
   offset = BufferUtil.writeVector3_96(payload, offset, direction)
   offset = BufferUtil.writef32(payload, offset, speed)
   offset = BufferUtil.writef64(payload, offset, throwServerTime)
   BufferUtil.writef32(payload, offset, curvature) -- // Curve decided by the server (BoomerangCurveLibrary)

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
-- // `recallTravelled`: studs flown since the recall started (clients replay the speed-up from it)
local function fireSnapshot(ownerUserId: number, position: Vector3, direction: Vector3, speed: number, state: number, curvature: number?, recallTravelled: number?)
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
   offset = BufferUtil.writef64(payload, offset, workspace:GetServerTimeNow())
   -- // Thrower position: remote clients see them slightly in the past, so a returning boomerang steers toward this
   local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
   local ownerRoot = ownerPlayer and ownerPlayer.Character and ownerPlayer.Character.PrimaryPart
   offset = BufferUtil.writeVector3_96(payload, offset, if ownerRoot then ownerRoot.Position else position)
   offset = BufferUtil.writef32(payload, offset, curvature or 0) -- // Current curve (0 once straightened by a bounce, homing, Telekinesis)
   BufferUtil.writef32(payload, offset, recallTravelled or -1) -- // -1 = not returning

   thrownWeaponReplicationRemote:FireAllClients(payload)
end

-- // Sweep a flat horizontal block for obstructions along the boomerang's path
-- Origin is pulled back by a skin margin so consecutive casts overlap (prevents tunneling through thin/concave corners)
local function blockcastWithHorizontalHitbox(
   rayOrigin: Vector3,
   direction: Vector3,
   rayDistance: number,
   hitboxRadius: number,
   raycastParams: RaycastParams
): RaycastResult?
   local result, castCFrame, castSize, castDistance = ObstructionCastLibrary.blockcast(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams)
   updateRaycastVisualizers(castCFrame, castSize, castDistance, result)
   return result
end

-- // A sphere cast ignores parts it already overlaps, so this shared invisible ball is moved to each step's start and
-- // queried for exact overlaps (one step at a time).
local overlapProbe: Part? = nil

local function getOverlapProbe(radius: number): Part
   local probe = overlapProbe
   if not probe or not probe.Parent then
      probe = Instance.new("Part")
      probe.Name = "BoomerangOverlapProbe"
      probe.Shape = Enum.PartType.Ball
      probe.Anchored = true
      probe.CanCollide = false
      probe.CanQuery = false
      probe.CanTouch = false
      probe.CastShadow = false
      probe.Transparency = 1
      probe.CollisionGroup = WEAPON_RAYCAST_COLLISION_GROUP
      probe.Parent = workspace
      overlapProbe = probe
   end
   local diameter = radius * 2
   if probe.Size.X ~= diameter then
      probe.Size = Vector3.new(diameter, diameter, diameter)
   end
   return probe :: Part
end

local function addLivingModel(hitModels: {Model}, seen: {[Model]: boolean}, instance: Instance)
   local hitModel = instance:FindFirstAncestorOfClass("Model")
   if hitModel and not seen[hitModel] then
      local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
      if humanoid and humanoid.Health > 0 then
         seen[hitModel] = true
         table.insert(hitModels, hitModel)
      end
   end
end

-- // Characters and bots touched this step: all overlapping at step start plus the first the sweep hits. With lag
-- // compensation, also everyone the sweep would hit at `thrower`'s view positions (LagCompensationLibrary; thrower
-- // passed on server only).
local function spherecastCharacterHitbox(rayOrigin: Vector3, direction: Vector3, rayDistance: number, hitboxRadius: number, thrower: Player?): {Model}
   local characterRaycastParams = RaycastParams.new()
   characterRaycastParams.FilterType = Enum.RaycastFilterType.Include
   local hitFilter = {Characters}
   local botsFolder = workspace:FindFirstChild("Bots") -- // Bots (e.g. the decoy) live here, not under Characters
   if botsFolder then
      table.insert(hitFilter, botsFolder)
   end
   characterRaycastParams.FilterDescendantsInstances = hitFilter
   characterRaycastParams.IgnoreWater = true
   characterRaycastParams.CollisionGroup = WEAPON_RAYCAST_COLLISION_GROUP

   local hitModels: {Model} = {}
   local seen: {[Model]: boolean} = {}

   -- // Already overlapping at step start (unqueryable parts like the Torso don't count, same as the cast)
   local overlapParams = OverlapParams.new()
   overlapParams.FilterType = Enum.RaycastFilterType.Include
   overlapParams.FilterDescendantsInstances = hitFilter
   overlapParams.CollisionGroup = WEAPON_RAYCAST_COLLISION_GROUP
   local probe = getOverlapProbe(hitboxRadius)
   probe.CFrame = CFrame.new(rayOrigin)
   for _, part in ipairs(workspace:GetPartsInPart(probe, overlapParams)) do
      if part.CanQuery then
         addLivingModel(hitModels, seen, part)
      end
   end

   if rayDistance > 0 then
      local spherecastResult = workspace:Spherecast(rayOrigin, hitboxRadius, direction * rayDistance, characterRaycastParams)
      if spherecastResult then
         addLivingModel(hitModels, seen, spherecastResult.Instance)
      end
   end

   if thrower then
      local rewindSeconds = LagCompensationLibrary.getRewindSeconds(thrower)
      if rewindSeconds > 0 then
         for _, rewoundModel in ipairs(LagCompensationLibrary.getRewoundHitModels(thrower, rewindSeconds, rayOrigin, direction, rayDistance, hitboxRadius)) do
            if not seen[rewoundModel] then
               seen[rewoundModel] = true
               table.insert(hitModels, rewoundModel)
            end
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

local function updateOwnWeaponHighlight(player: Player, thrownWeaponData: ThrownWeapons.Data, position: Vector3, isDeadOrDying: boolean?, fadeOutSeconds: number?)
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
   ToolController.applyHighlight(isObstructed, isDeadOrDying, fadeOutSeconds)
end

local function damagedPlayer(player: Player, boomerangId: string, thrownWeaponData: ThrownWeapons.Data, victimModel: Model): boolean
   -- // Bots (e.g. the decoy) are routed to the bot layer, which applies hit rules and eliminates server-side. No stat
   -- // crediting.
   if victimModel:GetAttribute("BotId") ~= nil then
      if isServer and BotService then
         -- // Bots are reported every step, so the same per-target cooldown as players applies
         if not thrownWeaponData.HitBots then
            thrownWeaponData.HitBots = {}
         end
         local botNow = workspace:GetServerTimeNow()
         local previousBotHitAt = thrownWeaponData.HitBots[victimModel]
         if previousBotHitAt and (botNow - previousBotHitAt) < (GlobalConfig.BoomerangHitThrottle or .5) then
            return false
         end
         thrownWeaponData.HitBots[victimModel] = botNow
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

   local Humanoid = victimModel:FindFirstChildOfClass("Humanoid")
   if not Humanoid or Humanoid.Health <= 0 then
      return false
   end

   local healthBeforeDamage = Humanoid.Health
   local hitResult = CombatLibrary.attackHitPlayer(player, boomerangId, victimPlayer, Humanoid, 100000)

   -- // A dash/spawn-protection dodge (or a no-op hit in this mode) isn't a strike: no cooldown or energy cost, so an
   -- // overlapping boomerang can hit on the next step after the dash ends.
   if hitResult == "Immune" or hitResult == "Ignored" then
      return false
   end
   thrownWeaponData.HitPlayers[victimPlayer] = now

   -- // Each player struck (not shield blocks) costs energy, outgoing or returning. Server only: client prediction
   -- // keeps a little more energy; the server's Returning/Dying snapshot decides the rest.
   if hitResult ~= "Blocked" and isServer and thrownWeaponData.Energy then
      thrownWeaponData.Energy -= BoomerangTuningLibrary.get(thrownWeaponData.ToolId, "PlayerHitEnergyCost")
   end
   if hitResult == "Hit" and isServer and WeaponService and healthBeforeDamage > 0 and Humanoid.Health <= 0 then
      WeaponService.WeaponKilledPlayer:Execute("parallel", player, victimPlayer, thrownWeaponData.ToolId)
   end
   return hitResult == "Hit"
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
   local defaultSpeed = BoomerangTuningLibrary.get(tuningToolId, "ThrowSpeed") -- // Tools value unless changed with Cmdr
   local speed = (options and options.Speed) or defaultSpeed
   local aimStrengthAlpha = math.clamp((options and options.AimStrengthAlpha) or 0, 0, 1)
   if aimStrengthAlpha > 0 and (not options or options.Speed == nil) then
      speed = defaultSpeed * (1 + aimStrengthAlpha * AIM_START_SPEED_BONUS_MULTIPLIER)
   end 
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local isRetuning = false -- // True after a live Cmdr ThrowSpeed change, until the speed reaches the new value
   -- // Energy: MinEnergy (tap) to MaxEnergy (full charge) by aimStrengthAlpha 0..1. Drains in flight (see
   -- // simulateStep); at 0 it recalls if it sees its player, else dies.
   local minEnergy = BoomerangTuningLibrary.get(tuningToolId, "MinEnergy")
   local maxEnergy = math.max(BoomerangTuningLibrary.get(tuningToolId, "MaxEnergy"), minEnergy)
   thrownWeaponData.Energy = minEnergy + (maxEnergy - minEnergy) * aimStrengthAlpha
   thrownWeaponData.EnergyDepletedHandled = false

   local startPosition = (options and options.StartPosition) or (character.PrimaryPart.Position + character.PrimaryPart.CFrame.LookVector * 3)
   -- // Physics always runs at GlobalConfig.BoomerangFlightHeight regardless of player height; clients draw from the
   -- // thrower's height and ease to it (getVisualYOffset).
   startPosition = Vector3.new(startPosition.X, GlobalConfig.BoomerangFlightHeight, startPosition.Z)

   -- // The server decides the curve (side/angle from thrower movement, arc through the aimed point) and turns the
   -- // launch off the aim line; clients fly the curve from the spawn event.
   if isServer then
      local aimDistance: number? = nil
      local targetPosition = options and options.TargetPosition
      if typeof(targetPosition) == "Vector3" and targetPosition == targetPosition then -- // NaN check
         local toTarget = Vector3.new(targetPosition.X - startPosition.X, 0, targetPosition.Z - startPosition.Z)
         aimDistance = toTarget:Dot(direction)
      end
      local humanoid = character:FindFirstChildOfClass("Humanoid")
      local energyPerStud = BoomerangTuningLibrary.get(tuningToolId, "EnergyPerStud")
      local maxDistance = if energyPerStud > 1e-3 then thrownWeaponData.Energy / energyPerStud else math.huge
      -- // Enemy to curve toward: the clicked one (PC), else the closest to the aim within a cone (ThrowTargetLibrary);
      -- // on the server the arc goes through that enemy.
      local curveDirection = direction
      local clickedTarget = options and options.ClickedTarget
      local targetEnemyPosition = ThrowTargetLibrary.findTarget(player, startPosition, direction,
         if type(clickedTarget) == "number" or type(clickedTarget) == "string" then clickedTarget else nil, maxDistance)
      if targetEnemyPosition then
         local toEnemy = Vector3.new(targetEnemyPosition.X - startPosition.X, 0, targetEnemyPosition.Z - startPosition.Z)
         if toEnemy.Magnitude > 1e-3 then
            curveDirection = toEnemy.Unit
            aimDistance = toEnemy.Magnitude
         end
      end
      local launchDirection, curvature = BoomerangCurveLibrary.decide(curveDirection, aimDistance, humanoid and humanoid.MoveDirection, maxDistance)
      direction = launchDirection
      thrownWeaponData.Curvature = curvature
   else
      local maxCurvature = BoomerangCurveLibrary.getMaxCurvature()
      local curvature = (options and options.Curvature) or 0
      thrownWeaponData.Curvature = if curvature == curvature then math.clamp(curvature, -maxCurvature, maxCurvature) else 0
   end

   if not isServer then
      local throwerRoot = character.PrimaryPart
      thrownWeaponData.VisualYOffset = if throwerRoot then throwerRoot.Position.Y - GlobalConfig.BoomerangFlightHeight else 0
      thrownWeaponData.VisualYOffsetStartedAt = os.clock()
   end
   
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
      fireSpawned(player.UserId, boomerangId, boomerangInstanceId, startPosition, direction, speed, throwServerTime, thrownWeaponData.Curvature or 0)
      thrownWeaponData.State = ThrownWeapons.StateEnum.Outgoing
      if projectileVisualizerEnabled then
         -- Server creates a simple representation part for debugging.
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
   local bounceWeight = 0 -- // 1 right after a returning boomerang bounces, fading to 0 as it steers back to the player

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
         if thrownWeaponData.Host then -- // Only exists when the visualizer is on
            if not thrownWeaponData.Host.Parent then
               return false
            end
         end
      else
         if not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
            return false
         end
         updateOwnWeaponHighlight(player, thrownWeaponData, pivot.Position)
      end

      -- // Live tuning: pick up Cmdr changes mid-flight
      local tunedSpeed = BoomerangTuningLibrary.get(tuningToolId, "ThrowSpeed")
      if tunedSpeed ~= defaultSpeed then
         defaultSpeed = tunedSpeed
         isRetuning = true
      end
      -- // A clash (server: Boomerang.clash; clients: Deflected snapshot) set a new direction
      local isReturning = thrownWeaponData.State == ThrownWeapons.StateEnum.Returning
      local returnMaxSpeed = BoomerangTuningLibrary.get(tuningToolId, "ThrowSpeed") * (thrownWeaponData.ReturnSpeedMultiplier or 1)
      if thrownWeaponData.PendingDirection then
         direction = thrownWeaponData.PendingDirection
         thrownWeaponData.PendingDirection = nil
         if not BoomerangCurveLibrary.KEEP_CURVE_AFTER_BOUNCE then
            thrownWeaponData.Curvature = 0 -- // A clash straightens it
         end
         if isReturning then
            -- // Knocked off course while returning: like a bounce, the knock overrides steering briefly
            speed = math.max(speed, returnMaxSpeed * RECALL_BOUNCE_MIN_SPEED_FRACTION)
            bounceWeight = 1
         end
      end

      -- // Client: the server's latest heading and speed replace ours (position is eased separately, see
      -- // WeaponController). Skipped while this client steers with Telekinesis (the server's heading lags the input).
      if not isServer and thrownWeaponData.SnapshotDirection then
         if not Telekinesis.getBias(thrownWeaponData) then
            direction = thrownWeaponData.SnapshotDirection
         end
         speed = thrownWeaponData.SnapshotSpeed or speed
         thrownWeaponData.SnapshotDirection = nil
         thrownWeaponData.SnapshotSpeed = nil
      end

      if not isReturning and (thrownWeaponData.Energy or 0) > 0 and (speed > defaultSpeed or isRetuning) then
         local fadeAlpha = math.clamp(deltaTime * AIM_SPEED_FADE_RATE, 0, 1)
         speed = speed + (defaultSpeed - speed) * fadeAlpha
         if isRetuning and math.abs(defaultSpeed - speed) < 0.5 then
            speed = defaultSpeed
            isRetuning = false
         end
      end

      -- // Out of energy flying OUT: over open air it returns regardless of sight; over ground it returns with a clear
      -- // line of sight to the player, else dies. A recall refills to GlobalConfig.BoomerangRecallEnergy.
      -- // The server decides death; a client predicts the return, or with ground and no sight slows (Exhausted) and
      -- // waits for the server's Returning/Dying snapshot.
      -- // Out of energy while RETURNING: dies (no new sight check); over open air it keeps heading to the player and
      -- // dies once over ground.
      if isReturning then
         if isServer and (thrownWeaponData.Energy or 0) <= 0 and DeadWeaponLogic.hasGroundBelow(pivot.Position, thrownWeaponData.Host) then
            -- // About to die, but if back in sight and range now (or along its slide) it keeps returning on a fresh
            -- // reserve, once per throw.
            if not thrownWeaponData.ReturnRescued and canAvoidDying(player, toolData, thrownWeaponData, pivot.Position, direction, speed) then
               thrownWeaponData.ReturnRescued = true
               thrownWeaponData.Energy = BoomerangTuningLibrary.get(tuningToolId, "RecallEnergy")
            else
               Boomerang.die(player, thrownWeaponData, {
                  Direction = direction,
                  Speed = speed,
                  Position = pivot.Position,
               })
               return true
            end
         end
      elseif (thrownWeaponData.Energy or 0) <= 0 then
         if shouldRecallTransitions and not thrownWeaponData.EnergyDepletedHandled then
            thrownWeaponData.EnergyDepletedHandled = true
            if isServer and WeaponService then
               -- // End of flight (Explosive / Teleport boomerang effects fire here)
               WeaponService.WeaponReachedEventPoint:Execute("parallel", player, thrownWeaponData.ToolId, pivot.Position)
            end
            if ThrownWeapons.Data[player] ~= thrownWeaponData then
               return true -- // Removed by an event-point effect
            end
            if DeadWeaponLogic.hasGroundBelow(pivot.Position, thrownWeaponData.Host) then
               if Boomerang.autoRecallOrDie(player, boomerangId, toolData, thrownWeaponData, pivot.Position, direction, speed) then
                  return true
               end
            else
               -- // Open air: can't die; head back regardless of sight
               thrownWeaponData.Energy = BoomerangTuningLibrary.get(tuningToolId, "RecallEnergy")
               Boomerang.recall(player, boomerangId, toolData, thrownWeaponData)
               return true
            end
         end
         thrownWeaponData.State = ThrownWeapons.StateEnum.Exhausted
         speed = speed - (speed * SLOW_RATE * deltaTime)
         if speed <= .1 then
            -- // Waiting for the server's verdict (Returning or Dying snapshot); the loop stays alive so a recall can
            -- // steer it home.
            speed = 0
            thrownWeaponData.Speed = 0
            return true
         end
      end

      -- // Returning: steer toward the player; the outgoing movement below then applies unchanged.
      if isReturning then
         local character = player.Character
         local rootPart = character and character.PrimaryPart
         if not rootPart then
            if isServer then
               Boomerang.removeFromField(player, thrownWeaponData)
            end
            return false
         end

         -- // Server steers toward its thrower position; the thrower's client toward its own character; other clients
         -- // toward the server-sent position (their view lags), so drawn paths match the server.
         local targetPosition = rootPart.Position
         if not isServer and player ~= Players.LocalPlayer and thrownWeaponData.ServerTargetPosition then
            targetPosition = thrownWeaponData.ServerTargetPosition
         end
         local toPlayer = targetPosition - pivot.Position
         local horizontalDistance = getHorizontalDistance(pivot.Position, targetPosition)
         local catchRadius = math.max(RECALL_CATCH_RADIUS_MIN, hitboxRadius * 1.25) + (if isServer then SERVER_RECALL_CATCH_BONUS else 0)
         if horizontalDistance <= catchRadius and catchWeapon(player, thrownWeaponData) then
            return true
         end
         local targetDirection = getHorizontalDirection(toPlayer)

         -- // A bounce or clash makes its momentum override steering, fading back over the recovery time. Velocity is
         -- // split relative to the player each frame: toward them the forward speed rebuilds; away it shrinks through
         -- // zero, and sideways speed bleeds off.
         local recoverySeconds = math.max(BoomerangTuningLibrary.get(tuningToolId, "RecallBounceRecovery"), 0.01)
         bounceWeight = math.max(bounceWeight - deltaTime / recoverySeconds, 0)
         local steerScale = 1 - bounceWeight * bounceWeight * (3 - 2 * bounceWeight)

         local travelVelocity = direction * speed
         local alignment = if travelVelocity.Magnitude > 1e-5 then travelVelocity.Unit:Dot(targetDirection) else 1
         local transitionRate = if alignment < -0.25 then 11 elseif alignment < 0.5 then 8 else 5
         local transitionAlpha = 1 - math.exp(-transitionRate * steerScale * deltaTime)

         local forwardSpeed = travelVelocity:Dot(targetDirection)
         local sidewaysVelocity = travelVelocity - targetDirection * forwardSpeed
         forwardSpeed += (returnMaxSpeed - forwardSpeed) * transitionAlpha
         -- // Up close the sideways part must drop fast enough to close in, or it would circle the player
         local steerRate = math.max(transitionRate, RETURN_STEER_TIGHTNESS * travelVelocity.Magnitude / math.max(horizontalDistance, catchRadius))
         sidewaysVelocity *= math.exp(-steerRate * steerScale * deltaTime)
         travelVelocity = targetDirection * forwardSpeed + sidewaysVelocity

         local velocityMagnitude = travelVelocity.Magnitude
         speed = math.clamp(velocityMagnitude, 0, returnMaxSpeed)
         direction = if velocityMagnitude > 1e-5 then getHorizontalDirection(travelVelocity) else targetDirection
      end

      local rayOrigin = pivot.Position
      local dynamicDisplacement = getDynamicDisplacement(rayOrigin, hitboxRadius, deltaTime)
      rayOrigin += dynamicDisplacement

      local steeredThisStep = false -- // Homing or Telekinesis took over the heading (curve stops)
      if isServer and thrownWeaponData.Homing and not isReturning then
         local targetDirection = getNearestEnemyDirection(player, rayOrigin)
         if targetDirection then
            local homingAlpha = math.clamp(HomingBoomerang.HOMING_INFLUENCE * deltaTime, 0, 1)
            direction = getHorizontalDirection(direction:Lerp(targetDirection, homingAlpha))
            steeredThisStep = true
         end
      end

      -- // Telekinesis (Telekinesis.lua): turns toward the owner's wanted direction; the server uses the owner client's
      -- // streamed input, the owner client its live input. Remote clients follow snapshots.
      if not isReturning then
         local telekinesisBias = Telekinesis.getBias(thrownWeaponData)
         if telekinesisBias then
            direction = getHorizontalDirection(Telekinesis.steer(direction, telekinesisBias, deltaTime))
            steeredThisStep = true
         end
      end

      -- // Throw curve (BoomerangCurveLibrary): constant turn per stud flown out, same on all machines. Homing or
      -- // Telekinesis ends it permanently.
      local curvature = thrownWeaponData.Curvature
      if curvature and curvature ~= 0 and not isReturning then
         if steeredThisStep then
            thrownWeaponData.Curvature = 0
         else
            direction = BoomerangCurveLibrary.rotate(direction, curvature * speed * deltaTime)
         end
      end

      local rayDistance = speed * deltaTime

      -- // Portals: passes through and exits the paired portal (same on server and client)
      local portalExit = Portal.getProjectileExit(rayOrigin, direction, rayDistance, hitboxRadius, thrownWeaponData.PortalExitAt, thrownWeaponData.PortalExitPart)
      if portalExit then
         direction = portalExit.Direction
         thrownWeaponData.PortalExitAt = os.clock()
         thrownWeaponData.PortalExitPart = portalExit.ExitPart
         if not isServer then
            retireTrail(thrownWeaponData)
            thrownWeaponData.SyncCorrection = nil -- // A pre-crossing correction would drag it back toward the entry portal
         end
         setWeaponCFrame(thrownWeaponData, CFrame.new(portalExit.Position), deltaTime)
         if not isServer then
            thrownWeaponData.LastPosition = portalExit.Position -- // Teleport: the drawn position must not slide through the gap
         end
         -- // Only the distance flown before entering costs energy; distance is free on the way back.
         if not isReturning then
            thrownWeaponData.Energy = (thrownWeaponData.Energy or 0) - portalExit.EntryDistance * BoomerangTuningLibrary.get(tuningToolId, "EnergyPerStud")
         end
         thrownWeaponData.Direction = direction
         thrownWeaponData.Speed = speed
         if isServer then
            fireSnapshot(player.UserId, portalExit.Position, direction, speed, thrownWeaponData.State, thrownWeaponData.Curvature) -- // Keyframe: clients exit at the same spot
         end
         return true
      end

      local obstructionRaycastResult = blockcastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams)

      -- // Only the server decides hits (a client boomerang never hits, so it can't show a rejected hit). The sweep
      -- // stops at walls so players behind them aren't struck.
      if isServer then
         local sweepDistance = rayDistance
         if obstructionRaycastResult then
            sweepDistance = math.clamp(obstructionRaycastResult.Distance - OBSTRUCTION_BLOCKCAST_SKIN, 0, rayDistance)
         end
         for _, victimModel in ipairs(spherecastCharacterHitbox(rayOrigin, direction, sweepDistance, hitboxRadius, player)) do
            damagedPlayer(player, boomerangId, thrownWeaponData, victimModel)
         end
      end

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
         if not BoomerangCurveLibrary.KEEP_CURVE_AFTER_BOUNCE then
            thrownWeaponData.Curvature = 0 -- // A bounce straightens it
         end
         if isReturning then
            -- // Bounce momentum replaces steering, then fades back into it (see above)
            speed = math.max(speed, returnMaxSpeed * RECALL_BOUNCE_MIN_SPEED_FRACTION)
            bounceWeight = 1
         end
         setWeaponCFrame(thrownWeaponData, pivot + dynamicDisplacement, deltaTime)
         SharedTasks.ThrownWeaponHitObject:Execute("parallel", player, thrownWeaponData.ToolId, obstructionRaycastResult.Instance, obstructionRaycastResult.Position)
         thrownWeaponData.Direction = direction
         thrownWeaponData.Speed = speed
         if isServer then
            fireSnapshot(player.UserId, pivot.Position, direction, speed, thrownWeaponData.State, thrownWeaponData.Curvature) -- // Keyframe: clients bounce at the same spot
         end
         return true
      end

      local currentCFrame = pivot
      setWeaponCFrame(thrownWeaponData, currentCFrame + dynamicDisplacement + direction * rayDistance, deltaTime)
      if not isReturning then
         -- // Flying out costs energy per stud; the way back is free (only bounces, player hits and clashes cost energy
         -- // while returning)
         thrownWeaponData.Energy = (thrownWeaponData.Energy or 0) - rayDistance * BoomerangTuningLibrary.get(tuningToolId, "EnergyPerStud")
      end
      thrownWeaponData.Direction = direction
      thrownWeaponData.Speed = speed
      return true
   end

   -- // A new boomerang arrives one network trip late: the distance the server already flew is eased in through the
   -- // snapshot correction instead of jumping.
   if not isServer and options and options.ThrowServerTime then
      local catchup = math.clamp(workspace:GetServerTimeNow() - options.ThrowServerTime, 0, MAX_SPAWN_CATCHUP)
      if catchup > 0 then
         -- // Along the arc flown so far, turned as far as the server has turned it
         local displacement, caughtUpDirection = BoomerangCurveLibrary.advanceAlongArc(direction, thrownWeaponData.Curvature or 0, speed * catchup)
         thrownWeaponData.SyncCorrection = displacement
         direction = caughtUpDirection
         thrownWeaponData.Energy = (thrownWeaponData.Energy or 0) - speed * catchup * BoomerangTuningLibrary.get(tuningToolId, "EnergyPerStud")
      end
   end

   -- // Client only: draw between the last two simulated positions so motion is smooth and never passes where walls
   -- // were checked
   local function drawHost(stepAccumulator: number)
      local host = thrownWeaponData.Host
      local simCFrame = thrownWeaponData.CFrame
      if isServer or not host or not host.Parent or not simCFrame then
         return
      end
      local alpha = math.clamp(stepAccumulator / FIXED_STEP, 0, 1)
      local drawnPosition = (thrownWeaponData.LastPosition or simCFrame.Position):Lerp(simCFrame.Position, alpha)
      local spin = (thrownWeaponData.VisualRotation or 0) + BOOMERANG_SPIN_SPEED * stepAccumulator
      host:PivotTo(CFrame.new(drawnPosition + Vector3.new(0, getVisualYOffset(thrownWeaponData), 0)) * (thrownWeaponData.RecallTilt or CFrame.identity) * CFrame.Angles(0, spin, 0))
   end

   local function stopMovement()
      local movementConnection = thrownWeaponData.MovementConnection
      if movementConnection then
         movementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
      end
   end

   -- // Fixed timestep: server and clients advance in identical FIXED_STEP slices so frame rate can't change where
   -- // bounces or turns happen. Leftover time carries to the next frame (used only for smooth drawing).
   local stepAccumulator = 0
   thrownWeaponData.MovementConnection = RunService.Stepped:Connect(function(time, deltaTime)
      stepAccumulator = math.min(stepAccumulator + deltaTime, FIXED_STEP * MAX_STEPS_PER_FRAME)
      while stepAccumulator >= FIXED_STEP - 1e-4 do
         stepAccumulator = math.max(stepAccumulator - FIXED_STEP, 0)
         if not simulateStep(FIXED_STEP, true) then
            stopMovement()
            return
         end
         if ThrownWeapons.Data[player] ~= thrownWeaponData then
            return
         end
      end

      local currentPivot = getWeaponCFrame(thrownWeaponData)
      if isServer and thrownWeaponData.Host then
         if not thrownWeaponData.Host.Parent then
            stopMovement()
            return
         end
      elseif not currentPivot then
         stopMovement()
         return
      end

      drawHost(stepAccumulator)

      SharedTasks.ThrownWeaponMoved:Execute("serial", player, thrownWeaponData.ToolId, currentPivot.Position, thrownWeaponData.State == ThrownWeapons.StateEnum.Returning)

      if isServer and time >= nextReplicationAt and currentPivot then
         nextReplicationAt = time + REPLICATION_RATE
         fireSnapshot(player.UserId, currentPivot.Position, direction, speed, thrownWeaponData.State, thrownWeaponData.Curvature)
      end
   end)
end

-- // Restore to player / remove from field
-------------------------------------------------------------------------------
-- CATCHING: only the server decides that a boomerang has been caught
-- A client only predicts a catch: it hides the boomerang and plays the catch animation and sound at once, but keeps the
-- data and keeps simulating it hidden. Then:
--   * the server agrees: its Despawned event removes it (WeaponController > removeFromField, effects not repeated)
--   * the server drops it (Dying snapshot): Boomerang.die shows it again where the server says
--   * no verdict within PENDING_CATCH_TIMEOUT: it is shown again and catch prediction stops for it (the server's catch
-- still despawns it)
-------------------------------------------------------------------------------

-- // Client-side visibility of the model (LocalTransparencyModifier, leaving other transparency untouched)
setHostHidden = function(thrownWeaponData: ThrownWeapons.Data, hidden: boolean)
   if not hidden and not thrownWeaponData.HostHidden then
      return
   end
   thrownWeaponData.HostHidden = if hidden then true else nil
   local host = thrownWeaponData.Host
   if isServer or not host or not host.Parent then
      return
   end
   local value = if hidden then 1 else 0
   if host:IsA("BasePart") then
      host.LocalTransparencyModifier = value
   end
   for _, descendant in ipairs(host:GetDescendants()) do
      if descendant:IsA("BasePart") or descendant:IsA("Decal") then
         descendant.LocalTransparencyModifier = value
      end
   end
end

-- // A returning boomerang reached its player. Server: caught (removed). Client: the catch is only predicted. Returns
-- // true if removed (the caller's movement loop must stop).
-- // Normal or heavy catch (CatchLibrary) from the motion before contact; only a manual recall can be heavy (and push)
local function resolveCatch(player: Player, thrownWeaponData: ThrownWeapons.Data): CatchLibrary.CatchInfo
   if thrownWeaponData.RecallFromDead ~= true then
      return { Heavy = false, ClosingSpeed = 0, Direction = Vector3.zero }
   end
   local position = thrownWeaponData.CFrame and thrownWeaponData.CFrame.Position
   local velocity = if thrownWeaponData.Direction and thrownWeaponData.Speed then thrownWeaponData.Direction * thrownWeaponData.Speed else nil
   return CatchLibrary.resolve(player, thrownWeaponData.ToolId, position, velocity)
end

-- // Catch animation: light or heavy for a manual recall, the original catch for any other return
local function getCatchAnimation(thrownWeaponData: ThrownWeapons.Data, catchInfo: CatchLibrary.CatchInfo): string
   if thrownWeaponData.RecallFromDead ~= true then
      return "ReturnCatch"
   end
   return if catchInfo.Heavy then "HeavyCatch" else "Catch"
end

catchWeapon = function(player: Player, thrownWeaponData: ThrownWeapons.Data): boolean
   if isServer then
      local catchInfo = resolveCatch(player, thrownWeaponData)
      if catchInfo.Heavy then
         CatchLibrary.push(player, catchInfo.Direction)
      end
      Boomerang.removeFromField(player, thrownWeaponData)
      return true
   end
   if thrownWeaponData.PendingCatchAt or thrownWeaponData.PendingCatchExpired then
      return false
   end
   thrownWeaponData.PendingCatchAt = os.clock()
   setHostHidden(thrownWeaponData, true)
   retireTrail(thrownWeaponData)
   local catchInfo = resolveCatch(player, thrownWeaponData)
   if AnimationController then
      AnimationController.playCoreAnimation(player, getCatchAnimation(thrownWeaponData, catchInfo))
   end
   if catchInfo.Heavy then
      CatchLibrary.push(player, catchInfo.Direction) -- // Only affects the local player (prediction)
   end
   SoundLibrary.play(thrownWeaponData.InstanceId, Sounds.Data.BoomerangCatch.Name, player.Character) -- // Replaces the flight loop
   thrownWeaponData.CatchEffectsPlayed = true
   return false
end

-- // Client: the server didn't take the predicted catch (it dropped the boomerang, or no verdict in time). Show it again.
-- // expired: no verdict arrived; stops catch prediction for this boomerang and resumes its flight sound.
function Boomerang.cancelPendingCatch(_player: Player, thrownWeaponData: ThrownWeapons.Data, expired: boolean?)
   if isServer or not thrownWeaponData.PendingCatchAt then
      return
   end
   thrownWeaponData.PendingCatchAt = nil
   thrownWeaponData.CatchEffectsPlayed = nil
   setHostHidden(thrownWeaponData, false)
   if expired then
      thrownWeaponData.PendingCatchExpired = true
      warn(`Boomerang: the server never confirmed a predicted catch ({thrownWeaponData.InstanceId}); showing the boomerang again`)
      local host = thrownWeaponData.Host
      if host and host.Parent and host.PrimaryPart then
         SoundLibrary.play(thrownWeaponData.InstanceId, Sounds.Data.BoomerangLoop.Name, host.PrimaryPart, nil, true)
      end
   end
end

-- // Client, every frame (WeaponController): give up on predicted catches the server hasn't answered in time
function Boomerang.updatePendingCatches()
   if isServer then
      return
   end
   local now = os.clock()
   for player, thrownWeaponData in pairs(ThrownWeapons.Data) do
      if thrownWeaponData.PendingCatchAt and now - thrownWeaponData.PendingCatchAt >= PENDING_CATCH_TIMEOUT then
         Boomerang.cancelPendingCatch(player, thrownWeaponData, true)
      end
   end
end

function Boomerang.removeFromField(player: Player, thrownWeaponData: ThrownWeapons.Data, options: RemoveFromFieldOptions?)
   local returnToPlayer = options == nil or options.ReturnToPlayer ~= false
   local shouldReattachLocally = returnToPlayer and (not isServer) and thrownWeaponData.ReuseEquippedHost == true

   if not isServer and ToolController and player == Players.LocalPlayer then
      ToolController.applyHighlight(false, false)
   end

   -- // A client that already showed the catch doesn't repeat the animation/sound
   if returnToPlayer and AnimationController and not thrownWeaponData.CatchEffectsPlayed then
      AnimationController.playCoreAnimation(player, getCatchAnimation(thrownWeaponData, resolveCatch(player, thrownWeaponData)))
   end
   if shouldReattachLocally then
      setHostHidden(thrownWeaponData, false) -- // The hidden host returns to the hand, visible
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
   elseif returnToPlayer and not thrownWeaponData.CatchEffectsPlayed then
      SoundLibrary.play(thrownWeaponData.InstanceId, Sounds.Data.BoomerangCatch.Name, player.Character)
   end
   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end
   thrownWeaponData.CFrame = nil
   ThrownWeapons.Data[player] = nil

   finishFanTrail(thrownWeaponData)
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

-- // Recall-or-die for a boomerang out of energy over ground: with a clear line of sight to the player (flat block cast
-- // to their Hitbox) it returns on a fresh recall energy reserve, else it drops into dying/dead (Dead.luau) and needs
-- // a manual recall. Over open air it simply returns.
-- // Distance from the player is irrelevant; this is the only way a thrown boomerang dies.
-- // Only the server decides death: on a client with no line of sight nothing happens (returns false) and it keeps
-- // flying until the server's Dying snapshot (WeaponController.onSnapshot calls die).
function Boomerang.autoRecallOrDie(player: Player, boomerangId: string, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data, position: Vector3, direction: Vector3, speed: number): boolean
   -- // Line of sight now, or (server) in sight and range at some point of the slide it is about to make
   if not thrownWeaponData.HasBeenDead and (hasLineOfSightToPlayer(player, position, toolData, thrownWeaponData) or canAvoidDying(player, toolData, thrownWeaponData, position, direction, speed)) then
      -- // The return gets its own small energy reserve; if bounces and hits use it up, the boomerang dies
      thrownWeaponData.Energy = BoomerangTuningLibrary.get(thrownWeaponData.ToolId or boomerangId, "RecallEnergy")
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

-- // Manual recall of a dying or dead boomerang: it becomes thrown again and returns.
-- // isManualRecall: the charged recall; it returns only while the player holds recall (Boomerang.stopRecallFromDead
-- // undoes it). false = automatic recovery.
-- // Server: called from WeaponService on recall press (and by the out-of-bounds failsafe / sliding-away hooks, without hold).
-- // Client: called from WeaponController.onSnapshot when the server's snapshot says it is Returning.
function Boomerang.recallFromDead(player: Player, deadWeaponData: DeadWeapons.Data, isManualRecall: boolean)
   if ThrownWeapons.Data[player] or DeadWeapons.Data[player] ~= deadWeaponData then
      return
   end
   local toolData = Tools[deadWeaponData.ToolId]
   if not toolData or not toolData.Boomerang then
      return
   end
   local host = deadWeaponData.Host
   local pivot = if host and host.Parent then host:GetPivot() else deadWeaponData.CFrame
   if not pivot then
      return
   end

   if deadWeaponData.MovementConnection then
      deadWeaponData.MovementConnection:Disconnect()
      deadWeaponData.MovementConnection = nil
   end

   -- // A returning boomerang's physics is always at flight height, whatever its drawn height
   local physicsCFrame = (pivot - pivot.Position) + Vector3.new(pivot.Position.X, GlobalConfig.BoomerangFlightHeight, pivot.Position.Z)

   local thrownWeaponData: ThrownWeapons.Data = {
      ToolId = deadWeaponData.ToolId,
      State = ThrownWeapons.StateEnum.Exhausted, -- // recall() switches it to Returning
      InstanceId = deadWeaponData.InstanceId,
      OwnerUserId = deadWeaponData.OwnerUserId,
      Host = host,
      LastPosition = physicsCFrame.Position,
      CFrame = physicsCFrame,
      Direction = deadWeaponData.Direction,
      Speed = 0,
      ReuseEquippedHost = deadWeaponData.ReuseEquippedHost,
      ExistingHost = deadWeaponData.ExistingHost,
      VisualRotation = deadWeaponData.VisualRotation,
      RecallFromDead = isManualRecall,
      HasBeenDead = deadWeaponData.HasBeenDead,
      -- // Client: drawn where the model is now, easing to physics height (getVisualYOffset), like a throw leaving the
      -- // hand
      VisualYOffset = if isServer then nil else pivot.Position.Y - GlobalConfig.BoomerangFlightHeight,
      VisualYOffsetStartedAt = if isServer then nil else os.clock(),
      -- // Ground approach: a manual recall starts on the ground and rises with distance flown
      VisualYOffsetByDistance = if not isServer and isManualRecall and GlobalConfig.ManualRecallGroundApproach then true else nil,
   } :: any

   DeadWeapons.Data[player] = nil
   ThrownWeapons.Data[player] = thrownWeaponData

   if not isServer and host and host.PrimaryPart then
      SoundLibrary.play(thrownWeaponData.InstanceId, Sounds.Data.BoomerangLoop.Name, host.PrimaryPart, nil, true)
   end

   Boomerang.recall(player, thrownWeaponData.ToolId, toolData, thrownWeaponData, { InitialSpeed = 0 })
end

-- // Recall released while a charged boomerang flies back: it loses momentum and drops (server only; clients follow the
-- // Dying snapshot). Ignored unless recalled from dead.
function Boomerang.stopRecallFromDead(player: Player, thrownWeaponData: ThrownWeapons.Data)
   if not isServer or not thrownWeaponData.RecallFromDead or thrownWeaponData.State ~= ThrownWeapons.StateEnum.Returning then
      return
   end
   if ThrownWeapons.Data[player] ~= thrownWeaponData then
      return
   end
   -- // The release can arrive after the owner's client already caught it (it sees its character slightly ahead). If it
   -- // is within the catch radius plus its travel in the owner's ping, count it as caught instead of dropping it.
   local toolData = Tools[thrownWeaponData.ToolId]
   local pivot = getWeaponCFrame(thrownWeaponData)
   local character = player.Character
   local rootPart = character and character.PrimaryPart
   if toolData and toolData.Boomerang and pivot and rootPart then
      local catchRadius = math.max(RECALL_CATCH_RADIUS_MIN, toolData.Boomerang.HitboxRadius * 1.25) + SERVER_RECALL_CATCH_BONUS
      local graceDistance = (thrownWeaponData.Speed or 0) * math.clamp(player:GetNetworkPing(), 0, RELEASE_CATCH_GRACE_MAX_PING) + RELEASE_CATCH_GRACE_STUDS
      if getHorizontalDistance(pivot.Position, rootPart.Position) <= catchRadius + graceDistance then
         Boomerang.removeFromField(player, thrownWeaponData)
         return
      end
   end
   local direction = thrownWeaponData.Direction
   if not direction or direction.Magnitude < 1e-5 then
      direction = if pivot and rootPart then getHorizontalDirection(rootPart.Position - pivot.Position) else Vector3.new(0, 0, -1)
   end
   Boomerang.die(player, thrownWeaponData, {
      Direction = direction,
      -- // At least the fully-charged release momentum (Dead.luau RELEASE_MOMENTUM)
      Speed = math.max(thrownWeaponData.Speed or 0, DeadWeaponLogic.getReleaseMomentum(1)),
   })
end

-- // Two thrown boomerangs struck mid-air (server only: ClashService > WeaponService.clashWeapon). Costs
-- // ClashEnergyCost and knocks it along options.Direction without killing it; at 0 energy the usual recall-or-die
-- // decision follows next step. A returning boomerang is knocked off course like a bounce. Clients learn the direction
-- // from the Deflected snapshot (Boomerang.deflect).
function Boomerang.clash(player: Player, thrownWeaponData: ThrownWeapons.Data, options: ClashInitOptions)
   if not isServer or ThrownWeapons.Data[player] ~= thrownWeaponData then
      return
   end
   if thrownWeaponData.Energy == nil then
      return
   end
   if not getWeaponCFrame(thrownWeaponData) then
      return
   end

   local newDirection = getHorizontalDirection(options.Direction)
   thrownWeaponData.Energy -= BoomerangTuningLibrary.get(thrownWeaponData.ToolId, "ClashEnergyCost")
   thrownWeaponData.PendingDirection = newDirection

   -- // Snapshots are unreliable, so the event is sent a few times with the same direction
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

-- // Client: Deflected snapshot (clashed with another boomerang): fly off in the given direction
function Boomerang.deflect(player: Player, thrownWeaponData: ThrownWeapons.Data, direction: Vector3)
   if ThrownWeapons.Data[player] ~= thrownWeaponData then
      return
   end
   thrownWeaponData.PendingDirection = getHorizontalDirection(direction)
end

-- // Client: a Dying/Dead snapshot arrived for a player whose boomerang this client lacks (desync or late join). Builds
-- // the dead boomerang so it can be seen, picked up and recalled.
-- // options.ExistingHost: the local player's held model to reuse, so catching it puts it back in the hand.
function Boomerang.restoreDeadFromSnapshot(player: Player, toolId: string, options: {
   Position: Vector3,
   Direction: Vector3,
   Speed: number,
   IsDead: boolean,
   ExistingHost: Model?,
})
   if isServer or ThrownWeapons.Data[player] or DeadWeapons.Data[player] then
      return
   end
   local toolData = Tools[toolId]
   if not toolData or not toolData.Boomerang then
      return
   end

   local boomerangModel = options.ExistingHost
   local reuseEquippedHost = boomerangModel ~= nil and boomerangModel.Parent ~= nil
   if not reuseEquippedHost then
      local modelName = SkinLibrary.getModelName(player)
      local template = modelName and ReplicatedStorage.Shared.Assets.Tools:FindFirstChild(modelName)
      if not template then
         warn(`Boomerang.restoreDeadFromSnapshot: no model for {player.Name}'s skin`)
         return
      end
      boomerangModel = template:Clone()
   end
   local host = boomerangModel :: Model
   host.Name = `Boomerang_{player.Name}`
   for _, descendant in ipairs(host:GetDescendants()) do
      if descendant:IsA("BasePart") then
         descendant.Anchored = true
      end
   end
   local startCFrame = CFrame.new(options.Position)
   host:PivotTo(startCFrame)
   host.Parent = WeaponsFolder

   local direction = getHorizontalDirection(options.Direction)
   local deadWeaponData = {
      OwnerUserId = player.UserId,
      ToolId = toolId,
      State = DeadWeapons.StateEnum.Dying,
      InstanceId = HttpService:GenerateGUID(false), -- // Local only (the snapshot has no server id); used for sound channels
      Host = host,
      LastPosition = options.Position,
      CFrame = startCFrame,
      Direction = direction,
      Speed = options.Speed,
      ReuseEquippedHost = if reuseEquippedHost then true else nil,
      ExistingHost = if reuseEquippedHost then host else nil,
      HasBeenDead = if options.IsDead then true else nil,
   } :: any
   DeadWeapons.Data[player] = deadWeaponData
   warn(`Boomerang: rebuilt {player.Name}'s dead boomerang from a server snapshot (this client didn't have it)`)

   DeadWeaponLogic.applyDeath(player, deadWeaponData, {
      Direction = direction,
      Speed = options.Speed,
      Position = options.Position,
      PhysicsY = options.Position.Y, -- // The server's position is its physics height
   })
   if options.IsDead then
      deadWeaponData.SpinRate = 0 -- // Already resting: no dying spin
      DeadWeaponLogic.setDead(player, deadWeaponData, options.Position)
   end
end

-- // A thrown boomerang dies: it loses flight and drops into dying/dead (Dead.luau)
function Boomerang.die(player: Player, thrownWeaponData: ThrownWeapons.Data, options: DieInitOptions)
   if DeadWeapons.Data[player] then
      return
   end
   -- // Client predicted a catch but the server dropped the boomerang: show it again where it drops
   Boomerang.cancelPendingCatch(player, thrownWeaponData)

   local pivot = getWeaponCFrame(thrownWeaponData)
   if not pivot then
      return
   end
   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end

   local direction = getHorizontalDirection(options.Direction)
   local speed = options.Speed or math.max((thrownWeaponData.Speed or 0) * DEATH_SPEED_SCALE, DEATH_MINIMUM_SPEED)

   finishFanTrail(thrownWeaponData)
   if thrownWeaponData.TrailObject then
      if thrownWeaponData.TrailObject.TrailHost and thrownWeaponData.TrailObject.TrailHost.Parent then
         thrownWeaponData.TrailObject.TrailHost:Destroy()
      end
      thrownWeaponData.TrailObject = nil
   end

   local deadWeaponData = {
      OwnerUserId = thrownWeaponData.OwnerUserId,
      ToolId = thrownWeaponData.ToolId,
      State = DeadWeapons.StateEnum.Dying,
      InstanceId = thrownWeaponData.InstanceId,
      Host = thrownWeaponData.Host,
      LastPosition = thrownWeaponData.LastPosition,
      CFrame = pivot,
      Direction = direction,
      Speed = speed,
      ReuseEquippedHost = thrownWeaponData.ReuseEquippedHost,
      ExistingHost = thrownWeaponData.ExistingHost,
      VisualRotation = thrownWeaponData.VisualRotation,
      HasBeenDead = thrownWeaponData.HasBeenDead, -- // Carried along permanently (see DeadWeapons.Data)
   }

   thrownWeaponData.Host = nil
   ThrownWeapons.Data[player] = nil
   DeadWeapons.Data[player] = deadWeaponData

   DeadWeaponLogic.applyDeath(player, deadWeaponData, {
      Direction = direction,
      Speed = speed,
      Position = options.Position,
      PhysicsY = GlobalConfig.BoomerangFlightHeight, -- // Flying physics is always at flight height, whatever the drawn height
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
      or DeadWeapons.Data[player] ~= nil
   then
      return
   end

   thrownWeaponData.State = ThrownWeapons.StateEnum.Returning

   -- // A thrown boomerang (has energy) keeps the throw's movement loop, which steers to the player while doing
   -- // everything outgoing flight does. Only a boomerang recalled off the ground (dying/dead, no energy) uses the
   -- // separate loop below.
   if thrownWeaponData.MovementConnection and thrownWeaponData.Energy ~= nil and thrownWeaponData.RecallFromDead == nil then
      -- // Explosive boomerang returns faster while its replicated effect is active
      thrownWeaponData.ReturnSpeedMultiplier = if PickupLibrary.hasPickupEffectActive(player.UserId, "ExplosiveBoomerang") then GlobalConfig.ExplosiveBoomerangReturnSpeedMultiplier else 1
      if isServer and hostPivot then
         -- // Its real heading; it turns toward the player gradually in that loop.
         local currentDirection = thrownWeaponData.Direction or Vector3.zero
         fireSnapshot(player.UserId, hostPivot.Position, currentDirection, thrownWeaponData.Speed or 0, thrownWeaponData.State, thrownWeaponData.Curvature)
      end
      return
   end

   if thrownWeaponData.MovementConnection then
      thrownWeaponData.MovementConnection:Disconnect()
      thrownWeaponData.MovementConnection = nil
   end

   local tuningToolId = thrownWeaponData.ToolId or boomerangId
   -- // Explosive boomerang returns faster while its replicated effect is active
   local returnSpeedMultiplier = if PickupLibrary.hasPickupEffectActive(player.UserId, "ExplosiveBoomerang") then GlobalConfig.ExplosiveBoomerangReturnSpeedMultiplier else 1
   -- // Held manual recall of a dying/dead boomerang: capped speed, heavy momentum
   local isManualRecallFromDead = thrownWeaponData.RecallFromDead == true
   local maximumSpeed, momentumMultiplier = 0, 1
   local rampSeconds, rampPower = MANUAL_RECALL_FULL_SPEED_SECONDS, GlobalConfig.ManualRecallRampPower
   local rampElapsed = 0 -- // Seconds since this recall started (drives the manual recall speed-up curve)
   local recallTravelled = 0 -- // Studs flown since this recall started (drives speed-up and rise)
   local riseStartY: number? = nil -- // Manual recall: height it started rising from
   -- // Tools/GlobalConfig values unless changed with Cmdr; re-read every frame so live changes apply mid-recall
   local function updateRecallTuning()
      if isManualRecallFromDead then
         maximumSpeed = BoomerangTuningLibrary.get(tuningToolId, "RecallSpeed") * returnSpeedMultiplier
         momentumMultiplier = BoomerangTuningLibrary.get(tuningToolId, "RecallCurveAcceleration")
         -- // Used only when ManualRecallGroundApproach is off: read straight from GlobalConfig, not tunable with Cmdr
         rampSeconds = MANUAL_RECALL_FULL_SPEED_SECONDS / math.max(GlobalConfig.ManualRecallAcceleration, 0.01)
         rampPower = GlobalConfig.ManualRecallRampPower
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
      if isServer and hostPart then
         if not hostPart.Parent then
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
      -- // Client: adopt the server's movement state from the latest snapshot (caught up by Boomerang.advanceReturn) so
      -- // speed-up and heading don't drift between snapshots
      if not isServer and thrownWeaponData.SnapshotReturnVelocity then
         travelVelocity = thrownWeaponData.SnapshotReturnVelocity
         speed = math.clamp(travelVelocity.Magnitude, 0, maximumSpeed)
         if thrownWeaponData.SnapshotRecallTravelled then
            recallTravelled = thrownWeaponData.SnapshotRecallTravelled
         end
         thrownWeaponData.SnapshotReturnVelocity = nil
         thrownWeaponData.SnapshotRecallTravelled = nil
      end
      rampElapsed += deltaTime
      recallTravelled += speed * deltaTime
      thrownWeaponData.RecallTravelled = recallTravelled

      -- // Prioritize movement towards the player
      local hostPivot = getWeaponCFrame(thrownWeaponData)
      if not hostPivot then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
         return
      end

      -- // Recalled off the ground: rise to GlobalConfig.BoomerangFlightHeight while returning (independent of player
      -- // height, so jumps can't carry it over arena walls). A manual recall rises slowly and tilts toward the player,
      -- // leveling out at flight height.
      if thrownWeaponData.RecallFromDead ~= nil then
         if isManualRecallFromDead and not MANUAL_RECALL_RISES_DURING_FLIGHT then
            -- // Already lifted to flight height by the recall charge: nothing to do
         elseif isManualRecallFromDead then
            -- // Manual recall: timed smoothstep rise from rest to flight height (GlobalConfig.ManualRecallRiseSeconds)
            riseStartY = riseStartY or hostPivot.Position.Y
            local riseAlpha = math.clamp(rampElapsed / math.max(GlobalConfig.ManualRecallRiseSeconds, 0.01), 0, 1)
            local easedRise = riseAlpha * riseAlpha * (3 - 2 * riseAlpha)
            local risenY = riseStartY + (GlobalConfig.BoomerangFlightHeight - riseStartY) * easedRise
            hostPivot = (hostPivot - hostPivot.Position) + Vector3.new(hostPivot.Position.X, risenY, hostPivot.Position.Z)
         else
            -- // Automatic recall: physics already at flight height (Boomerang.recallFromDead); clients ease the drawn
            -- // height with VisualYOffset
         end

         -- // Visual only: tilt toward the player while being lifted, easing flat at flight height
         if not isServer and isManualRecallFromDead then
            -- // Exactly 0 once the lift stops (within 0.05 studs of flight height)
            local remainingRise = math.max(GlobalConfig.BoomerangFlightHeight - hostPivot.Position.Y, 0)
            local riseAlpha = math.clamp((remainingRise - 0.05) / (MANUAL_RECALL_TILT_HEIGHT - 0.05), 0, 1)
            local targetTilt = math.rad(GlobalConfig.ManualRecallMaxTiltDegrees) * riseAlpha * riseAlpha * (3 - 2 * riseAlpha) -- // smoothstep
            local currentTilt = thrownWeaponData.RecallTiltAngle or 0
            if targetTilt < currentTilt then
               currentTilt = targetTilt -- // Leveling out follows the rise directly (no lag)
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

      -- // Leaving dead into a manual recall: the dead highlight fades out slowly to match the lift
      updateOwnWeaponHighlight(player, thrownWeaponData, hostPivot.Position, nil, if isManualRecallFromDead then GlobalConfig.ManualRecallHighlightFadeOutSeconds else nil)

      local toPlayer = (rootPart.Position - hostPivot.Position)
      local horizontalDistance = getHorizontalDistance(hostPivot.Position, rootPart.Position)
      if horizontalDistance <= catchRadius and catchWeapon(player, thrownWeaponData) then
         return
      end
      local targetDirection = getHorizontalDirection(toPlayer)

      if travelVelocity.Magnitude <= 1e-5 then
         travelVelocity = targetDirection * speed
      end

      local alignment = travelVelocity.Unit:Dot(targetDirection)
      local transitionRate = (if alignment < -0.25 then 11 elseif alignment < 0.5 then 8 else 5) * momentumMultiplier
      local transitionAlpha = 1 - math.exp(-transitionRate * deltaTime)

      -- // Split velocity into the part heading at the player and the sideways part. Forward builds at the normal
      -- // momentum-scaled rate. Sideways is what makes it circle, so it is removed at least fast enough to close in:
      -- // RETURN_STEER_TIGHTNESS x (speed/distance) always spirals inward. Only tightens the turn up close.
      local forwardSpeed = travelVelocity:Dot(targetDirection)
      local sidewaysVelocity = travelVelocity - targetDirection * forwardSpeed
      if isManualRecallFromDead and GlobalConfig.ManualRecallGroundApproach then
         -- // Ground approach: speed grows linearly with distance flown, from ManualRecallApproachStartFraction of max
         -- // speed to full speed at ManualRecallFullSpeedDistance studs (over time: slow creep, then late surge).
         -- // Cmdr: tune RecallStartSpeed / RecallFullSpeedDistance / RecallSpeedCurve
         local startSpeed = maximumSpeed * math.clamp(BoomerangTuningLibrary.get(tuningToolId, "RecallStartSpeed"), 0, 1)
         local fullSpeedDistance = math.max(BoomerangTuningLibrary.get(tuningToolId, "RecallFullSpeedDistance"), 0.01)
         local curve = math.max(BoomerangTuningLibrary.get(tuningToolId, "RecallSpeedCurve"), 0.05)
         local progress = math.clamp(recallTravelled / fullSpeedDistance, 0, 1) ^ curve
         forwardSpeed = startSpeed + (maximumSpeed - startSpeed) * progress
         local speedAlpha = if maximumSpeed > 1e-3 then forwardSpeed / maximumSpeed else 1
         thrownWeaponData.RecallSpinScale = speedAlpha * speedAlpha -- // Spin builds up with the speed
      elseif isManualRecallFromDead then
         -- // Manual recall: slow at first, then a steep surge to full speed (convex curve over time)
         local rampAlpha = math.clamp(rampElapsed / rampSeconds, 0, 1)
         local startFraction = GlobalConfig.ManualRecallRampStartFraction
         forwardSpeed = maximumSpeed * (startFraction + (1 - startFraction) * rampAlpha ^ rampPower)
         thrownWeaponData.RecallSpinScale = rampAlpha * rampAlpha -- // Spin builds up over the same time
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
            -- Near head-on hit on a convex corner tip gives a near-zero tangent; fall back to the travel direction's
            -- tangents so it isn't stuck
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
            -- Slide direction is obstructed (common at convex corners); try the opposite tangent
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

         -- blendedDirection can diverge from the tested `direction` while momentum decays; re-check it to avoid
         -- clipping into a corner
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
      if isServer then -- // Only the server decides hits (see the flight loop)
         for _, victimModel in ipairs(spherecastCharacterHitbox(rayOrigin, characterDirection, characterRayDistance, hitboxRadius, player)) do
            damagedPlayer(player, boomerangId, thrownWeaponData, victimModel)
         end
      end

      thrownWeaponData.Direction = direction
      thrownWeaponData.Speed = math.max(speed, slideSpeed)

      local currentPivot = getWeaponCFrame(thrownWeaponData)
      if currentPivot then
         SharedTasks.ThrownWeaponMoved:Execute("serial", player, thrownWeaponData.ToolId, currentPivot.Position, true)
      end
      if isServer and os.clock() >= nextReplicationAt and currentPivot then
         nextReplicationAt = os.clock() + REPLICATION_RATE
         fireSnapshot(player.UserId, currentPivot.Position, direction, thrownWeaponData.Speed, thrownWeaponData.State, nil, thrownWeaponData.RecallTravelled or 0)
      end

      local newPivot = getWeaponCFrame(thrownWeaponData)
      if newPivot and getHorizontalDistance(newPivot.Position, rootPart.Position) <= catchRadius and catchWeapon(player, thrownWeaponData) then
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
      fireSnapshot(player.UserId, currentPivot.Position, immediateDirection, thrownWeaponData.Speed or speed, thrownWeaponData.State, nil, thrownWeaponData.RecallTravelled or 0)
   end
end

-- // Hook: owner held recall on a dead boomerang for GlobalConfig.RecallCharge: it starts returning
DeadWeaponLogic.onRecallCharged = function(player: Player, deadWeaponData: DeadWeapons.Data)
   Boomerang.recallFromDead(player, deadWeaponData, true)
end

-- // Hook: a dying boomerang sliding with nothing to land on returns on its own (Dead.luau can't require this module)
DeadWeaponLogic.onSlidingAway = function(player: Player, deadWeaponData: DeadWeapons.Data)
   if deadWeaponData.HasBeenDead then
      return -- // Once Dead, never an automatic recall
   end
   Boomerang.recallFromDead(player, deadWeaponData, false)
end

-- // Hook: a dying boomerang with line of sight within DyingBoomerangRecallDistance (horizontal) resumes its recall
-- // even at 0 energy. Same recall as the sliding-away hook (Dead.luau can't require this module).
DeadWeaponLogic.checkRecallWhileDying = function(player: Player, deadWeaponData: DeadWeapons.Data, position: Vector3): boolean
   if DeadWeapons.Data[player] ~= deadWeaponData or deadWeaponData.State ~= DeadWeapons.StateEnum.Dying then
      return false
   end
   -- // Once Dead it never recalls by itself again (e.g. when a manual recall is released and it drops back in reach)
   if deadWeaponData.HasBeenDead then
      return false
   end
   local toolData = Tools[deadWeaponData.ToolId]
   local character = player.Character
   local targetPart = character and getPlayerTargetPart(character)
   if not toolData or not toolData.Boomerang or not targetPart then
      return false
   end
   if not isPlayerInRecallReach(player, position, toolData, deadWeaponData) then
      return false
   end
   Boomerang.recallFromDead(player, deadWeaponData, false)
   return ThrownWeapons.Data[player] ~= nil
end

-- // Server only. Boomerangs thrown from now on get (or no longer get) the red server-position part; ones already in flight are unchanged.
-- // Server: draw (or stop drawing) every boomerang's hit sweep as it flies (Cmdr `viewhitbox`)
function Boomerang.setRaycastVisualizersEnabled(value: boolean)
   assert(isServer, "Boomerang.setRaycastVisualizersEnabled is server only")
   raycastVisualizersEnabled = value
end

function Boomerang.setProjectileVisualizerEnabled(value: boolean)
   assert(isServer, "Boomerang.setProjectileVisualizerEnabled is server only")
   projectileVisualizerEnabled = value
end

-- // Client: position of a returning boomerang after `seconds` more of the server's return movement, from a snapshot.
-- // Replays the recall loop's speed-up (manual recall: by distance flown) and steering in small steps, without
-- // obstructions (a bounce sends its own snapshot). Returns position, velocity and distance flown since the recall
-- // started.
function Boomerang.advanceReturn(options: {
   ToolId: string,
   Position: Vector3,
   Velocity: Vector3,
   Target: Vector3,
   RecallTravelled: number,
   IsManualRecall: boolean,
   ReturnSpeedMultiplier: number?,
   Seconds: number,
}): (Vector3, Vector3, number)
   local toolData = Tools[options.ToolId]
   local position, velocity, travelled = options.Position, options.Velocity, options.RecallTravelled
   if not toolData or not toolData.Boomerang or options.Seconds <= 0 then
      return position, velocity, travelled
   end
   local multiplier = options.ReturnSpeedMultiplier or 1
   local isManual = options.IsManualRecall
   local maximumSpeed = BoomerangTuningLibrary.get(options.ToolId, if isManual then "RecallSpeed" else "ThrowSpeed") * multiplier
   local momentumMultiplier = if isManual then BoomerangTuningLibrary.get(options.ToolId, "RecallCurveAcceleration") else 1
   local catchRadius = math.max(RECALL_CATCH_RADIUS_MIN, toolData.Boomerang.HitboxRadius * 1.25)
   local startSpeed = maximumSpeed * math.clamp(BoomerangTuningLibrary.get(options.ToolId, "RecallStartSpeed"), 0, 1)
   local fullSpeedDistance = math.max(BoomerangTuningLibrary.get(options.ToolId, "RecallFullSpeedDistance"), 0.01)
   local curve = math.max(BoomerangTuningLibrary.get(options.ToolId, "RecallSpeedCurve"), 0.05)

   local remaining = options.Seconds
   while remaining > 1e-4 do
      local deltaTime = math.min(RETURN_PREDICTION_STEP, remaining)
      remaining -= deltaTime
      local toTarget = Vector3.new(options.Target.X - position.X, 0, options.Target.Z - position.Z)
      local horizontalDistance = toTarget.Magnitude
      if horizontalDistance <= catchRadius then
         break -- // It would be caught here
      end
      local targetDirection = toTarget.Unit
      if velocity.Magnitude <= 1e-5 then
         velocity = targetDirection * velocity.Magnitude
      end
      local alignment = if velocity.Magnitude > 1e-5 then velocity.Unit:Dot(targetDirection) else 1
      local transitionRate = (if alignment < -0.25 then 11 elseif alignment < 0.5 then 8 else 5) * momentumMultiplier
      local transitionAlpha = 1 - math.exp(-transitionRate * deltaTime)
      local forwardSpeed = velocity:Dot(targetDirection)
      local sidewaysVelocity = velocity - targetDirection * forwardSpeed
      if isManual and GlobalConfig.ManualRecallGroundApproach then
         local progress = math.clamp(travelled / fullSpeedDistance, 0, 1) ^ curve
         forwardSpeed = startSpeed + (maximumSpeed - startSpeed) * progress
      else
         forwardSpeed += (maximumSpeed - forwardSpeed) * transitionAlpha
      end
      local steerRate = math.max(transitionRate, RETURN_STEER_TIGHTNESS * velocity.Magnitude / math.max(horizontalDistance, catchRadius))
      sidewaysVelocity *= math.exp(-steerRate * deltaTime)
      velocity = targetDirection * forwardSpeed + sidewaysVelocity
      if velocity.Magnitude > maximumSpeed then
         velocity = velocity.Unit * maximumSpeed
      end
      position += velocity * deltaTime
      travelled += velocity.Magnitude * deltaTime
   end
   return position, velocity, travelled
end

return Boomerang
