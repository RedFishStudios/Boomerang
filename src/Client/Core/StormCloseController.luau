--[[
  Relays round-related functionality and utilities for the client

  Author:
  @Soulsplosion
]]

local StormCloseController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local StormCloseLibrary = require(ReplicatedStorage.Shared.Library.StormCloseLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local RECTANGLE_TWEEN_INFO = TweenInfo.new(
  StormCloseLibrary.RECTANGLE_TWEEN_DURATION,
  Enum.EasingStyle.Quad,
  Enum.EasingDirection.Out
)

local StormCloseRemote = SimpleRemotes.getEvent(StormCloseLibrary.REMOTE_EVENT_NAME)

local StormCloseFolder = workspace:FindFirstChild("StormClose")
if not StormCloseFolder then
  StormCloseFolder = Instance.new("Folder")
  StormCloseFolder.Name = "StormClose"
  StormCloseFolder.Parent = workspace
end

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

local currentStormCloseRectangle: Model? = nil
local currentCenterPosition: Vector3? = nil

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function clearRectangle()
  if currentStormCloseRectangle then
    currentStormCloseRectangle:Destroy()
    currentStormCloseRectangle = nil
  end
  currentCenterPosition = nil
end

local function createWall(model: Model, name: string, size: Vector3, position: Vector3, rotation: Vector3)
  local wall = Instance.new("Part")
  wall.Name = name
  wall.Size = size
  wall.CFrame = CFrame.new(position) * CFrame.Angles(
    math.rad(rotation.X),
    math.rad(rotation.Y),
    math.rad(rotation.Z)
  )
  wall.Anchored = true
  wall.CanCollide = false
  wall.CanTouch = false
  wall.CanQuery = false
  wall.Transparency = 1
  wall.Parent = model

  local attachment0 = Instance.new("Attachment")
  attachment0.Parent = wall
  attachment0.CFrame = CFrame.new(0, -.01, 0) * CFrame.Angles(math.rad(90), 0, math.rad(90))

  local attachment1 = Instance.new("Attachment")
  attachment1.Parent = wall
  attachment1.CFrame = CFrame.new(0, StormCloseLibrary.BEAM_HEIGHT, 0) * CFrame.Angles(math.rad(90), 0, math.rad(90))

  local beam = Instance.new("Beam")
  beam.Color = ColorSequence.new(Color3.new(0.92549, 0.07451, 0.356863))
  beam.Attachment0 = attachment0
  beam.Attachment1 = attachment1
  beam.Parent = wall
  beam.Texture = "rbxassetid://132155326"
  beam.TextureLength = 50
  beam.TextureMode = Enum.TextureMode.Wrap
  beam.TextureSpeed = .5
  beam.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, .5),
    NumberSequenceKeypoint.new(1, 1)
  })
  beam.ZOffset = .1
  beam.CurveSize0 = 0
  beam.CurveSize1 = 0
  beam.Segments = 11
  beam.FaceCamera = false
  beam.Width0 = size.X
  beam.Width1 = size.X
  beam.Enabled = true
end

local function createRectangle(centerPosition: Vector3, width: number, height: number)
  clearRectangle()

  currentCenterPosition = centerPosition

  local model = Instance.new("Model")
  model.Name = "Rectangle"
  model.Parent = StormCloseFolder

  for name, target in pairs(StormCloseLibrary.getRectangleWallDefinitions(centerPosition, width, height)) do
    createWall(model, name, target.size, target.position, target.rotation)
  end

  currentStormCloseRectangle = model
end

local function shiftRectangle(width: number, height: number)
  if not currentStormCloseRectangle or not currentCenterPosition then
    return
  end

  for name, target in pairs(StormCloseLibrary.getRectangleWallDefinitions(currentCenterPosition, width, height)) do
    local wall = currentStormCloseRectangle:FindFirstChild(name)
    if wall and wall:IsA("BasePart") then
      local beam = wall:FindFirstChildWhichIsA("Beam")

      local wallTween = TweenService:Create(
        wall,
        RECTANGLE_TWEEN_INFO,
        {
          Size = target.size,
          Position = target.position,
        }
      )
      wallTween:Play()

      if beam then
        local widthValue = Instance.new("NumberValue")
        widthValue.Value = beam.Width0

        local widthConnection
        widthConnection = widthValue:GetPropertyChangedSignal("Value"):Connect(function()
          beam.Width0 = widthValue.Value
          beam.Width1 = widthValue.Value
        end)

        local widthTween = TweenService:Create(
          widthValue,
          RECTANGLE_TWEEN_INFO,
          {
            Value = target.size.X,
          }
        )

        widthTween.Completed:Connect(function()
          widthConnection:Disconnect()
          widthValue:Destroy()

          beam.Width0 = target.size.X
          beam.Width1 = target.size.X
        end)

        widthTween:Play()
      end
    end
  end
end

function StormCloseController.init()
  SimpleRemotesUtil.bindRemoteEventActions(StormCloseRemote, {
    [StormCloseLibrary.REMOTE_ACTION_CREATE] = function(centerPosition: Vector3, width: number, height: number)
      createRectangle(centerPosition, width, height)
    end,
    [StormCloseLibrary.REMOTE_ACTION_SHIFT] = function(width: number, height: number)
      shiftRectangle(width, height)
    end,
    [StormCloseLibrary.REMOTE_ACTION_CLEAR] = function()
      clearRectangle()
    end,
  })
end

-- function StormCloseController.start() end

-- function StormCloseController.test() end

return StormCloseController
