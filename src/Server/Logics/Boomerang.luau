-- // Regulates boomerang functionality

local Boomerang = {}

local ReplicatedStorage = game.ReplicatedStorage
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local ToolAssets = ReplicatedStorage.Shared.Assets.Tools
local ThrownWeapons = require(game.ServerStorage.Server.Referential.ThrownWeapons)
local RoundService = require(game.ServerStorage.Server.Core.RoundService)

local Characters = game.Workspace.Characters
local ThrownWeaponsFolder = game.Workspace.ThrownWeapons
local ThrownWeaponReplicationPart = ReplicatedStorage.Shared.Assets.ThrownWeaponReplication

local RunService = game:GetService("RunService")

local SLOW_RATE = 5
local UP_VECTOR = Vector3.new(0, 1, 0)

local function raycastWithHorizontalHitbox(
   rayOrigin: Vector3,
   direction: Vector3,
   rayDistance: number,
   hitboxRadius: number,
   raycastParams: RaycastParams
): RaycastResult?
   local raycastResult = RaycastsUtility.raycastProjectileObstruction(rayOrigin, direction, rayDistance, raycastParams)
   if raycastResult or hitboxRadius <= 0 then
      return raycastResult
   end

   local rightDirection = direction:Cross(UP_VECTOR)
   if rightDirection.Magnitude <= 0 then
      return nil
   end
   rightDirection = rightDirection.Unit

   local leftOrigin = rayOrigin - rightDirection * hitboxRadius
   raycastResult = RaycastsUtility.raycastProjectileObstruction(leftOrigin, direction, rayDistance, raycastParams)
   if raycastResult then
      return raycastResult
   end

   local rightOrigin = rayOrigin + rightDirection * hitboxRadius
   return RaycastsUtility.raycastProjectileObstruction(rightOrigin, direction, rayDistance, raycastParams)
end

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
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local energy = toolData.Boomerang.Bounces
   local raycastParams = RaycastsUtility.getProjectileObstructionParams({replicationPart}) -- TODO: add throwing player or anyone on the throwing player's team

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
      local rayOrigin = replicationPart.Position
      local rayDistance = speed * deltaTime
      local raycastResult = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams)

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

   local maximumSpeed = toolData.Boomerang.Speed
   local speed = 0
   local hitboxRadius = toolData.Boomerang.HitboxRadius
   local movingTowardsPlayerPercentage = 1
   local raycastParams = RaycastsUtility.getProjectileObstructionParams({replicationPart, Characters})

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

      local currentMovementDirection

      -- // Prioritize movement towards the player
      local toPlayer = (rootPart.Position - replicationPart.Position)
      local distance = toPlayer.Magnitude
      local direction = toPlayer.Unit

      -- // Raycast in that direction for an obstruction
      local rayOrigin = replicationPart.Position
      local rayDistance = (math.max(speed, hitboxRadius)) * deltaTime
      local raycastResult = raycastWithHorizontalHitbox(rayOrigin, direction, rayDistance, hitboxRadius, raycastParams)

      -- // If we hit something, adjust movement direction to move perpendicular to the obstruction
      if raycastResult and raycastResult.Instance then
         -- Determine new movement direction adjacent to the obstructing surface
         -- Prioritize whichever direction brings the boomerang closer to the player
         local normal = raycastResult.Normal
         local slideDirection = direction - normal * direction:Dot(normal)
         local slideMagnitude = slideDirection.Magnitude
         slideDirection = slideDirection.Unit

         -- Obstruction is directly between player and wall = stop movement
         if slideMagnitude < 0.01 then
            return
         end

         -- Determine new slide speed
         local maximumSlideSpeed = math.clamp(maximumSpeed * slideMagnitude, 0, maximumSpeed)
         local slideSpeed = math.clamp(speed + deltaTime * 60, 0, maximumSlideSpeed)
         local slideDistance = slideSpeed * deltaTime

         local slideHit = workspace:Raycast(
            replicationPart.Position,
            slideDirection * slideDistance,
            raycastParams
         )

         if slideHit and not slideHit.Instance:IsDescendantOf(Characters) then
            return
         end

         replicationPart:PivotTo(
            replicationPart.CFrame + slideDirection * slideDistance
         )
      else
         speed = math.min(speed + deltaTime * 60, toolData.Boomerang.Speed)
         replicationPart:PivotTo(replicationPart.CFrame + direction * speed * deltaTime)
      end

      if distance <= speed * deltaTime then
         -- Close enough to snap and consider returned
         replicationPart:Destroy()
         ThrownWeapons.Data[player] = nil
         Connection:Disconnect()
         return
      end
   end)
end

return Boomerang