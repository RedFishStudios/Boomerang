local Water = {}

local SessionConnections: {[Instance]: RBXScriptConnection} = {}

local TasksList = require(game:GetService("ReplicatedStorage").Shared.Classes.TasksList)
local CollisionGroupConstants = require(game:GetService("ReplicatedStorage").Shared.Constants.CollisionGroupConstants)

Water.PlayerEnteredWater = TasksList.new() :: TasksList.TasksList<(player: Player, waterPart: Instance) -> ()>

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
   print(`water object added!`)
   if functionalChild:GetAttribute("Invalid") then
      warn(`invalid`)
      return
   end
   functionalChild.CollisionGroup = CollisionGroupConstants.WaterParts

   SessionConnections[functionalChild] = functionalChild.Touched:Connect(function(otherPart)
      print(`touched part`)
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

function Water.cleanup()
   for functionalChild, connection in pairs(SessionConnections) do
      if connection then
         connection:Disconnect()
      end
   end
   SessionConnections = {}
end

return Water
