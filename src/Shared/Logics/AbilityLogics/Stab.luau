local Stab = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local LagCompensationLibrary = require(ReplicatedStorage.Shared.Library.LagCompensationLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local WeaponLibrary = require(ReplicatedStorage.Shared.Library.WeaponLibrary)
local ThrownWeaponsData = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local DeadWeaponsData = require(ReplicatedStorage.Shared.Referential.DeadWeapons)
local GameTeamLibrary = require(ReplicatedStorage.Shared.Library.GameTeamLibrary)

local isServer = RunService:IsServer()

local CameraController
local CharacterRenderController
local ToolController
local AnimationController
local WeaponController
local WeaponService
local CharacterService
local BotService

if isServer then
   WeaponService = require(game.ServerStorage.Server.Core.WeaponService)
   CharacterService = require(game.ServerStorage.Server.Core.CharacterService)
   BotService = require(game.ServerStorage.Server.Core.BotService)
else
   AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
   WeaponController = require(ReplicatedStorage.Client.Core.WeaponController)
   CameraController = require(ReplicatedStorage.Client.Core.CustomCameraController)
   CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
   ToolController = require(ReplicatedStorage.Client.Core.ToolController)
end

-------------------------------------------------------------------------------
-- LOCAL VARIABLES
-------------------------------------------------------------------------------

local STAB_COOLDOWN = .5
local SERVER_COOLDOWN_GRACE = .1 -- // The server accepts a swing this much before its cooldown ends (the player's game may have ended it a moment sooner)
local SWING_STALE_SECONDS = 1 -- // Clients: another player's swing heard about later than this isn't shown at all (e.g. after the game was in the background)
local SWEEP_MAX_SKIP_FRACTION = .5 -- // Clients: a late swing's sweep skips ahead at most this much of itself, so it always shows

-- // T-125: the swing is ONE check, at the moment the blade lands (IMPACT_DELAY after the click), of a wedge in front of the player:
-- // anyone whose Hitbox (a 10-stud-tall cylinder) reaches into it, with no wall in between, is hit. It is checked against where everyone
-- // is now AND where the swinging player saw them (LagCompensationLibrary rewind: their ping plus the interpolation delay), so a swing
-- // that looked like a hit on their screen counts. The client sends where it was facing; where the player is comes only from the server
-- // (server authority: the server's character is the truth, and the player's own game predicts the same position).
local IMPACT_DELAY = .08 -- // Seconds from the click to the hit check (the blade landing in the animation)
local SWING_DURATION = .2 -- // Seconds a swing lasts on clients
local SWING_RANGE = 3 -- // Studs from the swinging player's centre to the edge of a target's Hitbox
local SWING_HALF_ANGLE = math.rad(55) -- // Half the wedge's width: 55 degrees to each side of where they face (110 total)
local SWING_HALF_HEIGHT = 2.5 -- // The wedge's half height around the swinging player's centre (a target's Hitbox adds its own)
local SWING_MAX_DIRECTION_DEVIATION = math.rad(120) -- // The most the client's reported facing may turn from the server's last known one
-- // Server authority: no client clock is trusted. When a player clicked is estimated by the server: the click's arrival less half their
-- // ping (the trip from them to the server), and the impact and parries are timed from that.
local SWING_MAX_ONE_WAY_LATENCY = .3 -- // The most the server takes off a click's arrival time (half the ping, capped)
local PARRY_WINDOW = .2 -- // Two swings clicked this close together (server-estimated) clash: a parry, if they face each other
local STAB_KILL_DAMAGE = 100000
local PARRY_DISTANCE = 6 -- // Centre to centre; beyond any reach of a swing (SWING_RANGE plus a Hitbox radius)

local PARRY_STAGGER_INITIAL_SPEED = 48
local PARRY_STAGGER_DECELERATION_DURATION = .25
local PARRY_STAGGER_TOTAL_DURATION = .3
local PARRY_STAGGER_MIN_DIRECTION_DISTANCE = .05
local PARRY_FACING_DOT_THRESHOLD = .4

-- // T-126: the swing's look. Every swing (yours at the click, others' when the server tells this client) shows the SlashAbility
-- // crescent (Shared/Assets/Particles/SlashAbility: one part, attachments "1" and "2" at its tips carrying the trails) sweeping
-- // forward in front of the player and fading out. Purely visual: the kill effect (Slash particle) is only ever played by the server.
local SWEEP_ASSET_NAME = "SlashAbility"
local SWEEP_DURATION = .2 -- // Seconds the crescent sweeps and fades
local SWEEP_SCALE = 0.56 -- // Size relative to the asset
local SWEEP_START_DISTANCE = 0.5 -- // Studs in front of the player's centre the crescent's centre starts
local SWEEP_END_DISTANCE = 1.5 -- // ...and ends (its front edge then reaches about as far as a swing hits)
local SWEEP_HEIGHT_ABOVE_HAND = 1 -- // Studs above where the weapon is held in the player's hand (when the swing starts)
local SWEEP_HEIGHT_OFFSET = 0 -- // Studs above the player's centre, if the held weapon can't be found
local SWEEP_START_TRANSPARENCY = .2

local SWING_VISUALIZER_COLOR = Color3.new(0.164706, 0.960784, 0.007843)
local SWING_VISUALIZER_LIFETIME = .4
local SWING_VISUALIZER_ARC_SEGMENTS = 10

local Cooldowns: {[Player]: number} = {}
local SwingClickTimes: {[Player]: number} = {} -- // Server: when each player's latest swing was clicked (server clock, estimated)
local ActiveStabs: {
   [Player]: {
      RunId: number,
      StartedAt: number,
      EndsAt: number,
   }
} = {}

local ActiveStaggers: {
   [Player]: {
      StartedAt: number,
      EndsAt: number,
      DecelerationEndsAt: number,
      Character: Model,
      RootPart: BasePart,
      Humanoid: Humanoid,
      Direction: Vector3,
      OriginalWalkSpeed: number,
      OriginalJumpPower: number,
      OriginalJumpHeight: number,
      OriginalAutoRotate: boolean,
   }
} = {}

local stabCount: {[Player]: number} = {}

local staggerConnection: RBXScriptConnection? = nil
local parryOccurredEvent = SimpleRemotes.getEvent("ParryOccurred")

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

-- a character's look direction is solely client-rendered, so it cannot be read from the character/root part itself;
-- the server trusts the player's most recently reported yaw from CharacterService, and the client reads its own
-- locally rendered model's orientation from CharacterRenderController
local function getLookDirection(player: Player, rootPart: BasePart): Vector3
   if isServer then
      local lookDirection = CharacterService and CharacterService.getLookDirection(player)
      if lookDirection then
         return lookDirection
      end
   else
      local renderedModel = CharacterRenderController and CharacterRenderController.getCharacterModel(player, false)
      if renderedModel then
         local lookVector = renderedModel:GetPivot().LookVector
         local horizontalLook = Vector3.new(lookVector.X, 0, lookVector.Z)
         if horizontalLook.Magnitude > 1e-5 then
            return horizontalLook.Unit
         end
      end
   end

   local horizontalLook = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
   if horizontalLook.Magnitude <= 1e-5 then
      return Vector3.new(0, 0, -1)
   end
   return horizontalLook.Unit
end

local function getHorizontalDistance(fromPart: BasePart, toPart: BasePart): number
   local delta = Vector3.new(toPart.Position.X - fromPart.Position.X, 0, toPart.Position.Z - fromPart.Position.Z)
   return delta.Magnitude
end

local function getHorizontalDirectionFromTo(fromPlayer: Player, fromPart: BasePart, toPart: BasePart): Vector3
   local delta = Vector3.new(toPart.Position.X - fromPart.Position.X, 0, toPart.Position.Z - fromPart.Position.Z)
   if delta.Magnitude <= PARRY_STAGGER_MIN_DIRECTION_DISTANCE then
      return getLookDirection(fromPlayer, fromPart)
   end
   return delta.Unit
end

local function arePlayersFacingEachOtherForParry(stabberPlayer: Player, stabberRootPart: BasePart, victimPlayer: Player, victimRootPart: BasePart): boolean
   local stabberLook = getLookDirection(stabberPlayer, stabberRootPart)
   local victimLook = getLookDirection(victimPlayer, victimRootPart)
   local stabberToVictim = getHorizontalDirectionFromTo(stabberPlayer, stabberRootPart, victimRootPart)
   local victimToStabber = -stabberToVictim

   local stabberFacingVictim = stabberLook:Dot(stabberToVictim) >= PARRY_FACING_DOT_THRESHOLD
   local victimFacingStabber = victimLook:Dot(victimToStabber) >= PARRY_FACING_DOT_THRESHOLD
   return stabberFacingVictim and victimFacingStabber
end

-- // Draws the swing's wedge for a moment (debug: GlobalConfig.ParryVisualizersEnabled)
local function showSwingVisualizer(origin: Vector3, direction: Vector3)
   local folder = Instance.new("Folder")
   folder.Name = "SwingVisualizer"

   local function addLine(fromPoint: Vector3, toPoint: Vector3)
      local length = (toPoint - fromPoint).Magnitude
      if length <= 1e-3 then
         return
      end
      local line = Instance.new("Part")
      line.Anchored = true
      line.CanCollide = false
      line.CanTouch = false
      line.CanQuery = false
      line.Material = Enum.Material.Neon
      line.Color = SWING_VISUALIZER_COLOR
      line.Transparency = .3
      line.Size = Vector3.new(.15, SWING_HALF_HEIGHT * 2, length)
      line.CFrame = CFrame.lookAt((fromPoint + toPoint) * .5, toPoint)
      line.Parent = folder
   end

   local previousPoint: Vector3? = nil
   for index = 0, SWING_VISUALIZER_ARC_SEGMENTS do
      local angle = -SWING_HALF_ANGLE + (SWING_HALF_ANGLE * 2) * (index / SWING_VISUALIZER_ARC_SEGMENTS)
      local point = origin + (CFrame.Angles(0, angle, 0) * direction) * SWING_RANGE
      if index == 0 or index == SWING_VISUALIZER_ARC_SEGMENTS then
         addLine(origin, point)
      end
      if previousPoint then
         addLine(previousPoint, point)
      end
      previousPoint = point
   end

   folder.Parent = workspace
   task.delay(SWING_VISUALIZER_LIFETIME, function()
      folder:Destroy()
   end)
end

-- // A target's Hitbox is a vertical cylinder centred on its root: Size is (height, diameter, diameter)
local function getHitboxShape(hitbox: BasePart): (number, number)
   return math.min(hitbox.Size.Y, hitbox.Size.Z) / 2, hitbox.Size.X / 2
end

-- // Whether a Hitbox (centre `targetPosition`) reaches into the swing's wedge
local function isInSwing(origin: Vector3, direction: Vector3, targetPosition: Vector3, targetRadius: number, targetHalfHeight: number): boolean
   if math.abs(targetPosition.Y - origin.Y) > targetHalfHeight + SWING_HALF_HEIGHT then
      return false
   end

   local offset = Vector3.new(targetPosition.X - origin.X, 0, targetPosition.Z - origin.Z)
   local distance = offset.Magnitude
   if distance <= targetRadius then
      return true -- // Overlapping the swinging player: hit whichever way they face
   end
   if distance - targetRadius > SWING_RANGE then
      return false
   end

   -- // Inside the wedge if any part of the cylinder is: the angle to its centre, less the angle its radius covers from here
   local angleToCentre = math.acos(math.clamp(direction:Dot(offset / distance), -1, 1))
   local angleCovered = math.asin(math.clamp(targetRadius / distance, 0, 1))
   return angleToCentre - angleCovered <= SWING_HALF_ANGLE
end

-- // No wall between the swinging player and the near edge of the target's Hitbox
local function hasLineOfSight(origin: Vector3, targetPosition: Vector3, targetRadius: number, raycastParams: RaycastParams): boolean
   local offset = Vector3.new(targetPosition.X - origin.X, targetPosition.Y - origin.Y, targetPosition.Z - origin.Z)
   local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
   if horizontalDistance <= targetRadius then
      return true
   end
   local reach = offset * ((horizontalDistance - targetRadius) / horizontalDistance)
   if reach.Magnitude <= 1e-3 then
      return true
   end
   return RaycastsUtility.raycastProjectileObstruction(origin, reach.Unit, reach.Magnitude, raycastParams) == nil
end

-- // Server: the facing the client reported with the swing, checked against the server's own view (falls back to it if missing or
-- // implausible). Where the player is and when they clicked are never taken from the client.
local function readSwingParams(player: Player, rootPart: BasePart, params: any): Vector3
   local serverDirection = getLookDirection(player, rootPart)
   local direction = serverDirection

   if type(params) == "table" then
      local reportedDirection = params.Direction
      if typeof(reportedDirection) == "Vector3" then
         local horizontal = Vector3.new(reportedDirection.X, 0, reportedDirection.Z)
         if horizontal == horizontal and horizontal.Magnitude > .5 then
            horizontal = horizontal.Unit
            local deviation = math.acos(math.clamp(horizontal:Dot(serverDirection), -1, 1))
            if deviation <= SWING_MAX_DIRECTION_DEVIATION then
               direction = horizontal
            end
         end
      end
   end

   return direction
end

-- // Server: how long a message from this player takes to get here (half their ping), capped
local function getOneWayLatency(player: Player): number
   return math.clamp(player:GetNetworkPing() * .5, 0, SWING_MAX_ONE_WAY_LATENCY)
end

-- // Server: whether `player`'s latest swing was clicked within PARRY_WINDOW of `clickTime` (both server-estimated)
local function swungNear(player: Player, clickTime: number): boolean
   local swingClickTime = SwingClickTimes[player]
   return swingClickTime ~= nil and math.abs(swingClickTime - clickTime) <= PARRY_WINDOW
end

local function disconnect(player: Player)
   ActiveStabs[player] = nil
   SwingClickTimes[player] = nil
end

-- // Client: the SlashAbility crescent sweeping out in front of `player`, facing where they swung. `elapsed` skips ahead when the
-- // swing was heard about late (another player's swing), so it ends when it would have.
local sweepTemplate: BasePart? = nil
local function playSwingSweep(player: Player, elapsed: number)
   if isServer or elapsed >= SWEEP_DURATION then
      return
   end
   local character = player.Character
   local rootPart = character and character.PrimaryPart
   if not rootPart then
      return
   end

   if not sweepTemplate then
      local asset = ReplicatedStorage.Shared.Assets.Particles:FindFirstChild(SWEEP_ASSET_NAME)
      if not asset or not asset:IsA("BasePart") then
         warn(`Stab: swing effect {SWEEP_ASSET_NAME} not found in Shared/Assets/Particles`)
         return
      end
      sweepTemplate = asset
   end

   local sweep = (sweepTemplate :: BasePart):Clone()
   for _, descendant in ipairs(sweep:GetDescendants()) do
      if descendant:IsA("BodyMover") or descendant:IsA("Constraint") then
         descendant:Destroy() -- // Moved by this code, not by physics
      elseif descendant:IsA("Attachment") then
         descendant.Position *= SWEEP_SCALE -- // Attachments don't scale with the part: keep the trails on the tips
      end
   end
   sweep.Anchored = true
   sweep.CanCollide = false
   sweep.CanQuery = false
   sweep.CanTouch = false
   sweep.CastShadow = false
   sweep.Size *= SWEEP_SCALE

   local direction = getLookDirection(player, rootPart) -- // Where they swung; it doesn't turn with them during the sweep
   -- // At the height of the weapon in their hand (plus a little), kept relative to them while they move during the sweep
   local heightOffset = SWEEP_HEIGHT_OFFSET
   local heldWeaponPosition = ToolController and ToolController.getToolPivotPosition(player)
   if heldWeaponPosition then
      heightOffset = heldWeaponPosition.Y - rootPart.Position.Y + SWEEP_HEIGHT_ABOVE_HAND
   end
   local function place(alpha: number)
      local eased = 1 - (1 - alpha) ^ 2 -- // Fast out, slowing at the end
      local currentRoot = character.PrimaryPart or rootPart
      local base = currentRoot.Position + Vector3.new(0, heightOffset, 0)
      local centre = base + direction * (SWEEP_START_DISTANCE + (SWEEP_END_DISTANCE - SWEEP_START_DISTANCE) * eased)
      sweep.CFrame = CFrame.lookAt(centre, centre + direction) -- // The asset's crescent faces its -Z (front)
      sweep.Transparency = SWEEP_START_TRANSPARENCY + (1 - SWEEP_START_TRANSPARENCY) * eased
   end

   place(elapsed / SWEEP_DURATION)
   sweep.Parent = workspace:FindFirstChild("Particles") or workspace

   local trailLifetime = 0
   for _, descendant in ipairs(sweep:GetDescendants()) do
      if descendant:IsA("Trail") then
         trailLifetime = math.max(trailLifetime, descendant.Lifetime)
      end
   end

   local startedAt = os.clock() - elapsed
   local connection: RBXScriptConnection? = nil
   connection = RunService.RenderStepped:Connect(function()
      local alpha = (os.clock() - startedAt) / SWEEP_DURATION
      if alpha >= 1 or not sweep.Parent then
         (connection :: RBXScriptConnection):Disconnect()
         sweep.Transparency = 1
         -- // It stops moving, so the trails stop growing and fade out on their own before it goes
         task.delay(trailLifetime, function()
            sweep:Destroy()
         end)
         return
      end
      place(alpha)
   end)
end

local function scheduleStabCleanup(player: Player, runId: number, endsAt: number)
   task.delay(math.max(0, endsAt - workspace:GetServerTimeNow()), function()
      local stabState = ActiveStabs[player]
      if stabState and stabState.RunId == runId then
         disconnect(player)
      end
   end)
end

local function cancelParryCameraEffectIfLocal(player: Player)
   if isServer or not CameraController then
      return
   end
   if player ~= game.Players.LocalPlayer then
      return
   end

   local cancelFn = CameraController.cancelParryEffect
   if cancelFn then
      cancelFn()
   end
end

local function cancelStagger(player: Player)
   local stagger = ActiveStaggers[player]
   if not stagger then
      return
   end

   local humanoid = stagger.Humanoid
   if humanoid and humanoid.Parent and humanoid.Health > 0 then
      humanoid.WalkSpeed = stagger.OriginalWalkSpeed
      humanoid.JumpPower = stagger.OriginalJumpPower
      humanoid.JumpHeight = stagger.OriginalJumpHeight
      humanoid.AutoRotate = stagger.OriginalAutoRotate
   end

   local rootPart = stagger.RootPart
   if rootPart and rootPart.Parent then
      local velocity = rootPart.AssemblyLinearVelocity
      rootPart.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
      if isServer and rootPart:CanSetNetworkOwnership() then
         rootPart:SetNetworkOwnershipAuto()
      end
   end

   ActiveStaggers[player] = nil
   cancelParryCameraEffectIfLocal(player)
end

local function cancelAllStaggers()
   for player in pairs(ActiveStaggers) do
      cancelStagger(player)
   end
end

local function stopStaggerUpdateConnectionIfIdle()
   if next(ActiveStaggers) then
      return
   end

   if staggerConnection then
      staggerConnection:Disconnect()
      staggerConnection = nil
   end
end

local function updateStaggers()
   local now = os.clock()

   for player, stagger in pairs(ActiveStaggers) do
      if player.Character ~= stagger.Character then
         cancelStagger(player)
         continue
      end

      if not stagger.RootPart.Parent or not stagger.Humanoid.Parent or stagger.Humanoid.Health <= 0 then
         cancelStagger(player)
         continue
      end

      if now >= stagger.EndsAt then
         cancelStagger(player)
         continue
      end

      local speed = 0
      if now < stagger.DecelerationEndsAt then
         local alpha = math.clamp((now - stagger.StartedAt) / math.max(PARRY_STAGGER_DECELERATION_DURATION, 1e-5), 0, 1)
         speed = PARRY_STAGGER_INITIAL_SPEED * (1 - alpha)
      end

      local velocity = stagger.RootPart.AssemblyLinearVelocity
      stagger.RootPart.AssemblyLinearVelocity = Vector3.new(stagger.Direction.X * speed, velocity.Y, stagger.Direction.Z * speed)
   end

   stopStaggerUpdateConnectionIfIdle()
end

local function ensureStaggerUpdateConnection()
   if staggerConnection then
      return
   end

   staggerConnection = RunService.Heartbeat:Connect(updateStaggers)
end

local function beginStagger(player: Player, direction: Vector3)
   local character = player.Character
   if not character then
      return
   end

   local rootPart = character.PrimaryPart
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not rootPart or not humanoid or humanoid.Health <= 0 then
      return
   end

   cancelStagger(player)

   local originalWalkSpeed = humanoid.WalkSpeed
   local originalJumpPower = humanoid.JumpPower
   local originalJumpHeight = humanoid.JumpHeight
   local originalAutoRotate = humanoid.AutoRotate

   if isServer and rootPart:CanSetNetworkOwnership() then
      rootPart:SetNetworkOwner(nil)
   end

   humanoid.WalkSpeed = 0
   humanoid.JumpPower = 0
   humanoid.JumpHeight = 0
   humanoid.AutoRotate = false

   local now = os.clock()
   ActiveStaggers[player] = {
      StartedAt = now,
      EndsAt = now + PARRY_STAGGER_TOTAL_DURATION,
      DecelerationEndsAt = now + PARRY_STAGGER_DECELERATION_DURATION,
      Character = character,
      RootPart = rootPart,
      Humanoid = humanoid,
      Direction = direction,
      OriginalWalkSpeed = originalWalkSpeed,
      OriginalJumpPower = originalJumpPower,
      OriginalJumpHeight = originalJumpHeight,
      OriginalAutoRotate = originalAutoRotate,
   }

   ensureStaggerUpdateConnection()
end

function Stab.onPickup(userId: number, timestamp: number)
   if isServer or typeof(timestamp) ~= "number" then
      return
   end

   local player = Players:GetPlayerByUserId(userId)
   local character = player and player.Character
   local rootPart = character and character.PrimaryPart
   if not player or not rootPart then
      return
   end

   -- // Every swing is shown, even one heard about late (another player's, sent over the reliable AbilityReplication event): the
   -- // animation and sound play now, and the sweep skips ahead a little so it ends about when it would have
   local lateness = math.max(0, workspace:GetServerTimeNow() - timestamp)
   if lateness > SWING_STALE_SECONDS then
      return
   end
   local endsAt = workspace:GetServerTimeNow() + SWING_DURATION

   Cooldowns[player] = os.clock() + STAB_COOLDOWN

   local activationSoundChannelId = `{player.UserId}_stab`
   SoundLibrary.play(activationSoundChannelId, Sounds.Data.Stab.Name, rootPart, nil, true)

   if AnimationController then
      AnimationController.playCoreAnimation(player, "Stab")
   end

   playSwingSweep(player, math.min(lateness, SWEEP_DURATION * SWEEP_MAX_SKIP_FRACTION))

   disconnect(player)

   local previousRunId = ActiveStabs[player] and ActiveStabs[player].RunId or 0
   local runId = previousRunId + 1
   ActiveStabs[player] = {
      RunId = runId,
      StartedAt = timestamp,
      EndsAt = endsAt,
   }

   scheduleStabCleanup(player, runId, endsAt)
end

local function applyParry(stabberPlayer: Player, stabberRootPart: BasePart, victimPlayer: Player, victimRootPart: BasePart)
   if ActiveStaggers[stabberPlayer] or ActiveStaggers[victimPlayer] then
      return
   end

   if not isServer then
      if CameraController and (stabberPlayer == Players.LocalPlayer or victimPlayer == Players.LocalPlayer) then
         CameraController.parryEffect()
      end
      return
   end

   local stabberToVictim = getHorizontalDirectionFromTo(stabberPlayer, stabberRootPart, victimRootPart)
   local victimToStabber = -stabberToVictim

   beginStagger(stabberPlayer, victimToStabber)
   beginStagger(victimPlayer, stabberToVictim)
   parryOccurredEvent:FireClient(stabberPlayer)
   parryOccurredEvent:FireClient(victimPlayer)
end

local function isPlayerAiming(player: Player): boolean
   if isServer then
      if WeaponService then
         return WeaponService.isAiming(player)
      end
   else
      if player == Players.LocalPlayer and WeaponController then
         return WeaponController.getWeaponState() == WeaponController.CurrentWeaponState.Aiming
      end
   end
   return false
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Stab.canActivate(player: Player): boolean
   if isPlayerAiming(player) then
      return false
   end

   if WeaponLibrary.playerIsWeaponLocked(player) then
      return false
   end

   local gameStateData = GameStateLibrary.getGameStateData()
   if gameStateData.CurrentRoundData:Get() == nil then
      return false
   end

   if ThrownWeaponsData.Data[player] or DeadWeaponsData.Data[player] then
      return false
   end

   -- // The server forgives a swing that arrives just before its cooldown ends (SERVER_COOLDOWN_GRACE), so a swing the player's game
   -- // allowed isn't thrown away over a tiny timing difference. The player's own game stays strict.
   local cooldown = Cooldowns[player]
   local grace = if isServer then SERVER_COOLDOWN_GRACE else 0
   if cooldown and os.clock() < cooldown - grace then
      return false
   end
   
   return true
end

-- // Client: where this player faced as they swung, sent with the click (Stab.activate checks it)
function Stab.getParams()
   local player = Players.LocalPlayer
   local character = player and player.Character
   local rootPart = character and character.PrimaryPart
   if not rootPart then
      return nil
   end
   return {
      Direction = getLookDirection(player, rootPart),
   }
end

-- // Server: a swing clicked at `clickTime` reached `victimPlayer`. If the victim also swung within PARRY_WINDOW of it, and they are close
-- // and facing each other, it's a parry; otherwise the victim is hit. A victim who could still have swung in time (close and facing, but
-- // their click not here yet because of their ping) is waited for, until their latest possible click would have arrived.
local function settleHit(player: Player, character: Model, victimPlayer: Player, clickTime: number)
   local victimCharacter = victimPlayer.Character
   local deadline = clickTime + PARRY_WINDOW + getOneWayLatency(victimPlayer)

   task.spawn(function()
      while true do
         local rootPart = character.PrimaryPart
         local humanoid = character:FindFirstChildOfClass("Humanoid")
         local victimRootPart = victimCharacter and victimCharacter.PrimaryPart
         local victimHumanoid = victimCharacter and victimCharacter:FindFirstChildOfClass("Humanoid")
         if player.Character ~= character or victimPlayer.Character ~= victimCharacter
            or not rootPart or not humanoid or humanoid.Health <= 0
            or not victimRootPart or not victimHumanoid or victimHumanoid.Health <= 0
         then
            return -- // One of them died or left in the meantime (e.g. the victim's own swing landed first)
         end

         local canClash = getHorizontalDistance(rootPart, victimRootPart) <= PARRY_DISTANCE
            and arePlayersFacingEachOtherForParry(player, rootPart, victimPlayer, victimRootPart)
         if canClash and swungNear(victimPlayer, clickTime) then
            applyParry(player, rootPart, victimPlayer, victimRootPart)
            return
         end
         if not canClash or workspace:GetServerTimeNow() >= deadline then
            -- // The slash and kill sound come from CombatLibrary.attackHitPlayer, only when the hit is accepted
            CombatLibrary.attackHitPlayer(player, "Stab", victimPlayer, victimHumanoid, STAB_KILL_DAMAGE)
            return
         end
         RunService.Heartbeat:Wait()
      end
   end)
end

-- // Server: the blade lands. One check of the wedge against everyone now and where the swinging player saw them (rewound).
local function resolveSwing(player: Player, character: Model, direction: Vector3, clickTime: number)
   local rootPart = character.PrimaryPart
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if player.Character ~= character or not rootPart or not humanoid or humanoid.Health <= 0 then
      return
   end
   local origin = rootPart.Position -- // Where the server has them as the blade lands

   if GlobalConfig.ParryVisualizersEnabled then
      showSwingVisualizer(origin, direction)
   end

   local filter: { Instance } = { character }
   local charactersFolder = workspace:FindFirstChild("Characters")
   if charactersFolder then
      table.insert(filter, charactersFolder)
   end
   local raycastParams = RaycastsUtility.getProjectileObstructionParams(filter)

   local hitPlayers: { Player } = {}
   local seen: { [Player]: boolean } = {}
   local function tryTarget(victimPlayer: Player, hitbox: BasePart, position: Vector3)
      if seen[victimPlayer] then
         return
      end
      local radius, halfHeight = getHitboxShape(hitbox)
      if isInSwing(origin, direction, position, radius, halfHeight) and hasLineOfSight(origin, position, radius, raycastParams) then
         seen[victimPlayer] = true
         table.insert(hitPlayers, victimPlayer)
      end
   end

   -- // Where everyone is now
   for _, victimPlayer in ipairs(Players:GetPlayers()) do
      local victimCharacter = victimPlayer.Character
      local hitbox = victimCharacter and victimCharacter:FindFirstChild("Hitbox")
      if victimPlayer ~= player and hitbox and hitbox:IsA("BasePart") then
         tryTarget(victimPlayer, hitbox, hitbox.Position)
      end
   end

   -- // Where the swinging player saw them
   local rewindSeconds = LagCompensationLibrary.getRewindSeconds(player)
   if rewindSeconds > 0 then
      for _, target in ipairs(LagCompensationLibrary.getRewoundTargets(player, rewindSeconds)) do
         if target.Player.Character == target.Character then
            tryTarget(target.Player, target.Hitbox, target.Position)
         end
      end
   end

   for _, victimPlayer in ipairs(hitPlayers) do
      settleHit(player, character, victimPlayer, clickTime)
   end

   -- // T-127: bots (e.g. decoys) are slashed the same way: now and where the swinging player saw them
   local hitBots: { Model } = {}
   local seenBots: { [Model]: boolean } = {}
   local function tryBot(model: Model, hitbox: BasePart, position: Vector3)
      if seenBots[model] then
         return
      end
      local radius, halfHeight = getHitboxShape(hitbox)
      if isInSwing(origin, direction, position, radius, halfHeight) and hasLineOfSight(origin, position, radius, raycastParams) then
         seenBots[model] = true
         table.insert(hitBots, model)
      end
   end

   local botsFolder = workspace:FindFirstChild("Bots")
   if botsFolder then
      for _, model in ipairs(botsFolder:GetChildren()) do
         local hitbox = model:FindFirstChild("Hitbox")
         if model:IsA("Model") and hitbox and hitbox:IsA("BasePart") then
            tryBot(model, hitbox, hitbox.Position)
         end
      end
   end
   if rewindSeconds > 0 then
      for _, target in ipairs(LagCompensationLibrary.getRewoundBots(rewindSeconds)) do
         tryBot(target.Model, target.Hitbox, target.Position)
      end
   end

   for _, model in ipairs(hitBots) do
      -- // Only a bot whose owner is an enemy (another team, or the same team with friendly fire on). The owner's own bot is left to
      -- // the bot's rules (a decoy: GlobalConfig.CanHitSelfDecoy). BotService pops it (despawn, with its vanish effect).
      local ownerUserId = model:GetAttribute("OwnerUserId")
      local owner = if typeof(ownerUserId) == "number" then Players:GetPlayerByUserId(ownerUserId) else nil
      if owner and owner ~= player and not GameTeamLibrary.areEnemies(player, owner) then
         continue
      end
      if BotService and model.Parent then
         BotService.onWeaponHit(player, model)
      end
   end
end

function Stab.activate(player: Player, _activatedAt: number?, params: any)
   local character = player.Character
   if not character then
      return
   end

   local rootPart = character.PrimaryPart
   if not rootPart then
      return
   end

   -- // From the end of the previous cooldown if this swing was let in a little early (the grace never adds up to faster swinging)
   Cooldowns[player] = math.max(os.clock(), Cooldowns[player] or 0) + STAB_COOLDOWN
   stabCount[player] = (stabCount[player] or 0) + 1

   -- // When they clicked, by the server's estimate (parries compare these)
   local clickTime = workspace:GetServerTimeNow() - getOneWayLatency(player)
   SwingClickTimes[player] = clickTime

   -- // The blade lands IMPACT_DELAY after the click. A click that took longer than that to arrive is checked straight away.
   local direction = readSwingParams(player, rootPart, params)
   local secondsUntilImpact = math.max(0, clickTime + IMPACT_DELAY - workspace:GetServerTimeNow())
   if secondsUntilImpact > 0 then
      task.delay(secondsUntilImpact, resolveSwing, player, character, direction, clickTime)
   else
      resolveSwing(player, character, direction, clickTime)
   end
end

-------------------------------------------------------------------------------
-- RUNTIME
-------------------------------------------------------------------------------

PlayersUtil.PlayerRemoving:Add(function(player: Player)
   cancelStagger(player)
   stopStaggerUpdateConnectionIfIdle()
   disconnect(player)
end)

PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
   cancelStagger(player)
   stopStaggerUpdateConnectionIfIdle()
   disconnect(player)
end)

PlayersUtil.CharacterDied:Add(function(player: Player, character: Model, humanoid: Humanoid)
   cancelStagger(player)
   stopStaggerUpdateConnectionIfIdle()
   disconnect(player)
end)

GameStateLibrary.getGameStateData().CurrentRoundData:Subscribe(function()
   cancelAllStaggers()
   stopStaggerUpdateConnectionIfIdle()
end)

if not isServer then
   parryOccurredEvent.OnClientEvent:Connect(function()
      if CameraController then
         CameraController.parryEffect()
      end
   end)
end

return Stab