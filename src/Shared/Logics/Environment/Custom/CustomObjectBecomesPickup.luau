local PickupService = require(game.ServerStorage.Server.Core.PickupService)
local SharedTasks = require(game:GetService("ReplicatedStorage").Shared.Constants.SharedTasks)

local CustomObjectBecomesPickup = {}

local SessionDestroyers: {[Instance]: RBXScriptConnection} = {}

function CustomObjectBecomesPickup.validate(functionalChild: Instance): boolean
   return true
end

function CustomObjectBecomesPickup.onObjectAdded(functionalChild: Instance)
   if functionalChild:GetAttribute("Invalid") then
      return
   end
   SessionDestroyers[functionalChild] = {}
   table.insert(SessionDestroyers[functionalChild], SharedTasks.ThrownWeaponHitObject:Add(function(player: Player, toolId: string, hitObject: Instance, hitPosition: Vector3)
      if hitObject == functionalChild then
         PickupService.createLivePickupAtPosition(hitPosition)
         hitObject:Destroy()
         CustomObjectBecomesPickup.cleanup(functionalChild)
      end
   end))
end

function CustomObjectBecomesPickup.cleanup(functionalChild: Instance)
   if SessionDestroyers[functionalChild] then
      for _, destroyer in pairs(SessionDestroyers[functionalChild]) do
         destroyer()
      end
      SessionDestroyers[functionalChild] = nil
   end
end

return CustomObjectBecomesPickup