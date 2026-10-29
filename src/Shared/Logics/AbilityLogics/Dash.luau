local Dash = {}

-- TODO: the animation clashes badly with authoritative run animation, causing the character to wiggle around
--       address as either an animation issue or a propulsion issue
-- // Server authority (T-137): the dash is started and moved inside the simulation step on the server and on the player's own
-- // client, from the replicated jump input, so the client's prediction matches the server. See PREDICTED DASH below.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local Gamemodes = require(ReplicatedStorage.Shared.Constants.Gamemodes)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayerStatsLibrary = require(ReplicatedStorage.Shared.Library.PlayerStatsLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local LobbyLibrary = require(ReplicatedStorage.Shared.Library.LobbyLibrary)
local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)

local PlayDash = SimpleRemotes.getEvent("PlayDash")

local isServer = RunService:IsServer()
local AnimationController
local WeaponController
local WeaponService

if isServer then
   WeaponService = require(game.ServerStorage.Server.Core.WeaponService)
else
   AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
   WeaponController = require(ReplicatedStorage.Client.Core.WeaponController)
end

-------------------------------------------------------------------------------
-- LOCAL VARIABLES
-------------------------------------------------------------------------------

local DASH_SPEED = 80
local DASH_DURATION_SECONDS = 0.12
local DASH_COOLDOWN_SECONDS = 1
local DASH_DISTANCE = DASH_SPEED * DASH_DURATION_SECONDS -- // How far a full dash goes (studs)

-- // SAFE DASH config (T-136): see the SAFE DASH section below. Set SAFE_DASH_ENABLED = false to remove the behaviour entirely.
local SAFE_DASH_ENABLED = true
-- // A dash that would end over open air (or deadly water) is shortened to stop at the edge, but only if that still covers at
-- // least this fraction of the full dash distance; otherwise the full dash happens (and the player goes over the edge)
local SAFE_DASH_MIN_FRACTION = 0.5
local SAFE_DASH_GROUND_SEARCH_DEPTH = 30 -- // Studs below the feet: no standable ground within this counts as open air
local SAFE_DASH_MAX_GROUND_SLOPE_Y = 0.7 -- // Ground whose normal's Y is below this is too steep to stand on
local SAFE_DASH_EDGE_MARGIN = 1 -- // Studs a shortened dash stops short of the edge (so the torso isn't hanging over it)
local SAFE_DASH_FOOT_OFFSETS = { Vector3.zero, Vector3.new(0.6, 0, 0.6), Vector3.new(-0.6, 0, 0.6), Vector3.new(0.6, 0, -0.6), Vector3.new(-0.6, 0, -0.6) }
local SAFE_DASH_MIN_SUPPORTED_FEET = 3 -- // Of the five footprint rays above (centre first, which must always hit): the centre and one side
local BODY_BELOW_ROOT = 3 -- // Feet are this far below the root (R6)
local BODY_ABOVE_ROOT = 2.5 -- // Top of the head is this far above the root
local OBSTRUCTION_STEP_HEIGHT = 1 -- // The obstruction cast ignores anything lower than this above the feet (the Humanoid steps up it)
local OBSTRUCTION_MARGIN = 0.1 -- // Studs a dash stops short of a wall
-- // When a dash ends, its leftover speed is cut to walking speed, so it really ends where it was planned to (at 80 studs/s
-- // the momentum used to slide the player several studs further, e.g. off the edge the dash had just stopped short of)
local DASH_END_CLAMPS_SPEED = true

local COOLDOWN_EFFECT_ID = "DashCooldown"
local ABILITY_ID = "Dash"

-- // Client only: the os.clock timestamp the local player's dash cooldown shows until (display only; the real cooldown is the
-- // DashReadyAt attribute, see PREDICTED DASH)
local cooldowns: {[Player]: number} = {}

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

-- // A dash's side effects end (immunity on the server, the animation on clients)
local function endDashEffects(player: Player)
   if isServer then
      HitboxLibrary.unImmunize(player, "Dash", 0)
   end
   if AnimationController then
      AnimationController.stopCoreAnimation(player, "Dash")
   end
end

-- // Client only: the dash cooldown is shown in the effects bar (the same gui as pickups / On Fire) as a display-only effect.
-- // The countdown itself lives only in `cooldowns` above; the server never hears about this effect. Every frame this compares
-- // whether the local player's dash is cooling down with whether the effect is shown, so death, round end or any reset
-- // that clears the cooldown also removes the icon, and nothing here is event-driven.
local shownCooldownEndsAt: number? = nil -- // The cooldown (an os.clock timestamp) the effect currently shown was started for

local function updateCooldownEffect()
   local localPlayer = Players.LocalPlayer
   local cooldownEndsAt = cooldowns[localPlayer]
   if cooldownEndsAt and os.clock() >= cooldownEndsAt then
      cooldownEndsAt = nil -- // Expired
   end
   if cooldownEndsAt == shownCooldownEndsAt then
      return
   end

   if cooldownEndsAt then
      -- // The effects gui counts down with server time, so convert the remaining cooldown
      local endsAt = workspace:GetServerTimeNow() + (cooldownEndsAt - os.clock())
      PickupLibrary.setPickupEffectActive(localPlayer.UserId, COOLDOWN_EFFECT_ID, COOLDOWN_EFFECT_ID, endsAt)
   else
      PickupLibrary.removePickupEffectActive(localPlayer.UserId, COOLDOWN_EFFECT_ID, nil, true)
   end
   shownCooldownEndsAt = cooldownEndsAt
end

local function isPlayerAiming(player: Player): boolean
   if isServer then
      if WeaponService then
         return WeaponService.isAiming(player)
      end
      return false
   else
      if player == Players.LocalPlayer then
         return WeaponController.getWeaponState() == WeaponController.CurrentWeaponState.Aiming
      end
   end
   return false
end

-------------------------------------------------------------------------------
-- SAFE DASH (T-136). Kept separate: change SAFE_DASH_MIN_FRACTION, or set SAFE_DASH_ENABLED = false to remove it entirely.
--
-- // Plans where a dash ends, before it starts:
-- // 1. One shapecast along the full dash finds how far the body can go (the full distance, or up to an obstruction).
-- // 2. Only that end point is checked. Stable ground there (or the safe-dash behaviour switched off): dash to it, even across
-- //    a gap.
-- // 3. Otherwise the end would leave the player over open air or deadly water. Find the near edge of the danger (a cast back
-- //    from the end just under the floor's surface hits the gap's near face; a cast forward at the water finds its near
-- //    face), and stop a margin short of it, provided that spot is stable and covers at least SAFE_DASH_MIN_FRACTION of the
-- //    full dash distance. If not, the full dash happens and the player goes over the edge.
-------------------------------------------------------------------------------

export type DashPlan = {
   Direction: Vector3, -- // Horizontal unit vector
   Distance: number, -- // Studs the dash travels
   Shortened: boolean, -- // Stopped short to stay on stable ground (the dash ends dead on the spot instead of carrying momentum)
}

-- // Lazily required: Water -> CombatLibrary -> PickupLibrary -> pickup logics (load order)
local WaterLogic = nil
local function getWaterParts(): { Instance }
   if not WaterLogic then
      WaterLogic = require(ReplicatedStorage.Shared.Logics.Environment.Water)
   end
   return WaterLogic.getCurrentWaterParts()
end

-- // Casts that see what the player's body physically collides with
local function getBodyCastParams(character: Model): RaycastParams
   local params = RaycastParams.new()
   params.FilterType = Enum.RaycastFilterType.Exclude
   params.FilterDescendantsInstances = { character }
   params.CollisionGroup = CollisionGroupConstants.Players
   params.RespectCanCollide = true
   return params
end

local function getWaterCastParams(): RaycastParams?
   local waterParts = getWaterParts()
   if #waterParts == 0 then
      return nil
   end
   local params = RaycastParams.new()
   params.FilterType = Enum.RaycastFilterType.Include
   params.FilterDescendantsInstances = waterParts
   return params
end

-- // How far the body can travel along the dash before something it collides with stops it
local function getUnobstructedDistance(rootPosition: Vector3, direction: Vector3, character: Model): number
   local bottom = rootPosition.Y - BODY_BELOW_ROOT + OBSTRUCTION_STEP_HEIGHT
   local top = rootPosition.Y + BODY_ABOVE_ROOT
   local center = Vector3.new(rootPosition.X, (bottom + top) / 2, rootPosition.Z)
   local size = Vector3.new(2, top - bottom, 1) -- // The torso's width and depth (R6), from step height to the top of the head
   local result = workspace:Blockcast(CFrame.lookAt(center, center + direction), size, direction * DASH_DISTANCE, getBodyCastParams(character))
   if not result then
      return DASH_DISTANCE
   end
   return math.max(0, result.Distance - OBSTRUCTION_MARGIN)
end

-- // Whether a character standing with its root at rootPosition would be on stable ground (standable, not over water)
local function isStableGround(rootPosition: Vector3, character: Model): boolean
   local params = getBodyCastParams(character)
   local feetY = rootPosition.Y - BODY_BELOW_ROOT
   local supported = 0
   for index, offset in ipairs(SAFE_DASH_FOOT_OFFSETS) do
      local origin = Vector3.new(rootPosition.X + offset.X, rootPosition.Y, rootPosition.Z + offset.Z)
      local result = workspace:Raycast(origin, Vector3.new(0, -(BODY_BELOW_ROOT + SAFE_DASH_GROUND_SEARCH_DEPTH), 0), params)
      local standable = result ~= nil and result.Normal.Y >= SAFE_DASH_MAX_GROUND_SLOPE_Y
      if index == 1 then
         if not standable then
            return false -- // Nothing to stand on under the centre: open air
         end
         -- // Deadly water between the root and the ground
         local waterParams = getWaterCastParams()
         if waterParams and workspace:Raycast(origin, Vector3.new(0, (result :: RaycastResult).Position.Y - origin.Y - 0.05, 0), waterParams) then
            return false
         end
         -- // Ground far below the feet is a fall, not footing
         if feetY - (result :: RaycastResult).Position.Y > SAFE_DASH_GROUND_SEARCH_DEPTH then
            return false
         end
      end
      if standable then
         supported += 1
      end
   end
   return supported >= SAFE_DASH_MIN_SUPPORTED_FEET
end

-- // How far along the dash the danger starts (the near edge of the gap or the water), or nil if no edge was found
local function getDangerStartDistance(rootPosition: Vector3, direction: Vector3, endDistance: number, character: Model): number?
   local groundUnderStart = workspace:Raycast(rootPosition, Vector3.new(0, -(BODY_BELOW_ROOT + 1), 0), getBodyCastParams(character))
   local surfaceY = if groundUnderStart then groundUnderStart.Position.Y else rootPosition.Y - BODY_BELOW_ROOT
   local nearest: number? = nil

   -- // Gap: from the end back toward the start, just under the floor's surface, the first thing hit is the floor's near edge
   local underSurfaceY = surfaceY - 0.25
   local endPoint = Vector3.new(rootPosition.X, underSurfaceY, rootPosition.Z) + direction * endDistance
   local gapHit = workspace:Raycast(endPoint, -direction * endDistance, getBodyCastParams(character))
   if gapHit then
      nearest = endDistance - gapHit.Distance
   end

   -- // Water: from the start toward the end, just under the floor's surface, the first water hit is its near face
   local waterParams = getWaterCastParams()
   if waterParams then
      local startPoint = Vector3.new(rootPosition.X, underSurfaceY, rootPosition.Z)
      local waterHit = workspace:Raycast(startPoint, direction * endDistance, waterParams)
      if waterHit and (nearest == nil or waterHit.Distance < nearest) then
         nearest = waterHit.Distance
      end
   end
   return nearest
end

-- // Where this dash ends (see the section comment)
local function planDash(rootPosition: Vector3, direction: Vector3, character: Model): DashPlan
   local endDistance = getUnobstructedDistance(rootPosition, direction, character)
   local fullPlan = { Direction = direction, Distance = endDistance, Shortened = false }
   if not SAFE_DASH_ENABLED or isStableGround(rootPosition + direction * endDistance, character) then
      return fullPlan
   end

   local dangerStart = getDangerStartDistance(rootPosition, direction, endDistance, character)
   if not dangerStart then
      return fullPlan
   end
   local safeDistance = dangerStart - SAFE_DASH_EDGE_MARGIN
   if safeDistance < DASH_DISTANCE * SAFE_DASH_MIN_FRACTION then
      return fullPlan -- // Not enough of a dash left before the edge: dash the full distance anyway
   end
   if not isStableGround(rootPosition + direction * safeDistance, character) then
      return fullPlan
   end
   return { Direction = direction, Distance = safeDistance, Shortened = true }
end

-------------------------------------------------------------------------------
-- PREDICTED DASH (T-137)
--
-- // Under server authority the server simulates every character and a player's own client only predicts its own. So the dash
-- // is started and moved inside the simulation step (RunService:BindToSimulation), on the server for every player and on each
-- // client for its own character, from the same replicated input: the moment the player's JumpAction is pressed (Space,
-- // gamepad, or the dash buttons, which press it). Both sides start it on the same simulation frame, plan it from the same
-- // state and move it the same way, and replays after a correction re-run it identically.
-- // Its state is kept in attributes on the HumanoidRootPart (a predicted instance, so they are rolled back and replayed with
-- // it), never in Lua tables. What can't happen inside the simulation (immunity, effects, stats, telling the other clients)
-- // follows those attributes afterwards (see EFFECTS).
-------------------------------------------------------------------------------

local ATTRIBUTE_INPUT_HELD = "DashInputHeld" -- // The jump input's state last step (a dash starts when it goes from up to down)
local ATTRIBUTE_STARTED_AT = "DashStartedAt" -- // time() the latest dash started
local ATTRIBUTE_ENDS_AT = "DashEndsAt" -- // time() the current dash ends; 0 when not dashing
local ATTRIBUTE_READY_AT = "DashReadyAt" -- // time() the cooldown ends
local ATTRIBUTE_DIRECTION = "DashDirection"
local ATTRIBUTE_START = "DashStart" -- // Root position the dash started from
local ATTRIBUTE_DISTANCE = "DashDistance" -- // Planned distance (SAFE DASH)
local ATTRIBUTE_SHORTENED = "DashShortened"

-- // Why each player can't dash right now (aiming, in the lobby, ...), or nil. Worked out outside the simulation each frame
-- // (those checks read game state the simulation can't), read inside it
local blockReasons: {[Player]: string?} = {}

local function getJumpAction(player: Player): InputAction?
   local inputContexts = player:FindFirstChild("InputContexts")
   local characterContext = inputContexts and inputContexts:FindFirstChild("CharacterContext")
   local jumpAction = characterContext and characterContext:FindFirstChild("JumpAction")
   return if jumpAction and jumpAction:IsA("InputAction") then jumpAction else nil
end

-- // Everything that stops a dash except its cooldown
local function getBlockReason(player: Player): string?
   if isPlayerAiming(player) then
      return "is aiming"
   end
   -- // T-092/T-093: holding a manual recall of a dead boomerang (charging it, or while it flies back) hinders the player like aiming does
   local deadWeaponData = DeadWeapons.Data[player]
   local thrownWeaponData = ThrownWeapons.Data[player]
   if (deadWeaponData and deadWeaponData.RecallChargeStart ~= nil) or (thrownWeaponData and thrownWeaponData.RecallFromDead == true) then
      return "holding a recall"
   end

   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   local currentGameMode = if currentRoundData then currentRoundData.Gamemode else nil
   if currentGameMode then
      local gameModeData = Gamemodes[currentGameMode]
      if gameModeData and gameModeData.DashDisabled then
         return "dash disabled in this gamemode"
      end
   end

   local character = player.Character
   local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
   if not character or not humanoidRootPart then
      return "no character"
   end
   -- // Jump replaces dash in the lobby (see LobbyController / AbilityController.useMovementInput)
   if LobbyLibrary.isCharacterInLobby(character) then
      return "in the lobby"
   end

   local raycastParams = RaycastParams.new()
   raycastParams.FilterDescendantsInstances = {character}
   raycastParams.CollisionGroup = CollisionGroupConstants.ArenaFloorDetector
   raycastParams.FilterType = Enum.RaycastFilterType.Exclude
   if not workspace:Raycast(humanoidRootPart.Position, Vector3.new(0, -5, 0), raycastParams) then
      return "not grounded"
   end
   return nil
end

-- // The direction the player is steering (the same maths as the ControlModule's move input), else the way they face
local function getDashDirection(player: Player, humanoidRootPart: BasePart): Vector3?
   local inputContexts = player:FindFirstChild("InputContexts")
   local characterContext = inputContexts and inputContexts:FindFirstChild("CharacterContext")
   local moveAction = characterContext and characterContext:FindFirstChild("MoveAction")
   local move: Vector2 = if moveAction then moveAction:GetState() else Vector2.zero

   local cameraLook: Vector3? = nil
   local success, cameraState = pcall(function()
      return (player :: any):GetCameraState()
   end)
   if success and cameraState and cameraState.CFrame ~= CFrame.identity then
      cameraLook = cameraState.CFrame.LookVector
   else
      local cameraContext = inputContexts and inputContexts:FindFirstChild("CameraContext")
      local cameraAction = cameraContext and cameraContext:FindFirstChild("CameraAction")
      if cameraAction then
         cameraLook = cameraAction:GetState()
      end
   end

   local direction = Vector3.zero
   if cameraLook and move.Magnitude > 1e-3 then
      local flatLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
      if flatLook.Magnitude > 1e-4 then
         flatLook = flatLook.Unit
         local right = flatLook:Cross(Vector3.yAxis).Unit
         direction = flatLook * move.Y + right * move.X
      end
   end
   if direction.Magnitude <= 1e-4 then
      direction = humanoidRootPart.CFrame.LookVector
   end
   direction = Vector3.new(direction.X, 0, direction.Z)
   if direction.Magnitude <= 1e-5 then
      return nil
   end
   return direction.Unit
end

-- // One simulation step of one player's dash: start it on the press, move it, end it
local function stepPlayerDash(player: Player, now: number, deltaTime: number)
   local character = player.Character
   local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
   local humanoid = character and character:FindFirstChildOfClass("Humanoid")
   if not character or not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
      return
   end

   local jumpAction = getJumpAction(player)
   local held = jumpAction ~= nil and jumpAction:GetState() == true
   local wasHeld = humanoidRootPart:GetAttribute(ATTRIBUTE_INPUT_HELD) == true
   if held ~= wasHeld then
      humanoidRootPart:SetAttribute(ATTRIBUTE_INPUT_HELD, held)
   end

   local endsAt = humanoidRootPart:GetAttribute(ATTRIBUTE_ENDS_AT) or 0
   local readyAt = humanoidRootPart:GetAttribute(ATTRIBUTE_READY_AT) or 0
   if held and not wasHeld and endsAt == 0 and now >= readyAt and not blockReasons[player] then
      local direction = getDashDirection(player, humanoidRootPart)
      if direction then
         -- // Where it ends: the full dash, up to a wall, or stopped at the edge of a gap/water (SAFE DASH)
         local plan = planDash(humanoidRootPart.Position, direction, character)
         endsAt = now + DASH_DURATION_SECONDS
         humanoidRootPart:SetAttribute(ATTRIBUTE_STARTED_AT, now)
         humanoidRootPart:SetAttribute(ATTRIBUTE_ENDS_AT, endsAt)
         humanoidRootPart:SetAttribute(ATTRIBUTE_READY_AT, now + DASH_COOLDOWN_SECONDS)
         humanoidRootPart:SetAttribute(ATTRIBUTE_DIRECTION, plan.Direction)
         humanoidRootPart:SetAttribute(ATTRIBUTE_START, humanoidRootPart.Position)
         humanoidRootPart:SetAttribute(ATTRIBUTE_DISTANCE, plan.Distance)
         humanoidRootPart:SetAttribute(ATTRIBUTE_SHORTENED, plan.Shortened)
      end
   end
   if endsAt == 0 then
      return
   end

   local direction: Vector3 = humanoidRootPart:GetAttribute(ATTRIBUTE_DIRECTION) or Vector3.zAxis
   local start: Vector3 = humanoidRootPart:GetAttribute(ATTRIBUTE_START) or humanoidRootPart.Position
   local distance: number = humanoidRootPart:GetAttribute(ATTRIBUTE_DISTANCE) or DASH_DISTANCE
   local shortened = humanoidRootPart:GetAttribute(ATTRIBUTE_SHORTENED) == true

   local velocity = humanoidRootPart.AssemblyLinearVelocity
   local travelled = (humanoidRootPart.Position - start) * Vector3.new(1, 0, 1)
   local remaining = distance - travelled:Dot(direction)
   if now >= endsAt or remaining <= 0.05 then
      if shortened then
         -- // Stopped at the edge: no momentum left to carry the player over it
         humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
      elseif DASH_END_CLAMPS_SPEED then
         local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
         if horizontal.Magnitude > humanoid.WalkSpeed then
            horizontal = horizontal.Unit * humanoid.WalkSpeed
         end
         humanoidRootPart.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
      end
      humanoidRootPart:SetAttribute(ATTRIBUTE_ENDS_AT, 0)
      return
   end

   -- // The last step slows so the dash lands exactly on its planned spot
   local speed = math.min(DASH_SPEED, remaining / math.max(deltaTime, 1 / 240))
   humanoidRootPart.AssemblyLinearVelocity = Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed)
end

local function stepDashes(deltaTime: number)
   local now = time()
   if isServer then
      for _, player in ipairs(Players:GetPlayers()) do
         stepPlayerDash(player, now, deltaTime)
      end
   else
      stepPlayerDash(Players.LocalPlayer, now, deltaTime)
   end
end

-------------------------------------------------------------------------------
-- EFFECTS (outside the simulation, following the PREDICTED DASH attributes)
-------------------------------------------------------------------------------

local seenDashStarts: {[Player]: number} = {} -- // The DashStartedAt each player's effects were last started for
local dashEffectsActive: {[Player]: boolean} = {}

-- // Client: the dash animation and trail for any player
local function playDashEffects(player: Player)
   local character = player.Character
   local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
   local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
   if not humanoidRootPart or not humanoid then
      return
   end
   if AnimationController then
      AnimationController.playCoreAnimation(player, "Dash")
   end
   local particle = ParticlesLibrary.play(math.random(1000), "Dash", humanoidRootPart:GetPivot().Position, 3, DASH_DURATION_SECONDS*.5)
   task.spawn(function()
      while particle and particle.Parent do
         local dir = humanoid.MoveDirection
         dir = Vector3.new(dir.X, 0, dir.Z)
         if dir.Magnitude > 0 then
               particle:PivotTo(
                  CFrame.lookAt(
                     humanoidRootPart.Position,
                     humanoidRootPart.Position + dir
                  ) * CFrame.Angles(0, math.rad(-90), 0)
               )
         end
         task.wait()
      end
   end)
   task.delay(DASH_DURATION_SECONDS, function()
      if AnimationController then
         AnimationController.stopCoreAnimation(player, "Dash")
      end
   end)
end

-- // A dash this player's simulation started: immunity, stats and the other clients (server); effects and cooldown (own client)
local function onDashStarted(player: Player)
   dashEffectsActive[player] = true
   if isServer then
      HitboxLibrary.immunize(player, "Dash", 0)
      local timestamp = workspace:GetServerTimeNow()
      for _, otherPlayer in ipairs(Players:GetPlayers()) do
         if otherPlayer ~= player then
            PlayDash:FireClient(otherPlayer, player.UserId, timestamp)
         end
      end
   else
      cooldowns[player] = os.clock() + DASH_COOLDOWN_SECONDS
      playDashEffects(player)
   end
   SharedTasks.PlayerUsedAbility:Execute("parallel", player, ABILITY_ID)
end

local function followDashes()
   local tracked = if isServer then Players:GetPlayers() else { Players.LocalPlayer }
   for _, player in ipairs(tracked) do
      blockReasons[player] = getBlockReason(player)

      local character = player.Character
      local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
      if not humanoidRootPart then
         continue
      end
      local startedAt = humanoidRootPart:GetAttribute(ATTRIBUTE_STARTED_AT)
      if type(startedAt) == "number" and startedAt ~= seenDashStarts[player] then
         seenDashStarts[player] = startedAt
         onDashStarted(player)
      end
      if dashEffectsActive[player] and (humanoidRootPart:GetAttribute(ATTRIBUTE_ENDS_AT) or 0) == 0 then
         dashEffectsActive[player] = nil
         endDashEffects(player)
      end
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Client: another player dashed (PlayDash / AbilityReplication): show it. The movement itself comes from the server.
function Dash.onPickup(userId: number, timestamp: number)
   if isServer or typeof(timestamp) ~= "number" then
      return
   end

   local player = Players:GetPlayerByUserId(userId)
   if not player or player == Players.LocalPlayer then
      return
   end

   Dash.activate(player, timestamp)
end

function Dash.canActivate(player: Player)
   local reason = getBlockReason(player)
   if reason then
      print(`cannot dash: {reason}`)
      return false
   end
   local character = player.Character
   local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
   if humanoidRootPart and time() < (humanoidRootPart:GetAttribute(ATTRIBUTE_READY_AT) or 0) then
      print("cannot dash: on cooldown")
      return false
   end
   return true
end

-- // Effects only (the dash itself is started by the jump input inside the simulation, see PREDICTED DASH)
function Dash.activate(player: Player, _timestamp: number?)
   if isServer then
      return
   end
   playDashEffects(player)
end

-- // Client: the dash buttons (touch) press the same replicated input Space does, so the dash is predicted the same way
function Dash.pressInput()
   if isServer then
      return
   end
   local jumpAction = getJumpAction(Players.LocalPlayer)
   if not jumpAction then
      return
   end
   pcall(function()
      jumpAction:Fire(true)
   end)
   task.delay(0.1, function()
      pcall(function()
         jumpAction:Fire(false)
      end)
   end)
end

-------------------------------------------------------------------------------
-- RUNTIME
-------------------------------------------------------------------------------

RunService:BindToSimulation(stepDashes, Enum.StepFrequency.Hz60)
RunService.Heartbeat:Connect(followDashes)

PlayersUtil.PlayerRemoving:Add(function(player: Player)
   cooldowns[player] = nil
   blockReasons[player] = nil
   seenDashStarts[player] = nil
   dashEffectsActive[player] = nil
end)

PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
   endDashEffects(player)
   dashEffectsActive[player] = nil
   cooldowns[player] = nil
end)

PlayersUtil.CharacterDied:Add(function(player: Player, character: Model, humanoid: Humanoid)
   endDashEffects(player)
   dashEffectsActive[player] = nil
   cooldowns[player] = nil
end)

if not isServer then
   RunService.Heartbeat:Connect(updateCooldownEffect)

   PlayDash.OnClientEvent:Connect(function(userId: number, timestamp: number)
      local player = Players:GetPlayerByUserId(userId)
      if not player then
         warn(`Dash.activate: No player found for userId {userId}`)
         return
      end
      local now = game.Workspace:GetServerTimeNow()
      if now - timestamp > 3 then
         print("cancelling a dash activation receipt with an outdated timestamp")
         return
      end
      Dash.activate(player, timestamp)
   end)
end

return Dash
