local MovingPlatform = {}

local RunService = game:GetService("RunService")
local GameStateLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameStateLibrary"))
local SimpleRemotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Networking"):WaitForChild("SimpleRemotes"))

local NewMovingPlatform = SimpleRemotes.getEvent("NewMovingPlatform")
local MovingPlatformSnapshot = SimpleRemotes.getUnreliableEvent("MovingPlatformSnapshot")

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
   }
} = {}

local renderConnection: RBXScriptConnection? = nil
local snapshotFrequency = 5/60
local isServer = RunService:IsServer()

local function reset()
   table.clear(platforms)
   if renderConnection then
      renderConnection:Disconnect()
      renderConnection = nil
   end
end

local function findPlatformById(name: string): Part?
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

local function getPosition(endPosition: CFrame, startPosition: CFrame, speed: number, restTime: number, serverTime: number, startedAt: number)
local distance = (endPosition.Position - startPosition.Position).Magnitude
	local travelTime = distance / speed
	local cycleTime = restTime + travelTime + restTime + travelTime

	local elapsed = serverTime - startedAt
	local cycle = elapsed % cycleTime

	-- Resting at start
	if cycle < restTime then
		return startPosition.Position
	end

	cycle -= restTime

	-- Moving start -> end
	if cycle < travelTime then
		local alpha = cycle / travelTime
		return startPosition.Position:Lerp(endPosition.Position, alpha)
	end

	cycle -= travelTime

	-- Resting at end
	if cycle < restTime then
		return endPosition.Position
	end

	cycle -= restTime

	-- Moving end -> start
	local alpha = cycle / travelTime
	return endPosition.Position:Lerp(startPosition.Position, alpha)
end

local function beginRendering()
   if renderConnection then
      return
   end
   if isServer then
      -- Authoritative snapshotting
      renderConnection = RunService.PostSimulation:Connect(function()
          for _, platformData in pairs(platforms) do
            local position = getPosition(platformData.EndPivot, platformData.StartPivot, platformData.CurrentSpeed, platformData.RestTime or 0, game.Workspace:GetServerTimeNow(), platformData.StartedAt)
            platformData.CurrentPivot = position
            platformData.Part:PivotTo(CFrame.new(position)) -- TODO: maintain orientation
         end
      end)
   else
      -- Clientside prediction
      renderConnection = RunService.PreSimulation:Connect(function()
         for _, platformData in pairs(platforms) do
            local position = getPosition(platformData.EndPivot, platformData.StartPivot, platformData.CurrentSpeed, platformData.RestTime or 0, game.Workspace:GetServerTimeNow(), platformData.StartedAt)
            platformData.CurrentPivot = position
            platformData.Part:PivotTo(CFrame.new(position)) -- TODO: maintain orientation
         end
      end)
   end
end

function MovingPlatform.onObjectAdded(platform: Part, _birth: number?)
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
      NewMovingPlatform.onClientEvent:Connect(function(platformId: string, birth)
         local platform = findPlatformById(platformId)
         if platform then
            MovingPlatform.onObjectAdded(platform, birth)
         end
      end)

      MovingPlatformSnapshot.onClientEvent:Connect(function(platform: Part, currentPivot: CFrame, timestamp: number)
         -- TODO: implement timestamp
         for _, data in pairs(platforms) do
            if data.Part == platform then
               data.CurrentPivot = currentPivot
               break
            end
         end
      end)
   end
end

return MovingPlatform