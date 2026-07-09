--[[
   - The camera's preferred centerpoint should be the center of the current map arena.
     However, it can drift from this centerpoint towards the centerpoint calculated from the average center of all players or boomerangs on the map.
]]

local CustomCameraController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local localPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CAMERA_TILT_DEGREES_FROM_VERTICAL = 15
local CAMERA_YAW_DEGREES = 0
local CAMERA_DISTANCE_PADDING = 20
local CAMERA_MIN_DISTANCE = 40

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local thrownWeaponsFolder = game.Workspace:WaitForChild("ThrownWeapons")

local currentCamera: Camera? = nil
local topDownCameraConnection: RBXScriptConnection? = nil

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CustomCameraController.Mode = "TopDown" :: "TopDown" | "Regular"

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getAllPlayersBoundingBox()
   local min = Vector3.new(math.huge, math.huge, math.huge)
   local max = Vector3.new(-math.huge, -math.huge, -math.huge)

   local parts: { BasePart | Model | Tool } = {}
   local sizes: {Vector3} = {}

   for _, player in ipairs(GameStateLibrary.LivingPlayersInArena:Get()) do
      if player.Character and player.Character.PrimaryPart then
         table.insert(parts, player.Character.PrimaryPart)
         table.insert(sizes, player.Character.PrimaryPart.Size)
      end
   end

   for _, weapon in ipairs(thrownWeaponsFolder:GetChildren()) do
      if weapon:IsA("BasePart") then
         table.insert(parts, weapon)
         table.insert(sizes, weapon.Size)
      elseif weapon:IsA("Model") then
         local primaryPart = weapon.PrimaryPart
         if primaryPart then
            table.insert(parts, primaryPart)
            table.insert(sizes, primaryPart.Size)
         end
      elseif weapon:IsA("Tool") then
         local handle = weapon:FindFirstChild("Handle")
         if handle then
            table.insert(parts, handle)
            table.insert(sizes, handle.Size)
         end
      end
   end

   if #parts == 0 then
      local character = localPlayer.Character
      local root = character and character.PrimaryPart
      if root then
         table.insert(parts, root)
         table.insert(sizes, root.Size)
      end
   end

   if #parts == 0 then
      return nil
   end

   for i, part in ipairs(parts) do
      local p = part:GetPivot().Position
      local s = sizes[i] / 2

      min = Vector3.new(
         math.min(min.X, p.X - s.X),
         math.min(min.Y, p.Y - s.Y),
         math.min(min.Z, p.Z - s.Z)
      )

      max = Vector3.new(
         math.max(max.X, p.X + s.X),
         math.max(max.Y, p.Y + s.Y),
         math.max(max.Z, p.Z + s.Z)
      )
   end

   local center = (min + max) / 2
   local size = max - min
   return center, size
end

local function getRequiredDistanceForSize(size: Vector3, cameraBasis: CFrame, aspectRatio: number, verticalFovRadians: number)
   local half = size / 2
   local halfWidth = 0
   local halfHeight = 0

   local right = cameraBasis.RightVector
   local up = cameraBasis.UpVector

   for x = -1, 1, 2 do
      for y = -1, 1, 2 do
         for z = -1, 1, 2 do
            local offset = Vector3.new(half.X * x, half.Y * y, half.Z * z)
            halfWidth = math.max(halfWidth, math.abs(offset:Dot(right)))
            halfHeight = math.max(halfHeight, math.abs(offset:Dot(up)))
         end
      end
   end

   local tanVertical = math.tan(verticalFovRadians / 2)
   local horizontalFovRadians = 2 * math.atan(tanVertical * aspectRatio)
   local tanHorizontal = math.tan(horizontalFovRadians / 2)

   local distanceFromWidth = if tanHorizontal > 0 then halfWidth / tanHorizontal else 0
   local distanceFromHeight = if tanVertical > 0 then halfHeight / tanVertical else 0
   return math.max(distanceFromWidth, distanceFromHeight)
end

local function updateCamera()
   if not currentCamera then
      return
   end

   local focusPosition, boxSize = getAllPlayersBoundingBox()
   if not focusPosition or not boxSize then
      return
   end

   local tiltRadians = math.rad(CAMERA_TILT_DEGREES_FROM_VERTICAL)
   local yawRadians = math.rad(CAMERA_YAW_DEGREES)

   local horizontalDirection = Vector3.new(math.sin(yawRadians), 0, math.cos(yawRadians))
   local focusToCameraDirection = (Vector3.yAxis * math.cos(tiltRadians) + horizontalDirection * math.sin(tiltRadians)).Unit

   local baseCFrame = CFrame.lookAt(focusPosition + focusToCameraDirection, focusPosition)
   local distance = getRequiredDistanceForSize(boxSize, baseCFrame, currentCamera.ViewportSize.X / currentCamera.ViewportSize.Y, math.rad(currentCamera.FieldOfView))
   local targetPosition = focusPosition + focusToCameraDirection * math.max(CAMERA_MIN_DISTANCE, distance + CAMERA_DISTANCE_PADDING)

   -- Keep all active arena players in frame from a mostly-overhead tilted angle.
   currentCamera.CFrame = CFrame.lookAt(targetPosition, focusPosition)
	currentCamera.Focus = CFrame.new(focusPosition)
end

local function startTopDownMode()
   if topDownCameraConnection then
      return
   end
   local character = localPlayer.Character
   if not character then
      repeat
         task.wait()
         character = localPlayer.Character
      until character
   end
   if topDownCameraConnection then
      return
   end

   currentCamera = workspace.CurrentCamera
   currentCamera.CameraType = Enum.CameraType.Scriptable
   currentCamera.FieldOfView = 60
   topDownCameraConnection = RunService.RenderStepped:Connect(updateCamera)
end

local function stopTopDownMode()
   if topDownCameraConnection then
      topDownCameraConnection:Disconnect()
      topDownCameraConnection = nil
   end
   currentCamera = nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CustomCameraController.setMode(mode: "TopDown" | "Regular")
   if not GameStateLibrary.LivingPlayersInArena then
      error(`Do not call CustomCameraController.setMode before 'start'`)
   end
   CustomCameraController.Mode = mode
   if mode == "TopDown" then
      startTopDownMode()
   elseif mode == "Regular" then
      stopTopDownMode()
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CustomCameraController.init()
end

function CustomCameraController.start()
   local function onCharacterAdded(character)
      CustomCameraController.setMode("TopDown")
   end

   if localPlayer.Character then
      onCharacterAdded(localPlayer.Character)
   end

   localPlayer.CharacterAdded:Connect(onCharacterAdded)
end

function CustomCameraController.test() end

return CustomCameraController
