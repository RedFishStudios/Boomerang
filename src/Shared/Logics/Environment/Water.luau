local Water = {}

local SessionConnections: {[Instance]: RBXScriptConnection} = {}

local TasksList = require(game:GetService("ReplicatedStorage").Shared.Classes.TasksList)
local CollisionGroupConstants = require(game:GetService("ReplicatedStorage").Shared.Constants.CollisionGroupConstants)
local ParticlesLibrary = require(game:GetService("ReplicatedStorage").Shared.Library.ParticlesLibrary)

local isServer = game:GetService("RunService"):IsServer()

local DROWN_CAUSE_LABEL = "Drowned"
local SPLASH_PARTICLE = "Splash"
local SPLASH_EMIT_COUNT = 30
-- // Set on the authoritative character when it drowns; CharacterRenderController reads it so the ragdoll sinks
local DROWNED_ATTRIBUTE = "Drowned"

-- // Lazily required: CombatLibrary -> PickupLibrary -> pickup logics require this module (load-time circular require)
local CombatLibrary = nil
local function getCombatLibrary()
   if not CombatLibrary then
      CombatLibrary = require(game:GetService("ReplicatedStorage").Shared.Library.CombatLibrary)
   end
   return CombatLibrary
end

Water.PlayerEnteredWater = TasksList.new() :: TasksList.TasksList<(player: Player, waterPart: Instance) -> ()>
Water.DROWNED_ATTRIBUTE = DROWNED_ATTRIBUTE

-- // Point on the water's top surface above/below the given position
local function getSurfacePoint(waterPart: BasePart, position: Vector3): Vector3
   local localPoint = waterPart.CFrame:PointToObjectSpace(position)
   return waterPart.CFrame:PointToWorldSpace(Vector3.new(localPoint.X, waterPart.Size.Y / 2, localPoint.Z))
end

-- // Server only: kill the player through the normal death path, splash, and let the character sink through the water
local function drownPlayer(player: Player, character: Model, waterPart: BasePart)
   if character:GetAttribute(DROWNED_ATTRIBUTE) then
      return
   end
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not humanoid or humanoid.Health <= 0 then
      return
   end

   getCombatLibrary().applyDamageToHumanoid(player, humanoid, humanoid.MaxHealth, nil, DROWN_CAUSE_LABEL)
   if humanoid.Health > 0 then
      -- // Blocked (e.g. ForceField): stay on the surface
      return
   end

   character:SetAttribute(DROWNED_ATTRIBUTE, true)
   for _, descendant in ipairs(character:GetDescendants()) do
      if descendant:IsA("BasePart") then
         descendant.CollisionGroup = CollisionGroupConstants.SinkingPlayers
      end
   end

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
         -- // After the listeners, so an effect that kills on entry (e.g. electrified water) keeps its elim credit
         if isServer and character == player.Character then
            drownPlayer(player, character, functionalChild :: BasePart)
         end
      end
   end)
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
