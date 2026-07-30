local MovingPlatform = {}

local RunService = game:GetService("RunService")
local GameStateLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameStateLibrary"))
local SimpleRemotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Networking"):WaitForChild("SimpleRemotes"))

local NewMovingPlatform = SimpleRemotes.getEvent("NewMovingPlatform")

type MovingPlatformAttributes = {
   Speed: number,
   StartPosition: Vector3,
   EndPosition: Vector3
}

local platforms: {
   {
      Part: Part,
      Speed: number,
      StartPosition: Vector3,
      EndPosition: Vector3,
      CurrentPosition: Vector3,
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

local function beginRendering()
   if renderConnection then
      return
   end
   if isServer then
      -- Authoritative snapshotting
      renderConnection = RunService.Heartbeat:Connect(function()
      end)
   else
      -- Clientside prediction
      renderConnection = RunService.RenderStepped:Connect(function()

      end)
   end
end

function MovingPlatform.render(platform: Part, _birth: number?)
   local attributes: MovingPlatformAttributes = platform:GetAttributes()
   local speed = attributes.Speed or 5
   local startPosition = attributes.StartPosition or platform.Position
   local endPosition = attributes.EndPosition or platform.Position

   local birth = _birth or game.Workspace:GetServerTimeNow()
   table.insert(platforms, {
      Part = platform,
      Speed = speed,
      StartPosition = startPosition,
      EndPosition = endPosition,
      CurrentPosition = startPosition,
      StartedAt = birth,
   })

   if isServer then
      NewMovingPlatform:FireAllClients(platform, birth)
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
      NewMovingPlatform.onClientEvent:Connect(function(platform, birth)
         MovingPlatform.render(platform, birth)
      end)
   end
end

return MovingPlatform