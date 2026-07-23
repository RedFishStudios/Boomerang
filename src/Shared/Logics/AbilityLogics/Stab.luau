local Stab = {}

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local AnimationLibrary = require(ReplicatedStorage.Shared.Library.AnimationLibrary)

local CombatService

local Cooldowns: {[Player]: number} = {}
local ActiveStabs: {[Player]: boolean} = {}

-------------------------------------------------------------------------------
-- LOCAL VARIABLES
-------------------------------------------------------------------------------

local STAB_COOLDOWN = 1

local HITBOX_KILL_SIZE = Vector3.new(2, 2, 2)
local HITBOX_PARRY_FORWARD_EXTENSION = 1
local HITBOX_PARRY_SIZE = Vector3.new(HITBOX_KILL_SIZE.X, HITBOX_KILL_SIZE.Y, HITBOX_KILL_SIZE.Z + HITBOX_PARRY_FORWARD_EXTENSION)
local HITBOX_DURATION = .6
local HITBOX_DELAY = .08
local HITBOX_INTERVAL = .1
local HITBOX_DISTANCE = 1
local STAB_KILL_DAMAGE = 100000

local HITBOX_COLLISION_GROUP = CollisionGroupConstants.Players
local KILL_VISUALIZER_COLOR = Color3.new(0.164706, 0.960784, 0.007843)
local PARRY_VISUALIZER_COLOR = Color3.new(1, 0.647059, 0)

local isServer = RunService:IsServer()
if isServer then
   CombatService = require(game.ServerStorage.Server.Core.CombatService)
end

local ActiveStabRunIds: {[Player]: number} = {}

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

   local previousRunId = ActiveStabRunIds[player] or 0
   local runId = previousRunId + 1
   ActiveStabRunIds[player] = runId
   ActiveStabs[player] = true

   AnimationLibrary.playCoreAnimation(player, "Stab")
   -- TODO: Stab sound

   local overlapParams = OverlapParams.new()
   overlapParams.FilterType = Enum.RaycastFilterType.Exclude
   overlapParams.FilterDescendantsInstances = {character}
   overlapParams.CollisionGroup = HITBOX_COLLISION_GROUP

   local registeredKillHits: {[Player]: boolean} = {}
   local killVisualizer: BasePart? = nil
   local parryVisualizer: BasePart? = nil

   task.spawn(function()
      task.wait(HITBOX_DELAY)

      local startedAt = os.clock()
      while ActiveStabRunIds[player] == runId and (os.clock() - startedAt) <= HITBOX_DURATION do
         local latestCharacter = player.Character
         local latestRootPart = latestCharacter and latestCharacter.PrimaryPart
         if not latestCharacter or not latestRootPart then
            break
         end

         overlapParams.FilterDescendantsInstances = {latestCharacter}

         local killCFrame = getHitboxCFrame(latestRootPart)
         local parryCFrame = getHitboxCFrame(latestRootPart, HITBOX_PARRY_FORWARD_EXTENSION)

         if isServer and GlobalConfig.ParryVisualizersEnabled then
            if not killVisualizer or not killVisualizer.Parent then
               killVisualizer = createHitboxVisualizer(killCFrame, HITBOX_KILL_SIZE, KILL_VISUALIZER_COLOR)
            else
               updateHitboxVisualizer(killVisualizer, killCFrame)
            end

            if not parryVisualizer or not parryVisualizer.Parent then
               parryVisualizer = createHitboxVisualizer(parryCFrame, HITBOX_PARRY_SIZE, PARRY_VISUALIZER_COLOR)
            else
               updateHitboxVisualizer(parryVisualizer, parryCFrame)
            end
         else
            destroyHitboxVisualizer(killVisualizer)
            destroyHitboxVisualizer(parryVisualizer)
            killVisualizer = nil
            parryVisualizer = nil
         end

         local killTargets = getHitPlayers(player, latestCharacter, killCFrame, HITBOX_KILL_SIZE, overlapParams)
         for _, victimPlayer in ipairs(killTargets) do
            print("[Stab] Hit player to kill:", player.Name, "->", victimPlayer.Name)

            if not registeredKillHits[victimPlayer] then
               registeredKillHits[victimPlayer] = true

               if not ActiveStabs[victimPlayer] then
                  if isServer then
                     local victimCharacter = victimPlayer.Character
                     local victimHumanoid = victimCharacter and victimCharacter:FindFirstChildOfClass("Humanoid")
                     if victimHumanoid and victimHumanoid.Health > 0 then
                        CombatService.damagePlayer(player, "Stab", victimPlayer, victimHumanoid, STAB_KILL_DAMAGE)
                     end
                  else
                     -- CLIENTSIDE STAB DETECTED
                  end
               end
            end
         end

         local parryTargets = getHitPlayers(player, latestCharacter, parryCFrame, HITBOX_PARRY_SIZE, overlapParams)
         for _, victimPlayer in ipairs(parryTargets) do
            if ActiveStabs[victimPlayer] then
               print("[Stab] Hit player to parry:", player.Name, "<->", victimPlayer.Name)
            end
         end

         task.wait(HITBOX_INTERVAL)
      end

      destroyHitboxVisualizer(killVisualizer)
      destroyHitboxVisualizer(parryVisualizer)

      if ActiveStabRunIds[player] == runId then
         ActiveStabRunIds[player] = nil
      end
      ActiveStabs[player] = nil
   end)
end

-------------------------------------------------------------------------------
-- RUNTIME
-------------------------------------------------------------------------------

PlayersUtil.PlayerRemoving:Add(function(player: Player)
   Cooldowns[player] = nil
   ActiveStabs[player] = nil
   ActiveStabRunIds[player] = nil
end)

PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
   Cooldowns[player] = nil
   ActiveStabs[player] = nil
   ActiveStabRunIds[player] = nil
end)

PlayersUtil.CharacterDied:Add(function(player: Player, character: Model, humanoid: Humanoid)
   Cooldowns[player] = nil
   ActiveStabs[player] = nil
   ActiveStabRunIds[player] = nil
end)

return Stab