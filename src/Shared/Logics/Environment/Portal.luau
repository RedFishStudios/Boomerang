local Portal = {}

local SessionConnections: {[Instance]: RBXScriptConnection} = {}
local TeleportDebounces: {[Player]: number} = {}
local AwaitingDebounce: {[Player]: number} = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaLibrary = require(ReplicatedStorage.Shared.Library.ArenaLibrary)

-- // A portal is a direct child of the arena's "Functional" folder with attribute ClassName = "Portal".
-- // It is a Part (entry A) containing an Attachment and a child Part (entry B) with its own Attachment.
-- // Convention: each Attachment faces OUT of its portal (players exit facing it).
local PROJECTILE_PORTAL_COOLDOWN = 0.25 -- // Seconds after exiting before a projectile can enter a portal again

type PortalPair = { A: BasePart, B: BasePart, AttachmentA: Attachment, AttachmentB: Attachment }
export type ProjectileExit = { Position: Vector3, Direction: Vector3, EntryPart: BasePart, ExitPart: BasePart, EntryDistance: number }

local cachedArenaModel: Model? = nil
local cachedPairs: {PortalPair} = {}

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

-- // Portal pairs of the current arena, found from the map itself so the server and clients agree without replication
local function getArenaPortalPairs(): {PortalPair}
   local arenaModel = ArenaLibrary.getArenaModel()
   if arenaModel == cachedArenaModel then
      return cachedPairs
   end
   cachedArenaModel = arenaModel
   cachedPairs = {}
   local functional = arenaModel and arenaModel:FindFirstChild("Functional")
   if not functional then
      return cachedPairs
   end
   for _, child in ipairs(functional:GetChildren()) do
      if child:GetAttribute("ClassName") ~= "Portal" or child:GetAttribute("Invalid") or not child:IsA("BasePart") then
         continue
      end
      local other = child:FindFirstChildWhichIsA("BasePart")
      local attachmentA = child:FindFirstChildWhichIsA("Attachment")
      local attachmentB = other and other:FindFirstChildWhichIsA("Attachment")
      if other and attachmentA and attachmentB then
         table.insert(cachedPairs, { A = child, B = other, AttachmentA = attachmentA, AttachmentB = attachmentB })
      end
   end
   return cachedPairs
end

-- // Returns the distance along the segment at which it enters the part's box (expanded by radius), or nil
local function segmentEntersPart(part: BasePart, origin: Vector3, direction: Vector3, distance: number, radius: number): number?
   local localOrigin = part.CFrame:PointToObjectSpace(origin)
   local localDirection = part.CFrame:VectorToObjectSpace(direction)
   local halfSize = part.Size / 2 + Vector3.new(radius, radius, radius)
   local tMin, tMax = 0, distance
   for _, axis in ipairs({ "X", "Y", "Z" }) do
      local o, d, h = localOrigin[axis], localDirection[axis], halfSize[axis]
      if math.abs(d) < 1e-6 then
         if o < -h or o > h then
            return nil
         end
      else
         local t1, t2 = (-h - o) / d, (h - o) / d
         if t1 > t2 then
            t1, t2 = t2, t1
         end
         tMin = math.max(tMin, t1)
         tMax = math.min(tMax, t2)
         if tMin > tMax then
            return nil
         end
      end
   end
   return tMin
end

local function toHorizontalUnit(v: Vector3): Vector3?
   local horizontal = Vector3.new(v.X, 0, v.Z)
   if horizontal.Magnitude < 1e-5 then
      return nil
   end
   return horizontal.Unit
end

-- // For projectiles (e.g. thrown boomerangs): if the step from origin along direction for distance enters a portal,
-- // returns where it comes out of the paired portal and its new direction. Keeps the projectile's height.
-- // lastExitAt/ lastExitPart (optional) stop a projectile from immediately re-entering the portal it just left.
function Portal.getProjectileExit(origin: Vector3, direction: Vector3, distance: number, radius: number, lastExitAt: number?, lastExitPart: BasePart?): ProjectileExit?
   local nearestT, nearestEntry, nearestPair = math.huge, nil, nil
   local isCoolingDown = lastExitAt ~= nil and os.clock() - lastExitAt < PROJECTILE_PORTAL_COOLDOWN
   for _, pair in ipairs(getArenaPortalPairs()) do
      for _, entry in ipairs({ pair.A, pair.B }) do
         if not entry.Parent or (isCoolingDown and entry == lastExitPart) then
            continue
         end
         local t = segmentEntersPart(entry, origin, direction, distance, radius)
         if t and t < nearestT then
            nearestT, nearestEntry, nearestPair = t, entry, pair
         end
      end
   end
   if not nearestEntry or not nearestPair then
      return nil
   end

   local entryAttachment = if nearestEntry == nearestPair.A then nearestPair.AttachmentA else nearestPair.AttachmentB
   local exitAttachment = if nearestEntry == nearestPair.A then nearestPair.AttachmentB else nearestPair.AttachmentA
   local exitPart = if nearestEntry == nearestPair.A then nearestPair.B else nearestPair.A

   -- // Map the direction through the pair: relative to the entry portal, turned around, then relative to the exit portal
   local localDirection = entryAttachment.WorldCFrame:VectorToObjectSpace(direction)
   local turnedAround = CFrame.Angles(0, math.pi, 0):VectorToWorldSpace(localDirection)
   local exitLook = toHorizontalUnit(exitAttachment.WorldCFrame.LookVector) or toHorizontalUnit(direction) or Vector3.new(0, 0, -1)
   local newDirection = toHorizontalUnit(exitAttachment.WorldCFrame:VectorToWorldSpace(turnedAround)) or exitLook
   if newDirection:Dot(exitLook) <= 0 then
      newDirection = exitLook -- // Never send it back into the exit portal
   end

   local exitPosition = exitAttachment.WorldPosition
   return {
      Position = Vector3.new(exitPosition.X, origin.Y, exitPosition.Z),
      Direction = newDirection,
      EntryPart = nearestEntry,
      ExitPart = exitPart,
      EntryDistance = nearestT, -- // How far along the step it flew before entering (the teleport itself isn't flight)
   }
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