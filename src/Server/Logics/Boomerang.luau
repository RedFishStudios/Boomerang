-- // Regulates boomerang functionality

local Boomerang = {}

local ReplicatedStorage = game.ReplicatedStorage
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local ToolAssets = ReplicatedStorage.Shared.Assets.Tools
local ThrownWeapons = require(game.ServerStorage.Server.Referential.ThrownWeapons)
local RoundService = require(game.ServerStorage.Server.Core.RoundService)

local Characters = game.Workspace.Characters
local ThrownWeaponsFolder = game.Workspace.ThrownWeapons
local ThrownWeaponReplicationPart = ReplicatedStorage.Shared.Assets.ThrownWeaponReplication

local RunService = game:GetService("RunService")

local SLOW_RATE = 5

function Boomerang.throw(player: Player, boomerangId: string, toolData: Tools.Tool, thrownWeaponData: ThrownWeapons.Data)
   if not toolData.Boomerang then
      warn(`this is not a boomerang`)
      return
   end
   local character = player.Character
   if not character then
      print(`no character`)
      return
   end

   -- TODO: cast in front of the player to see if they already have a wall obstructing them (ie trying to throw the weapon inside a wall)

   local replicationPart = ThrownWeaponReplicationPart:Clone()
   replicationPart.Position = character.PrimaryPart.Position + character.PrimaryPart.CFrame.LookVector * 3
   replicationPart.Parent = ThrownWeaponsFolder
   thrownWeaponData.ReplicationPart = replicationPart

   local direction = character.PrimaryPart.CFrame.LookVector
   direction = Vector3.new(direction.X, 0, direction.Z).Unit
   local speed = toolData.Boomerang.Speed
   local energy = toolData.Boomerang.Bounces

   local Connection
   Connection = RunService.Stepped:Connect(function(time, deltaTime)
      if not replicationPart or not replicationPart.Parent then
         return
      end

      -- Exhaustion
      if energy <= 0 then
         speed = speed - speed * SLOW_RATE * deltaTime
         if speed <= 0 then
            Connection:Disconnect()
         end
      end

      -- Raycast in front of the boomerang to detect collisions with walls or other obstacles
      -- TODO: move to a shared utility as many weapons will use similar raycasts
      -- TODO: raycast params can be moved outside of this function so we aren't creating new ones every frame
      local rayOrigin = replicationPart.Position
      local rayDirection = direction * speed * deltaTime
      local raycastParams = RaycastParams.new()
      raycastParams.FilterDescendantsInstances = {replicationPart} -- TODO: add throwing player or anyone on the throwing player's team
      raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
      local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

      -- Result
      if raycastResult then
         local struckObject = raycastResult.Instance
         print(`Boomerang struck {struckObject.Name}`)

         if struckObject:IsDescendantOf(Characters) then
            print('STRUCK A PLAYER')
            if energy > 0 and RoundService.isInRound() then 
               print(`deal damage`)
            else
               print(`exhausted; deal no damage`)
            end
         else
            print('STRUCK OBSTRUCTION')
            energy -= 1
            direction = direction - 2 * direction:Dot(raycastResult.Normal) * raycastResult.Normal
            direction = Vector3.new(direction.X, 0, direction.Z).Unit
            if energy == 0 then
               print(`become exhausted`)
               local Data = ThrownWeapons.Data[player]
               if Data then
                  Data.State = ThrownWeapons.StateEnum.Exhausted
               end
            end
            return
         end
      end

      local currentCFrame = replicationPart.CFrame
      replicationPart:PivotTo(currentCFrame + direction * speed * deltaTime)
   end)
end

function Boomerang.recall(player: Player, boomerangId: string, toolData: Tools.Tool, thrownToolData: ThrownWeapons.Data)
   if not toolData.Boomerang then
      warn(`this is not a boomerang`)
      return
   end
   local character = player.Character
   if not character then
      print(`no character`)
      return
   end
   local replicationPart = thrownToolData.ReplicationPart  
   if not replicationPart or not replicationPart.Parent then
      warn(`no replication part found for thrown tool`)
      return
   end

   local speed = 0
   local movingTowardsPlayerPercentage = 1

   local Connection
   Connection = RunService.Stepped:Connect(function(_, deltaTime)
      if not replicationPart or not replicationPart.Parent then
         Connection:Disconnect()
         return
      end

      local rootPart = character and character.PrimaryPart
      if not rootPart then
         Connection:Disconnect()
         return
      end

      local toPlayer = (rootPart.Position - replicationPart.Position)
      local distance = toPlayer.Magnitude
      local direction = toPlayer.Unit

      -- Raycast in front of the boomerang to detect collisions with walls or other obstacles
      -- TODO: move to a shared utility as many weapons will use similar raycasts
      local rayOrigin = replicationPart.Position
      local rayDirection = direction * (math.max(speed, 5)) * deltaTime
      local raycastParams = RaycastParams.new()
      raycastParams.FilterDescendantsInstances = {replicationPart, Characters}
      raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
      local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

      -- // Hit obstruction = move perpendicularly along the wall to slide around it
      if raycastResult and raycastResult.Instance then
         speed = 0
         local normal = raycastResult.Normal
         
         -- Direction along the wall.
         local slideDirection = direction - normal * direction:Dot(normal)
         local slideMagnitude = slideDirection.Magnitude

         if slideMagnitude < 0.01 then
            speed = 0
            return
         end

         slideDirection = slideDirection.Unit

         local slideSpeed = toolData.Boomerang.Speed * slideMagnitude
         local slideDistance = slideSpeed * deltaTime

         local slideHit = workspace:Raycast(
            replicationPart.Position,
            slideDirection * slideDistance,
            raycastParams
         )

         if slideHit and not slideHit.Instance:IsDescendantOf(Characters) then
            speed = 0
            return
         end

         replicationPart:PivotTo(
            replicationPart.CFrame + slideDirection * slideDistance
         )
      else
         speed = math.min(speed + deltaTime * 60, toolData.Boomerang.Speed)
      end

      if distance <= speed * deltaTime then
         -- Close enough to snap and consider returned
         replicationPart:Destroy()
         ThrownWeapons.Data[player] = nil
         Connection:Disconnect()
         return
      end

      replicationPart:PivotTo(replicationPart.CFrame + direction * speed * deltaTime)
   end)
end

return Boomerang