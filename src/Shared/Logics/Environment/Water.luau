local Water = {}

local SessionConnections: {[Instance]: RBXScriptConnection} = {}

local TasksList = require(game:GetService("ReplicatedStorage").Shared.Classes.TasksList)
local CollisionGroupConstants = require(game:GetService("ReplicatedStorage").Shared.Constants.CollisionGroupConstants)
local ParticlesLibrary = require(game:GetService("ReplicatedStorage").Shared.Library.ParticlesLibrary)

local isServer = game:GetService("RunService"):IsServer()

local DROWN_CAUSE_LABEL = "Drowned"
local SPLASH_PARTICLE = "Splash"
local SPLASH_EMIT_COUNT = 30
-- // Set on the authoritative character when it drowns, so it only drowns once per life
local DROWNED_ATTRIBUTE = "Drowned"
-- // How far below the water's bottom the root still counts as in the water (a fast fall can skip past a thin part in one frame)
local MAX_ROOT_DEPTH_BELOW_BOTTOM = 10

-- // Lazily required: CombatLibrary -> PickupLibrary -> pickup logics require this module (load-time circular require)
local CombatLibrary = nil
local function getCombatLibrary()
   if not CombatLibrary then
      CombatLibrary = require(game:GetService("ReplicatedStorage").Shared.Library.CombatLibrary)
   end
   return CombatLibrary
end

local drownCheckConnection: RBXScriptConnection? = nil

Water.PlayerEnteredWater = TasksList.new() :: TasksList.TasksList<(player: Player, waterPart: Instance) -> ()>

-- // Point on the water's top surface above/below the given position
local function getSurfacePoint(waterPart: BasePart, position: Vector3): Vector3
   local localPoint = waterPart.CFrame:PointToObjectSpace(position)
   return waterPart.CFrame:PointToWorldSpace(Vector3.new(localPoint.X, waterPart.Size.Y / 2, localPoint.Z))
end

-- // True when the position is inside the water (below its top surface, within its footprint)
local function isPositionInWater(waterPart: BasePart, position: Vector3): boolean
   local localPoint = waterPart.CFrame:PointToObjectSpace(position)
   local halfSize = waterPart.Size / 2
   return math.abs(localPoint.X) <= halfSize.X
      and math.abs(localPoint.Z) <= halfSize.Z
      and localPoint.Y <= halfSize.Y
      and localPoint.Y >= -halfSize.Y - MAX_ROOT_DEPTH_BELOW_BOTTOM
end

-- // Server only: kill the player through the normal death path and splash (water is non-collidable, so the body keeps sinking)
local function drownPlayer(player: Player, character: Model, waterPart: BasePart)
   if character:GetAttribute(DROWNED_ATTRIBUTE) then
      return
   end
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not humanoid or humanoid.Health <= 0 then
      return
   end

   -- // Water kills through shields: TakeDamage is a no-op while the character has a ForceField,
   -- // so set Health directly and send the death reason ourselves (same as applyDamageToHumanoid)
   character:SetAttribute(DROWNED_ATTRIBUTE, true)
   humanoid.Health = 0
   getCombatLibrary().notifyDeathReason(player, nil, DROWN_CAUSE_LABEL)

   local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
   local splashPosition = getSurfacePoint(waterPart, if root and root:IsA("BasePart") then root.Position else character:GetPivot().Position)
   ParticlesLibrary.emit(`Splash_{player.UserId}_{workspace:GetServerTimeNow()}`, SPLASH_PARTICLE, splashPosition, SPLASH_EMIT_COUNT)
end

function Water.getCurrentWaterParts(): {Instance}
   local waterParts: {Instance} = {}
   for functionalChild, _ in pairs(SessionConnections) do
      if functionalChild and functionalChild.Parent then
         table.insert(waterParts, functionalChild)
      end
   end
   return waterParts
end

function Water.getTouchingWaters(Player: Player): {Instance}
   local waterParts = Water.getCurrentWaterParts()
   local touchingWaters: {Instance} = {}

   for _, waterPart in pairs(waterParts) do
      if waterPart and waterPart:IsA("BasePart") then
         local touchingParts = waterPart:GetTouchingParts()
         for _, touchingPart in pairs(touchingParts) do
            if touchingPart and touchingPart.Parent then
               local character = touchingPart:FindFirstAncestorWhichIsA("Model")
               if character and character == Player.Character then
                  table.insert(touchingWaters, waterPart)
                  break
               end
            end
         end
      end
   end

   return touchingWaters
end

function Water.validate(functionalChild: Instance): boolean
   if not functionalChild:IsA("Part") and not functionalChild:IsA("BasePart") and not functionalChild:IsA("MeshPart") then
      warn(`Water.validate: functionalChild {functionalChild:GetFullName()} is not a Part, BasePart, or MeshPart`)
      return false
   end
   return true
end

function Water.onObjectAdded(functionalChild: Instance)
   if functionalChild:GetAttribute("Invalid") then
      warn(`invalid`)
      return
   end
   functionalChild.CollisionGroup = CollisionGroupConstants.WaterParts
   -- // Players always fall through water. Touched / GetTouchingParts still work because the part has a Touched connection
   functionalChild.CanCollide = false

   SessionConnections[functionalChild] = functionalChild.Touched:Connect(function(otherPart)
      if otherPart and otherPart.Parent then
         local character = otherPart:FindFirstAncestorWhichIsA("Model")
         if not character then
            return
         end
         local player = game.Players:GetPlayerFromCharacter(character)
         if not player then
            return
         end
         Water.PlayerEnteredWater:Execute("serial", player, functionalChild)
      end
   end)
end

-- // Server only: drown players once the centre of their body (root) is in the water.
-- // Checked every frame rather than on Touched, so feet touching the water or the edge is safe.
local function checkDrowning()
   local waterParts = Water.getCurrentWaterParts()
   if #waterParts == 0 then
      return
   end
   for _, player in ipairs(game.Players:GetPlayers()) do
      local character = player.Character
      if not character or character:GetAttribute(DROWNED_ATTRIBUTE) then
         continue
      end
      local root = character:FindFirstChild("HumanoidRootPart")
      if not root or not root:IsA("BasePart") then
         continue
      end
      for _, waterPart in ipairs(waterParts) do
         if waterPart:IsA("BasePart") and isPositionInWater(waterPart, root.Position) then
            drownPlayer(player, character, waterPart)
            break
         end
      end
   end
end

function Water.init()
   if isServer and not drownCheckConnection then
      drownCheckConnection = game:GetService("RunService").Heartbeat:Connect(checkDrowning)
   end
end

function Water.cleanup()
   for functionalChild, connection in pairs(SessionConnections) do
      if connection then
         connection:Disconnect()
      end
   end
   SessionConnections = {}
end

return Water
