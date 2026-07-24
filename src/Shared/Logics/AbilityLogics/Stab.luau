local Stab = {}

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local AnimationLibrary = require(ReplicatedStorage.Shared.Library.AnimationLibrary)

local CameraController

local CombatService

-------------------------------------------------------------------------------
-- LOCAL VARIABLES
-------------------------------------------------------------------------------

local STAB_COOLDOWN = 1

local HITBOX_SIZE = Vector3.new(2, 2, 3)
local HITBOX_DURATION = .2
local HITBOX_DELAY = .08
local HITBOX_DISTANCE = 1
local STAB_KILL_DAMAGE = 100000
local STAB_DISTANCE = 2 + HITBOX_DISTANCE
local PARRY_DISTANCE = 3 + HITBOX_DISTANCE

local HITBOX_COLLISION_GROUP = CollisionGroupConstants.Players
local HITBOX_VISUALIZER_COLOR = Color3.new(0.164706, 0.960784, 0.007843)

local HITBOX_CHECK_INTERVAL = 1/20

local isServer = RunService:IsServer()
if isServer then
   CombatService = require(game.ServerStorage.Server.Core.CombatService)
else
   CameraController = require(ReplicatedStorage.Client.Core.CustomCameraController)
end

local Cooldowns: {[Player]: number} = {}
local ActiveStabs: {
   [Player]: {
      RunId: number,
      Connection: RBXScriptConnection?,
      Visualizer: BasePart?
   }
} = {}

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

local function getHorizontalLookDirection(rootPart: BasePart): Vector3
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

local function getHitboxCFrame(rootPart: BasePart, forwardExtension: number?): CFrame
   local lookDirection = getHorizontalLookDirection(rootPart)
   local extension = forwardExtension or 0
   local forwardOffset = HITBOX_DISTANCE + (extension * .5)
   local center = rootPart.Position + lookDirection * forwardOffset
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

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Stab.canActivate(player: Player): boolean
   local gameStateData = GameStateLibrary.getGameStateData()
   local inRound = gameStateData.IsInRound:Get()
   if not inRound then
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

   local previousRunId = ActiveStabs[player] and ActiveStabs[player].RunId or 0
   local runId = previousRunId + 1
   local shouldShowVisualizer = isServer and GlobalConfig.ParryVisualizersEnabled

   AnimationLibrary.playCoreAnimation(player, "Stab")
   -- TODO: Stab sound

   local overlapParams = OverlapParams.new()
   overlapParams.FilterType = Enum.RaycastFilterType.Exclude
   overlapParams.FilterDescendantsInstances = {character}
   overlapParams.CollisionGroup = HITBOX_COLLISION_GROUP

   local registeredKillHits: {[Player]: boolean} = {}

   local startedAt = os.clock()
   local stabState = {
      RunId = runId,
      Connection = nil :: RBXScriptConnection?,
      Visualizer = nil :: BasePart?
   }
   ActiveStabs[player] = stabState
   
   local accumulator = 0

   local function everyFrame(dt)
      if not ActiveStabs[player] or ActiveStabs[player].RunId ~= runId then
         return
      end

      local elapsed = os.clock() - startedAt
      if elapsed < HITBOX_DELAY then
         return
      end

      accumulator = accumulator + dt
      if accumulator < HITBOX_CHECK_INTERVAL then
         return
      end
      accumulator = 0

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

      local hitboxCFrame = getHitboxCFrame(latestRootPart)

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

      local hitTargets = getHitPlayers(player, latestCharacter, hitboxCFrame, HITBOX_SIZE, overlapParams)
      for _, victimPlayer in ipairs(hitTargets) do
         local victimCharacter = victimPlayer.Character
         local victimRootPart = victimCharacter and victimCharacter.PrimaryPart
         if not victimRootPart then
            continue
         end

         local targetDistance = getHorizontalDistance(latestRootPart, victimRootPart)
         local victimIsStabbing = ActiveStabs[victimPlayer] ~= nil

         if victimIsStabbing then
            if targetDistance <= PARRY_DISTANCE then
               print("[Stab] Hit player to parry:", player.Name, "<->", victimPlayer.Name)
               if CameraController then
                  CameraController.parryEffect()
               end
            end
         else
            if targetDistance <= STAB_DISTANCE and not registeredKillHits[victimPlayer] then
               registeredKillHits[victimPlayer] = true

               if isServer then
                  local victimHumanoid = victimCharacter:FindFirstChildOfClass("Humanoid")
                  if victimHumanoid and victimHumanoid.Health > 0 then
                     CombatService.damagePlayer(player, "Stab", victimPlayer, victimHumanoid, STAB_KILL_DAMAGE)
                  end
               else
                  -- CLIENTSIDE STAB DETECTED
               end
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
   disconnect(player)
end)

PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
   disconnect(player)
end)

PlayersUtil.CharacterDied:Add(function(player: Player, character: Model, humanoid: Humanoid)
   disconnect(player)
end)

return Stab