local Dash = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local Gamemodes = require(ReplicatedStorage.Shared.Constants.Gamemodes)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)

local isServer = RunService:IsServer()
local WeaponController
local WeaponService

if isServer then
   WeaponService = require(game.ServerStorage.Server.Core.WeaponService)
else
   WeaponController = require(ReplicatedStorage.Client.Core.WeaponController)
end

-------------------------------------------------------------------------------
-- LOCAL VARIABLES
-------------------------------------------------------------------------------

local DASH_SPEED = 80
local DASH_DURATION_SECONDS = 0.12
local DASH_COOLDOWN_SECONDS = 1

local activeDashConnections: {[Model]: RBXScriptConnection} = {}

-- The timestamp every player's dash wears off at
local Cooldowns: {[Player]: number} = {}

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

local function stopDash(character: Model)
   local connection = activeDashConnections[character]
   if connection then
      connection:Disconnect()
      activeDashConnections[character] = nil
   end
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
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Dash.canActivate(player: Player)
   if isPlayerAiming(player) then
      return false
   end

   local gameStateData = GameStateLibrary.getGameStateData()
   local currentGameMode = gameStateData.Gamemode:Get()
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

   local rayOrigin = humanoidRootPart.Position
   local rayDirection = Vector3.new(0, -5, 0)
   local raycastParams = RaycastParams.new()
   raycastParams.FilterDescendantsInstances = {character}
   raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
   local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
   if not raycastResult then
      return false
   end

   local cooldown = Cooldowns[player]
   if cooldown and os.clock() < cooldown then
      return false
   end
   return true
end

function Dash.activate(player: Player)
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

   Cooldowns[player] = os.clock() + DASH_COOLDOWN_SECONDS

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

      stopDash(character)

      local dashEndsAt = os.clock() + DASH_DURATION_SECONDS
      activeDashConnections[character] = RunService.Heartbeat:Connect(function()
         if not character.Parent or not humanoidRootPart.Parent then
            stopDash(character)
            return
         end

         if os.clock() >= dashEndsAt then
            stopDash(character)
            return
         end

         local currentVelocity = humanoidRootPart.AssemblyLinearVelocity
         humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
            horizontalForward.X * DASH_SPEED,
            currentVelocity.Y,
            horizontalForward.Z * DASH_SPEED
         )
      end)
   else
      -- Client context
      local particle = ParticlesLibrary.play("Dash", humanoidRootPart:GetPivot().Position, 3, DASH_DURATION_SECONDS*.5)
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
   end
end

-------------------------------------------------------------------------------
-- RUNTIME
-------------------------------------------------------------------------------

PlayersUtil.PlayerRemoving:Add(function(player: Player)
   Cooldowns[player] = nil
end)

PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
   stopDash(character)
   Cooldowns[player] = nil
end)

PlayersUtil.CharacterDied:Add(function(player: Player, character: Model, humanoid: Humanoid)
   stopDash(character)
   Cooldowns[player] = nil
end)

return Dash