local Dash = {}

-- TODO: Clientside implement timestamp to account for lag
-- TODO: the animation clashes badly with authoritative run animation, causing the character to wiggle around
--       address as either an animation issue or a propulsion issue

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

local activeDashConnections: {[Model]: RBXScriptConnection} = {}

-- The timestamp every player's dash wears off at
local cooldowns: {[Player]: number} = {}

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

local function stopDash(player: Player, character: Model)
   local connection = activeDashConnections[character]
   if connection then
      connection:Disconnect()
      activeDashConnections[character] = nil
   end
   HitboxLibrary.unImmunize(player, "Dash", 0)
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
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Dash.onPickup(userId: number, timestamp: number)
   if isServer or typeof(timestamp) ~= "number" then
      return
   end

   local player = Players:GetPlayerByUserId(userId)
   if not player then
      return
   end

   Dash.activate(player, timestamp)
end

function Dash.canActivate(player: Player)
   if isPlayerAiming(player) then
      print("cannot dash: is aiming")
      return false
   end

   -- // T-092/T-093: holding a manual recall of a dead boomerang (charging it, or while it flies back) hinders the player like aiming does
   local deadWeaponData = DeadWeapons.Data[player]
   local thrownWeaponData = ThrownWeapons.Data[player]
   if (deadWeaponData and deadWeaponData.RecallChargeStart ~= nil) or (thrownWeaponData and thrownWeaponData.RecallFromDead == true) then
      print("cannot dash: holding a recall")
      return false
   end

   local gameStateData = GameStateLibrary.getGameStateData()
   local currentRoundData = gameStateData.CurrentRoundData:Get()
   local currentGameMode = if currentRoundData then currentRoundData.Gamemode else nil
   if currentGameMode then
      local gameModeData = Gamemodes[currentGameMode]
      if gameModeData and gameModeData.DashDisabled then
         print("dash disabled in this gamemode")
         return false
      end
   end

   local character = player.Character
   if not character then
      warn(`Dash.activate: No character found for player {player.Name}`)
      return  
   end

   local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
   if not humanoidRootPart then
      warn(`Dash.activate: No HumanoidRootPart found for player {player.Name}`)
      return
   end

   -- // Jump replaces dash in the lobby (see LobbyController / AbilityController.useMovementInput)
   if LobbyLibrary.isCharacterInLobby(character) then
      return false
   end

   local rayOrigin = humanoidRootPart.Position
   local rayDirection = Vector3.new(0, -5, 0)
   local raycastParams = RaycastParams.new()
   raycastParams.FilterDescendantsInstances = {character}
   raycastParams.CollisionGroup = CollisionGroupConstants.ArenaFloorDetector
   raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
   local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
   if not raycastResult then
      print("cannot dash: not grounded")
      return false
   end

   local cooldown = cooldowns[player]
   if cooldown and os.clock() < cooldown then
      print("cannot dash: on cooldown")
      return false
   end
   return true
end

function Dash.activate(player: Player, _timestamp: number?)
   local character = player.Character
   if not character then
      warn(`Dash.activate: No character found for player {player.Name}`)
      return  
   end

   local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
   if not humanoidRootPart then
      warn(`Dash.activate: No HumanoidRootPart found for player {player.Name}`)
      return
   end
   
   local humanoid = character:FindFirstChildWhichIsA("Humanoid")
   if not humanoid then
      warn(`Dash.activate: No Humanoid found for player {player.Name}`)
      return
   end

   local timestamp = _timestamp or game.Workspace:GetServerTimeNow()
   if isServer then
      for _, p in pairs(game.Players:GetPlayers()) do
         if p == player then
            continue
         end
         PlayDash:FireClient(p, player.UserId, timestamp)
      end
   end

   stopDash(player, character)

   cooldowns[player] = os.clock() + DASH_COOLDOWN_SECONDS
   if AnimationController then
      AnimationController.playCoreAnimation(player, "Dash")
   end

   local dashEndsAt = os.clock() + DASH_DURATION_SECONDS

   if isServer then
      -- Server context

      local forward = humanoid.MoveDirection
      if forward.X == 0 and forward.Y == 0 and forward.Z == 0 then
         forward = humanoidRootPart.CFrame.LookVector
      end
      local horizontalForward = Vector3.new(forward.X, 0, forward.Z)
      if horizontalForward.Magnitude <= 1e-5 then
         return
      end
      horizontalForward = horizontalForward.Unit

      -- // Where it ends: the full dash, up to a wall, or stopped at the edge of a gap/water (SAFE DASH)
      local plan = planDash(humanoidRootPart.Position, horizontalForward, character)
      local startPosition = humanoidRootPart.Position

      HitboxLibrary.immunize(player, "Dash", 0)

      activeDashConnections[character] = RunService.Heartbeat:Connect(function(deltaTime)
         if not character.Parent or not humanoidRootPart.Parent then
            stopDash(player, character)
            return
         end

         local currentVelocity = humanoidRootPart.AssemblyLinearVelocity
         local travelled = (humanoidRootPart.Position - startPosition) * Vector3.new(1, 0, 1)
         local remaining = plan.Distance - travelled:Dot(plan.Direction)
         if os.clock() >= dashEndsAt or (plan.Shortened and remaining <= 0.05) then
            if plan.Shortened then
               -- // Stopped at the edge: no momentum left to carry the player over it
               humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, currentVelocity.Y, 0)
            elseif DASH_END_CLAMPS_SPEED then
               local horizontal = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
               if horizontal.Magnitude > humanoid.WalkSpeed then
                  horizontal = horizontal.Unit * humanoid.WalkSpeed
               end
               humanoidRootPart.AssemblyLinearVelocity = Vector3.new(horizontal.X, currentVelocity.Y, horizontal.Z)
            end
            stopDash(player, character)
            return
         end

         -- // A shortened dash slows on its last frame so it lands on the planned spot
         local speed = if plan.Shortened then math.min(DASH_SPEED, remaining / math.max(deltaTime, 1 / 240)) else DASH_SPEED
         humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
            plan.Direction.X * speed,
            currentVelocity.Y,
            plan.Direction.Z * speed
         )
      end)
   else
      -- Client context
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

      activeDashConnections[character] = RunService.Heartbeat:Connect(function()
         if not character.Parent or not humanoidRootPart.Parent then
            stopDash(player, character)
            return
         end

         if os.clock() >= dashEndsAt then
            stopDash(player, character)
            return
         end
      end)
   end
end

-------------------------------------------------------------------------------
-- RUNTIME
-------------------------------------------------------------------------------

PlayersUtil.PlayerRemoving:Add(function(player: Player)
   cooldowns[player] = nil
end)

PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
   stopDash(player, character)
   cooldowns[player] = nil
end)

PlayersUtil.CharacterDied:Add(function(player: Player, character: Model, humanoid: Humanoid)
   stopDash(player, character)
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