local PickupService = game:GetService("ReplicatedStorage").Shared.Services.PickupService
local SharedTasks = require(game:GetService("ReplicatedStorage").Shared.Constants.SharedTasks)

local CustomObjectBecomesPickup = {}

local SessionDestroyers: {[Instance]: RBXScriptConnection} = {}

function CustomObjectBecomesPickup.validate(functionalChild: Instance): boolean
end

function CustomObjectBecomesPickup.onObjectAdded(functionalChild: Instance)
   if functionalChild:GetAttribute("Invalid") then
      return
   end
   SessionDestroyers[functionalChild] = {}
end

function CustomObjectBecomesPickup.cleanup()
end

return CustomObjectBecomesPickup