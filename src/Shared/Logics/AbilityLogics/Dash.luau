local Dash = {}

local RunService = game:GetService("RunService")

-------------------------------------------------------------------------------
-- LOCAL VARIABLES
-------------------------------------------------------------------------------

local DASH_SPEED = 120
local DASH_DURATION_SECONDS = 0.22
local DASH_COOLDOWN_SECONDS = 1

local activeDashConnections: {[Model]: RBXScriptConnection} = {}

local isServer = RunService:IsServer()

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

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function Dash.canActivate(player: Player)
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
      print("dash denied: not grounded")
      return false
   end

   local cooldown = Cooldowns[player]
   if cooldown and os.clock() < cooldown then
      print("dash cooldown")
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
      -- TODO: sound, vfx, etc
   end
end

return Dash