local MovingPlatform = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameStateLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameStateLibrary"))
local SimpleRemotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Networking"):WaitForChild("SimpleRemotes"))

local NewMovingPlatform = SimpleRemotes.getEvent("NewMovingPlatform")
local _MovingPlatformSnapshot = SimpleRemotes.getUnreliableEvent("MovingPlatformSnapshot")
local CollisionGroupConstants = require(game.ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local CombatLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("CombatLibrary"))

type MovingPlatformAttributes = {
   Speed: number,
   StartPivot: CFrame,
   EndPivot: CFrame,
   RestTime: number?, -- How long it should rest at start or end position before resuming
}

type PlatformMoverData = {
	Attachment: Attachment,
	AlignPosition: AlignPosition,
	AlignOrientation: AlignOrientation,
}

local platforms: {
   {
      Part: Part,
      Speed: number,
      CurrentSpeed: number,
      StartPivot: CFrame,
      EndPivot: CFrame,
      CurrentPivot: CFrame,
      RestTime: number?,
      StartedAt: number, -- GetServerTimeNow

      StartCrushAlpha: number?,
      EndCrushAlpha: number?,
      EndCrush: Part?,
      StartCrush: Part?,
      Mover: PlatformMoverData,
   }
} = {}

local connections: {RBXScriptConnection} = {}
local _snapshotFrequency = 5/60
local isServer = RunService:IsServer()

local function reset()
   for _, platformData in pairs(platforms) do
      if platformData.Mover then
         if platformData.Mover.AlignPosition then
            platformData.Mover.AlignPosition:Destroy()
         end
         if platformData.Mover.AlignOrientation then
            platformData.Mover.AlignOrientation:Destroy()
         end
         if platformData.Mover.Attachment then
            platformData.Mover.Attachment:Destroy()
         end
      end
   end

   table.clear(platforms)
   for _, connection in pairs(connections) do
      connection:Disconnect()
   end
   table.clear(connections)
end

local function createMoverConstraint(part: Part): PlatformMoverData
   local attachment = Instance.new("Attachment")
   attachment.Name = "MovingPlatformMoverAttachment"
   attachment.Parent = part

   local alignPosition = Instance.new("AlignPosition")
   alignPosition.Name = "MovingPlatformAlignPosition"
   alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
   alignPosition.Attachment0 = attachment
   alignPosition.RigidityEnabled = true
   alignPosition.ApplyAtCenterOfMass = true
   alignPosition.MaxForce = math.huge
   alignPosition.MaxVelocity = math.huge
   alignPosition.Responsiveness = 200
   alignPosition.Parent = part

   local alignOrientation = Instance.new("AlignOrientation")
   alignOrientation.Name = "MovingPlatformAlignOrientation"
   alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
   alignOrientation.Attachment0 = attachment
   alignOrientation.RigidityEnabled = true
   alignOrientation.MaxTorque = math.huge
   alignOrientation.Responsiveness = 200
   alignOrientation.Parent = part

   return {
      Attachment = attachment,
      AlignPosition = alignPosition,
      AlignOrientation = alignOrientation,
   }
end

local function setMoverConstraintTarget(platformData, pivot: CFrame)
   platformData.Mover.AlignPosition.Position = pivot.Position
   platformData.Mover.AlignOrientation.CFrame = pivot
end

local function findPlatformById(name: string): Folder?
   local map = game.Workspace.Arena:FindFirstChildWhichIsA("Model")
   if not map then
      return nil
   end
   local dynamicsFolder = map:FindFirstChild("Dynamics")
   if not dynamicsFolder then
      return nil
   end
   return dynamicsFolder:FindFirstChild(name)
end

local function isCharacterStandingOnPlatform(
	character: Model,
	platform: BasePart
): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	-- Don't carry airborne characters.
	if humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { platform }

	local result = workspace:Raycast(
		root.Position,
		Vector3.new(0, -6, 0),
		rayParams
	)

	return result ~= nil
end

local connections: {[Player]: RBXScriptConnection} = {}

local function moveStandingPlayersWithPlatform(
    platformPart: BasePart,
    deltaPosition: Vector3
)
    for _, player in Players:GetPlayers() do
        local character = player.Character
        if not character then
            continue
        end

        if not isCharacterStandingOnPlatform(character, platformPart) then
            continue
        end
      
    end
end

local function getPivot(endPivot: CFrame, startPivot: CFrame, speed: number, restTime: number, serverTime: number, startedAt: number)
   local distance = (endPivot.Position - startPivot.Position).Magnitude
   if distance <= 1e-5 or speed <= 1e-5 then
      return startPivot, 0, true
   end
	local travelTime = distance / speed
	local cycleTime = restTime + travelTime + restTime + travelTime

	local elapsed = serverTime - startedAt
	local cycle = elapsed % cycleTime

	-- Resting at start
	if cycle < restTime then
      return startPivot, 0, true
	end

	cycle -= restTime

	-- Moving start -> end
	if cycle < travelTime then
		local alpha = cycle / travelTime
      return startPivot:Lerp(endPivot, alpha), alpha, true
	end

	cycle -= travelTime

	-- Resting at end
	if cycle < restTime then
      return endPivot, 1, false
	end

	cycle -= restTime

	-- Moving end -> start
	local alpha = cycle / travelTime
   return endPivot:Lerp(startPivot, alpha), alpha, false
end

local function beginRendering()
   if #connections > 0 then
      return
   end
   table.insert(connections, RunService.PreSimulation:Connect(function()
      for _, platformData in pairs(platforms) do
         local pivot, alpha, fromStart = getPivot(platformData.EndPivot, platformData.StartPivot, platformData.CurrentSpeed, platformData.RestTime or 0, game.Workspace:GetServerTimeNow(), platformData.StartedAt)
         local previousPivot = platformData.CurrentPivot
         local newPosition = pivot.Position
         local lastPosition = previousPivot.Position
         local deltaPosition = pivot.Position - previousPivot.Position
         if (newPosition - lastPosition).Magnitude > 0.0001 then
            platformData.CurrentPivot = pivot
            setMoverConstraintTarget(platformData, pivot)

            if isServer then
				moveStandingPlayersWithPlatform(platformData.Part, deltaPosition)
			end

            if fromStart then
               if platformData.EndCrushAlpha and alpha > platformData.EndCrushAlpha then
                  print("END CRUSH")
                  -- TODO: why does this list of parts include the map model?
                  -- this should only detect player hitboxes.
                  local endCrushHitbox = platformData.EndCrush
                  local CrushOverlapParams = OverlapParams.new()
                  CrushOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
                  CrushOverlapParams.CollisionGroup = CollisionGroupConstants.Players
                  local parts = workspace:GetPartBoundsInBox(endCrushHitbox.CFrame, endCrushHitbox.Size, CrushOverlapParams)
                  for _, part in ipairs(parts) do
                     local hitCharacter = part:FindFirstAncestorOfClass("Model")
                     print(hitCharacter)
                     if hitCharacter then
                        local humanoid = hitCharacter:FindFirstChildWhichIsA("Humanoid")
                        if not humanoid or humanoid.Health <= 0 then
                           continue
                        end
                        humanoid:TakeDamage(1000000) -- TODO:PLACEHOLDER
                     end
                  end
               end
            else
               if platformData.StartCrushAlpha and alpha > platformData.StartCrushAlpha then
                  print("START CRUSH")
                  local startCrushHitbox = platformData.StartCrush
                  local CrushOverlapParams = OverlapParams.new()
                  CrushOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
                  CrushOverlapParams.CollisionGroup = CollisionGroupConstants.Players
                  local parts = workspace:GetPartBoundsInBox(startCrushHitbox.CFrame, startCrushHitbox.Size, CrushOverlapParams)
                  for _, part in ipairs(parts) do
                     local hitCharacter = part:FindFirstAncestorOfClass("Model")
                     print(hitCharacter)
                      if hitCharacter then
                        local humanoid = hitCharacter:FindFirstChildWhichIsA("Humanoid")
                         if not humanoid or humanoid.Health <= 0 then
                           continue
                        end
                        humanoid:TakeDamage(1000000) -- TODO:PLACEHOLDER
                     end
                  end
               end
            end
         end
      end
   end))
end

function MovingPlatform.validate(functionalChild: Instance): boolean
   if not functionalChild:IsA("Folder") then
      warn(`Functional child of class 'MovingPlatform' is not a folder: {functionalChild.Name}`)
      return false
   end

   local platform = functionalChild:FindFirstChild("Platform")
   if not platform or not platform:IsA("BasePart") then
      warn(`Moving platform missing Platform part to represent the moving platform itself: {functionalChild.Name}`)
      return false
   end

   local attributes: MovingPlatformAttributes = platform:GetAttributes()
   if not attributes.Speed or not attributes.StartPivot or not attributes.EndPivot then
      warn(`Moving platform missing required attributes: {functionalChild.Name}`)
      warn(`Possessed attributes: {attributes.Speed}, {attributes.StartPivot}, {attributes.EndPivot}`)
      return false
   end

   return true
end

function MovingPlatform.onObjectAdded(platformFolder: Folder, _birth: number?)
   if platformFolder:GetAttribute("Invalid") then
      warn(`skipping invalid moving platform folder: ${platformFolder.Name}`)
      return
   end
   local platform = platformFolder:FindFirstChild("Platform")
   for _, data in pairs(platforms) do
      if data.Part == platform then
         warn(`Moving platform attempted duplicate registration: ${platform.Name}`)
         return
      end
   end

   local attributes: MovingPlatformAttributes = platform:GetAttributes()
   local speed = attributes.Speed or 5
   local startPosition = attributes.StartPivot or platform:GetPivot()
   local endPosition = attributes.EndPivot or platform:GetPivot()
   
   platform:PivotTo(startPosition)
   if isServer then
		platform.Anchored = false
	end

	local mover = createMoverConstraint(platform)
	setMoverConstraintTarget({Mover = mover}, startPosition)

   local startCrush = platformFolder:FindFirstChild("StartCrush")
   local endCrush = platformFolder:FindFirstChild("EndCrush")

   local birth = _birth or game.Workspace:GetServerTimeNow()
   table.insert(platforms, {
      Part = platform,
      Speed = speed,
      CurrentSpeed = speed,
      StartPivot = startPosition,
      EndPivot = endPosition,
      CurrentPivot = startPosition,
      RestTime = attributes.RestTime,
      StartedAt = birth,
      StartCrushAlpha = if startCrush then startCrush:GetAttribute("AtAlpha") else nil,
      EndCrushAlpha = if endCrush then endCrush:GetAttribute("AtAlpha") else nil,
      StartCrush = startCrush,
      EndCrush = endCrush,
		Mover = mover,
   })

   if isServer then
      NewMovingPlatform:FireAllClients(platform.Name, birth)
   end

   beginRendering()
end

function MovingPlatform.init()
   local gameStateData = GameStateLibrary.getGameStateData()

   gameStateData.CurrentRoundData:Subscribe(function(currentRoundData)
      if currentRoundData == nil then
         reset()
      end
   end)

   if isServer then
   else
      NewMovingPlatform.onClientEvent:Connect(function(platformFolderId: string, birth)
         local platformFolder = findPlatformById(platformFolderId)
         if platformFolder and platformFolder:IsA("Folder") then
            MovingPlatform.onObjectAdded(platformFolder, birth)
         end
      end)
   end
end

return MovingPlatform