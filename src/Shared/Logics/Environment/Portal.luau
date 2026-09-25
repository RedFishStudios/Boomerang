local Portal = {}

local SessionConnections: {[Instance]: RBXScriptConnection} = {}
local TeleportDebounces: {[Player]: number} = {}
local AwaitingDebounce: {[Player]: number} = {}

local Players = game:GetService("Players")

local ValidPortals: {
   [Part]: Part
} = {}

function Portal.validate(functionalChild: Instance): boolean
   local otherPart = functionalChild:FindFirstChildWhichIsA("Part")
   if not otherPart then
      error(`portal not valid: missing part in functional child ${functionalChild:GetFullName()}`)
      return false
   end
   local portalPosition = functionalChild:FindFirstChildWhichIsA("Attachment")
   if not portalPosition then
      error(`portal not valid: missing attachment in functional child ${functionalChild:GetFullName()}`)
      return false
   end
   portalPosition = otherPart:FindFirstChildWhichIsA("Attachment")
   if not portalPosition then
      error(`portal not valid: missing attachment in other part ${otherPart:GetFullName()}`)
      return false
   end
   ValidPortals[functionalChild] = otherPart
   ValidPortals[otherPart] = functionalChild
   return true
end

function Portal.onObjectAdded(functionalChild: Instance)
   local otherPart = ValidPortals[functionalChild]

   local functionalAttachment = functionalChild:FindFirstChildWhichIsA("Attachment")
   local otherAttachment = otherPart:FindFirstChildWhichIsA("Attachment")
   if not functionalAttachment or not otherAttachment then
      warn(`portal not valid: missing attachment in functional child ${functionalChild:GetFullName()} or other part ${otherPart:GetFullName()}`)
      return
   end

   local function teleportFrom(targetAttachment: Attachment, hit: BasePart, sourcePart: BasePart)
      local character = hit:FindFirstAncestorOfClass("Model")
      local player = character and Players:GetPlayerFromCharacter(character)
      local rootPart = character and character.PrimaryPart
      if not player or not character or not rootPart then
         return
      end

      local now = workspace:GetServerTimeNow()
      if TeleportDebounces[player] and TeleportDebounces[player] > now then
         local thisDebounceId = (AwaitingDebounce[player] or 0) + 1
         AwaitingDebounce[player] = thisDebounceId
         repeat
            task.wait(.1)
         until AwaitingDebounce[player] ~= thisDebounceId or TeleportDebounces[player] > now or not player.Parent
         if not player.Parent then
            AwaitingDebounce[player] = nil
            return
         end
         if AwaitingDebounce[player] ~= thisDebounceId then
            -- A different thread began awaiting debounce
            return
         end
         local touching = sourcePart:GetTouchingParts()
         local yep = false
         for _, part in ipairs(touching) do
            if part == hit then
               yep = true
            end
         end
         if not yep then 
            return
         end
      end
      TeleportDebounces[player] = now + 1

      character:PivotTo(targetAttachment.WorldCFrame)
      rootPart.AssemblyLinearVelocity = Vector3.zero
      rootPart.AssemblyAngularVelocity = Vector3.zero
   end

   if SessionConnections[functionalChild] then
      SessionConnections[functionalChild]:Disconnect()
   end
   if SessionConnections[otherPart] then
      SessionConnections[otherPart]:Disconnect()
   end

   SessionConnections[functionalChild] = functionalChild.Touched:Connect(function(hit)
      teleportFrom(otherAttachment, hit, functionalChild)
   end)
   SessionConnections[otherPart] = otherPart.Touched:Connect(function(hit)
      teleportFrom(functionalAttachment, hit, otherPart)
   end)
end

function Portal.cleanup()
   for _, connection in pairs(SessionConnections) do
      if connection then
         connection:Disconnect()
      end
   end
   SessionConnections = {}
   table.clear(TeleportDebounces)
   table.clear(AwaitingDebounce)
end

return Portal