local PermanentFire = {}

local SessionConnections: {[Instance]: RBXScriptConnection} = {}

local TasksList = require(game:GetService("ReplicatedStorage").Shared.Classes.TasksList)
local CollisionGroupConstants = require(game:GetService("ReplicatedStorage").Shared.Constants.CollisionGroupConstants)
local GameStateLibrary = require(game:GetService("ReplicatedStorage").Shared.Library.GameStateLibrary)

PermanentFire.PlayerTouchedFire = TasksList.new() :: TasksList.TasksList<(player: Player, permanentfirePart: Instance) -> ()>

function PermanentFire.validate(functionalChild: Instance): boolean
   if not functionalChild:IsA("Part") and not functionalChild:IsA("BasePart") and not functionalChild:IsA("MeshPart") then
      warn(`PermanentFire.validate: functionalChild {functionalChild:GetFullName()} is not a Part, BasePart, or MeshPart`)
      return false
   end
   if not functionalChild:FindFirstChild("Volume") then
      warn(`PermanentFire.validate: functionalChild {functionalChild:GetFullName()} does not have a Volume child`)
      return false
   end
   functionalChild.Volume.CanTouch = true
   functionalChild.Volume.Transparency = 1
   functionalChild.Volume.CollisionGroup = CollisionGroupConstants.Fire
   return true
end

function PermanentFire.onObjectAdded(functionalChild: Instance)
   if functionalChild:GetAttribute("Invalid") then
      return
   end

   SessionConnections[functionalChild] = functionalChild.Volume.Touched:Connect(function(otherPart)
      if otherPart and otherPart.Parent then
         local character = otherPart:FindFirstAncestorWhichIsA("Model")
         if not character then
            return
         end
         local player = game.Players:GetPlayerFromCharacter(character)
         if not player then
            return
         end
         PermanentFire.PlayerTouchedFire:Execute("serial", player, functionalChild)
      end
   end)
   -- // The entry goes with the map
   functionalChild.Destroying:Once(function()
      local connection = SessionConnections[functionalChild]
      if connection then
         connection:Disconnect()
         SessionConnections[functionalChild] = nil
      end
   end)
end

function PermanentFire.cleanup()
   for functionalChild, connection in pairs(SessionConnections) do
      if connection then
         connection:Disconnect()
      end
   end
   SessionConnections = {}
end

-- // Round end (players back in the lobby): the arena's fire is done
function PermanentFire.init()
   GameStateLibrary.getGameStateData().CurrentRoundData:Subscribe(function(currentRoundData)
      if currentRoundData == nil then
         PermanentFire.cleanup()
      end
   end)
end

return PermanentFire