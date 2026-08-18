local Stab = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)

local isServer = RunService:IsServer()

local CameraController
local CharacterRenderController
local AnimationController
local WeaponController
local WeaponService
local CharacterService

if isServer then
   WeaponService = require(game.ServerStorage.Server.Core.WeaponService)
   CharacterService = require(game.ServerStorage.Server.Core.CharacterService)
else
   AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
   WeaponController = require(ReplicatedStorage.Client.Core.WeaponController)
   CameraController = require(ReplicatedStorage.Client.Core.CustomCameraController)
   CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
end

-------------------------------------------------------------------------------
-- LOCAL VARIABLES
-------------------------------------------------------------------------------

local STAB_COOLDOWN = 1

local HITBOX_SIZE = Vector3.new(2, 2, 3)
local HITBOX_DURATION = .2
local HITBOX_DELAY = .08
local HITBOX_DISTANCE = 1
local HITBOX_VERTICAL_OFFSET = -2
local STAB_KILL_DAMAGE = 100000
local STAB_DISTANCE = 2 + HITBOX_DISTANCE
local PARRY_DISTANCE = 3 + HITBOX_DISTANCE

local PARRY_STAGGER_INITIAL_SPEED = 48
local PARRY_STAGGER_DECELERATION_DURATION = .25
local PARRY_STAGGER_TOTAL_DURATION = .3
local PARRY_STAGGER_MIN_DIRECTION_DISTANCE = .05
local PARRY_FACING_DOT_THRESHOLD = .4

local HITBOX_VISUALIZER_COLOR = Color3.new(0.164706, 0.960784, 0.007843)
local HITBOX_CHECK_INTERVAL = 1 / 20

local Cooldowns: {[Player]: number} = {}
local ActiveStabs: {
   [Player]: {
      RunId: number,
      StartedAt: number,
      EndsAt: number,
      Connection: RBXScriptConnection?,
      Visualizer: BasePart?
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

local function getHitboxCFrame(player: Player, rootPart: BasePart, forwardExtension: number?): CFrame
   local lookDirection = getLookDirection(player, rootPart)
   local extension = forwardExtension or 0
   local forwardOffset = HITBOX_DISTANCE + (extension * .5)
   local center = rootPart.Position + lookDirection * forwardOffset + Vector3.new(0, HITBOX_VERTICAL_OFFSET, 0)
   return CFrame.lookAt(center, center + lookDirection)
end

local function createHitboxVisualizer(cframe: CFrame, size: Vector3, color: Color3)
   local visualizer = Instance.new("Part")
   visualizer.Name = "StabHitboxVisualizer"
   visualizer.Anchored = true
   visualizer.CanCollide = false
   visualizer.CanTouch = false
   visualizer.CanQuery = false
   visualizer.Transparency = .5
   visualizer.Color = color
   visualizer.Size = size
   visualizer.CFrame = cframe
   visualizer.Parent = workspace

   return visualizer
end

local function updateHitboxVisualizer(visualizer: BasePart?, cframe: CFrame)
   if not visualizer or not visualizer.Parent then
      return
   end

   visualizer.CFrame = cframe
end

local function destroyHitboxVisualizer(visualizer: BasePart?)
   if visualizer and visualizer.Parent then
      visualizer:Destroy()
   end
end

local function getHitPlayers(player: Player, character: Model, cframe: CFrame, size: Vector3, overlapParams: OverlapParams): {Player}
   local hitPlayers = {}
   local seenPlayers = {}
   local parts = workspace:GetPartBoundsInBox(cframe, size, overlapParams)

   for _, part in ipairs(parts) do
      local hitCharacter = part:FindFirstAncestorOfClass("Model")
      if hitCharacter and hitCharacter ~= character then
         local hitPlayer = game.Players:GetPlayerFromCharacter(hitCharacter)
         if hitPlayer and hitPlayer ~= player and not seenPlayers[hitPlayer] then
            seenPlayers[hitPlayer] = true
            table.insert(hitPlayers, hitPlayer)
         end
      end
   end

   return hitPlayers
end

local function disconnect(player: Player)
   local stabState = ActiveStabs[player]
   if stabState and stabState.Connection then
      stabState.Connection:Disconnect()
   end

   if stabState and stabState.Visualizer then
      destroyHitboxVisualizer(stabState.Visualizer)
   end

   Cooldowns[player] = nil
   ActiveStabs[player] = nil
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
   warn(`begin stagger`)
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

function Stab.onClientSimulation(userId: number, timestamp: number)
   if isServer or typeof(timestamp) ~= "number" then
      return
   end

   local player = Players:GetPlayerByUserId(userId)
   if not player then
      return
   end

   local endsAt = timestamp + HITBOX_DURATION
   if workspace:GetServerTimeNow() >= endsAt then
      return
   end

   local activationSoundChannelId = `{player.UserId}_stab`
   SoundLibrary.play(activationSoundChannelId, Sounds.Data.Stab.Name, player.Character.PrimaryPart, nil, true)

   if AnimationController then
      -- TODO: adjust based on timestamp..?
      AnimationController.playCoreAnimation(player, "Stab")
   end

   disconnect(player)

   local previousRunId = ActiveStabs[player] and ActiveStabs[player].RunId or 0
   local runId = previousRunId + 1
   ActiveStabs[player] = {
      RunId = runId,
      StartedAt = timestamp,
      EndsAt = endsAt,
      Connection = nil,
      Visualizer = nil,
   }

   scheduleStabCleanup(player, runId, endsAt)
end

local function applyParry(stabberPlayer: Player, stabberRootPart: BasePart, victimPlayer: Player, victimRootPart: BasePart)
   if ActiveStaggers[stabberPlayer] or ActiveStaggers[victimPlayer] then
      return
   end
   local stabberToVictim = getHorizontalDirectionFromTo(stabberPlayer, stabberRootPart, victimRootPart)
   local victimToStabber = -stabberToVictim

   beginStagger(stabberPlayer, victimToStabber)
   beginStagger(victimPlayer, stabberToVictim)

   if not isServer and CameraController then
      if stabberPlayer == game.Players.LocalPlayer or victimPlayer == game.Players.LocalPlayer then
         CameraController.parryEffect()
      end
   end
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

   local gameStateData = GameStateLibrary.getGameStateData()
   if gameStateData.CurrentRoundData:Get() == nil then
      return false
   end

   local cooldown = Cooldowns[player]
   if cooldown and os.clock() < cooldown then
      return false
   end
   
   return true
end

function Stab.activate(player: Player)
   local character = player.Character
   if not character then
      return
   end

   local rootPart = character.PrimaryPart
   if not rootPart then
      return
   end

   Cooldowns[player] = os.clock() + STAB_COOLDOWN
   stabCount[player] = (stabCount[player] or 0) + 1

   local previousRunId = ActiveStabs[player] and ActiveStabs[player].RunId or 0
   local runId = previousRunId + 1
   local shouldShowVisualizer = isServer and GlobalConfig.ParryVisualizersEnabled

   local overlapParams = OverlapParams.new()
   overlapParams.FilterType = Enum.RaycastFilterType.Exclude
   overlapParams.FilterDescendantsInstances = {character}
   -- "Players" doesn't collide with "Players" (players don't push each other), so filtering the
   -- query by that group would silently exclude every other player's hitbox; "HandWeapons" does
   -- collide with "Players" and correctly returns overlapping player hitboxes for this melee attack
   overlapParams.CollisionGroup = CollisionGroupConstants.HandWeapons

   local registeredKillHits: {[Player]: boolean} = {}

   local startedAt = os.clock()
   local stabState = {
      RunId = runId,
      StartedAt = startedAt,
      EndsAt = startedAt + HITBOX_DURATION,
      Connection = nil :: RBXScriptConnection?,
      Visualizer = nil :: BasePart?
   }
   ActiveStabs[player] = stabState

   local checkAccumulator = 0

   local function everyFrame(_dt)
      if not ActiveStabs[player] or ActiveStabs[player].RunId ~= runId then
         return
      end

      local elapsed = os.clock() - startedAt
      if elapsed < HITBOX_DELAY then
         return
      end

      if elapsed > HITBOX_DURATION then
         disconnect(player)
         return
      end

      local latestCharacter = player.Character
      local latestRootPart = latestCharacter and latestCharacter.PrimaryPart
      if not latestCharacter or not latestRootPart then
         disconnect(player)
         return
      end

      overlapParams.FilterDescendantsInstances = {latestCharacter}

      local hitboxCFrame = getHitboxCFrame(player, latestRootPart)

      if shouldShowVisualizer then
         if not stabState.Visualizer or not stabState.Visualizer.Parent then
            stabState.Visualizer = createHitboxVisualizer(hitboxCFrame, HITBOX_SIZE, HITBOX_VISUALIZER_COLOR)
         else
            updateHitboxVisualizer(stabState.Visualizer, hitboxCFrame)
         end
      else
         destroyHitboxVisualizer(stabState.Visualizer)
         stabState.Visualizer = nil
      end

      checkAccumulator += _dt
      if checkAccumulator < HITBOX_CHECK_INTERVAL then
         return
      end
      checkAccumulator = 0

      local hitTargets = getHitPlayers(player, latestCharacter, hitboxCFrame, HITBOX_SIZE, overlapParams)
      for _, victimPlayer in ipairs(hitTargets) do
         local victimCharacter = victimPlayer.Character
         local victimRootPart = victimCharacter and victimCharacter.PrimaryPart
         if not victimRootPart then
            continue
         end

         local targetDistance = getHorizontalDistance(latestRootPart, victimRootPart)
         local victimIsStabbing = ActiveStabs[victimPlayer] ~= nil

         local shouldParry = victimIsStabbing
            and targetDistance <= PARRY_DISTANCE
            and arePlayersFacingEachOtherForParry(player, latestRootPart, victimPlayer, victimRootPart)

         if shouldParry then
            print("[Stab] Hit player to parry:", player.Name, "<->", victimPlayer.Name)
            applyParry(player, latestRootPart, victimPlayer, victimRootPart)
         elseif targetDistance <= STAB_DISTANCE and not registeredKillHits[victimPlayer] then
            registeredKillHits[victimPlayer] = true

            local eventId = `{player.UserId}_vs_{victimPlayer.UserId}`
            SoundLibrary.play(eventId, Sounds.Data.Kill.Name, victimCharacter.PrimaryPart, nil, true)
            ParticlesLibrary.emit(eventId, "Slash", victimCharacter.PrimaryPart.Position, 1, nil, true)

            local victimHumanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
            if victimHumanoid and victimHumanoid.Health > 0 then
               CombatLibrary.attackHitPlayer(player, "Stab", victimPlayer, victimHumanoid, STAB_KILL_DAMAGE)
            end
         end
      end
   end

   stabState.Connection = RunService.Heartbeat:Connect(everyFrame)
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

return Stab