local MovingPlatform = {}

local RunService = game:GetService("RunService")
local GameStateLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameStateLibrary"))
local SimpleRemotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Networking"):WaitForChild("SimpleRemotes"))

local NewMovingPlatform = SimpleRemotes.getEvent("NewMovingPlatform")
local MovingPlatformSnapshot = SimpleRemotes.getUnreliableEvent("MovingPlatformSnapshot")
local CollisionGroupConstants = require(game.ReplicatedStorage.Shared.Constants.CollisionGroupConstants)

type MovingPlatformAttributes = {
   Speed: number,
   StartPivot: CFrame,
   EndPivot: CFrame,
   RestTime: number?, -- How long it should rest at start or end position before resuming
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
   }
} = {}

local connections: {RBXScriptConnection} = {}
local snapshotFrequency = 5/60
local isServer = RunService:IsServer()

local function reset()
   table.clear(platforms)
   for _, connection in pairs(connections) do
      connection:Disconnect()
   end
   table.clear(connections)
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

local function getPivot(endPivot: CFrame, startPivot: CFrame, speed: number, restTime: number, serverTime: number, startedAt: number)
local distance = (endPivot.Position - startPivot.Position).Magnitude
	local travelTime = distance / speed
	local cycleTime = restTime + travelTime + restTime + travelTime

	local elapsed = serverTime - startedAt
	local cycle = elapsed % cycleTime

	-- Resting at start
	if cycle < restTime then
		return startPivot, 0, cycle < travelTime
	end

	cycle -= restTime

	-- Moving start -> end
	if cycle < travelTime then
		local alpha = cycle / travelTime
		return CFrame.new(startPivot.Position:Lerp(endPivot.Position, alpha)), alpha, cycle < travelTime
	end

	cycle -= travelTime

	-- Resting at end
	if cycle < restTime then
		return endPivot, 1, cycle < travelTime
	end

	cycle -= restTime

	-- Moving end -> start
	local alpha = cycle / travelTime
	return CFrame.new(endPivot.Position:Lerp(startPivot.Position, alpha)), alpha, cycle < travelTime
end

local function beginRendering()
   if #connections > 0 then
      return
   end
   if isServer then
      -- Authoritative snapshotting
      table.insert(connections, RunService.PostSimulation:Connect(function()
          for _, platformData in pairs(platforms) do
            local pivot, alpha, fromStart = getPivot(platformData.EndPivot, platformData.StartPivot, platformData.CurrentSpeed, platformData.RestTime or 0, game.Workspace:GetServerTimeNow(), platformData.StartedAt)
            local newPosition = pivot.Position
            local lastPosition = platformData.CurrentPivot.Position
            if (newPosition - lastPosition).Magnitude > 0.0001 then
               platformData.CurrentPivot = pivot
               platformData.Part:PivotTo(pivot) -- TODO: maintain orientation
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
   else
      -- Clientside prediction
      table.insert(connections, RunService.PreSimulation:Connect(function()
         for _, platformData in pairs(platforms) do
            local pivot = getPivot(platformData.EndPivot, platformData.StartPivot, platformData.CurrentSpeed, platformData.RestTime or 0, game.Workspace:GetServerTimeNow(), platformData.StartedAt)
            platformData.CurrentPivot = pivot
            platformData.Part:PivotTo(pivot) -- TODO: maintain orientation
         end
      end))
   end
end

function MovingPlatform.onObjectAdded(platformFolder: Folder, _birth: number?)
   local platform = platformFolder:FindFirstChild("Platform")
   if not platform then
      warn(`Moving platform folder missing Platform part: ${platformFolder.Name}`)
      return
   end

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
   
   platform.Anchored = true

   platform:PivotTo(startPosition)

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
   })

   if isServer then
      NewMovingPlatform:FireAllClients(platform.Name, birth)
   end

   beginRendering()
end

function MovingPlatform.init()
   local gameStateData = GameStateLibrary.getGameStateData()

   gameStateData.IsInRound:Subscribe(function(isInRound)
      if not isInRound then
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