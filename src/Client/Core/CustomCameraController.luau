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
local CAMERA_MIN_DISTANCE = 60
local CAMERA_FOCUS_SMOOTH_BASE = 11
local CAMERA_FOCUS_SMOOTH_DISTANCE_FACTOR = 0.08
local CAMERA_FOCUS_SMOOTH_MAX = 42
local CAMERA_DISTANCE_SMOOTH_BASE = 9
local CAMERA_DISTANCE_SMOOTH_DISTANCE_FACTOR = 0.04
local CAMERA_DISTANCE_SMOOTH_MAX = 30

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local thrownWeaponsFolder = game.Workspace:WaitForChild("ThrownWeapons")

local currentCamera: Camera? = nil
local overheadCameraConnection: RBXScriptConnection? = nil
local smoothedFocusPosition: Vector3? = nil
local smoothedCameraDistance: number? = nil

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CustomCameraController.Mode = "Overhead" :: "Overhead" | "Regular"

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Get parameters for the Overhead camera to have these desired objects within its view
local function getAllSubjectsBoundingBox()
   local min = Vector3.new(math.huge, math.huge, math.huge)
   local max = Vector3.new(-math.huge, -math.huge, -math.huge)

   local parts: { BasePart | Model | Tool } = {}
   local sizes: {Vector3} = {}
   local gameStateData = GameStateLibrary.getGameStateData()

   local alphabet = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}
   local thisTick = alphabet[math.random(1, #alphabet)]
   for _, player in ipairs(gameStateData.LivingPlayersInArena:Get()) do
      --print(`{thisTick}: {player}`)
      if player.Team and player.Team.Name == "OutOfGame" then
         -- debug
         warn(`player with out of game team is detected in living players list: {player}`)
         continue
      end
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

-- // Get required camera distance for the camera to possess these subjects within its view
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

-- // Smoothing functions for smooth camera motion
local function expSmoothingAlpha(rate: number, deltaTime: number): number
   return 1 - math.exp(-rate * deltaTime)
end

local function stepSmoothVector3(currentValue: Vector3, targetValue: Vector3, baseRate: number, distanceFactor: number, maxRate: number, deltaTime: number): Vector3
   local distance = (targetValue - currentValue).Magnitude
   local rate = math.clamp(baseRate + distance * distanceFactor, baseRate, maxRate)
   local alpha = expSmoothingAlpha(rate, deltaTime)
   return currentValue:Lerp(targetValue, alpha)
end

local function stepSmoothNumber(currentValue: number, targetValue: number, baseRate: number, distanceFactor: number, maxRate: number, deltaTime: number): number
   local distance = math.abs(targetValue - currentValue)
   local rate = math.clamp(baseRate + distance * distanceFactor, baseRate, maxRate)
   local alpha = expSmoothingAlpha(rate, deltaTime)
   return currentValue + (targetValue - currentValue) * alpha
end

-- // Instantly place overhead camera to fit all visible subjects with no smoothing
local function placeCameraInstantly()
   if not currentCamera then
      return
   end

   local focusPosition, boxSize = getAllSubjectsBoundingBox()
   if not focusPosition or not boxSize then
      return
   end

   local tiltRadians = math.rad(CAMERA_TILT_DEGREES_FROM_VERTICAL)
   local yawRadians = math.rad(CAMERA_YAW_DEGREES)

   local horizontalDirection = Vector3.new(math.sin(yawRadians), 0, math.cos(yawRadians))
   local focusToCameraDirection = (Vector3.yAxis * math.cos(tiltRadians) + horizontalDirection * math.sin(tiltRadians)).Unit

   local baseCFrame = CFrame.lookAt(focusPosition + focusToCameraDirection, focusPosition)
   local requiredDistance = getRequiredDistanceForSize(
      boxSize,
      baseCFrame,
      currentCamera.ViewportSize.X / currentCamera.ViewportSize.Y,
      math.rad(currentCamera.FieldOfView)
   )
   local targetDistance = math.max(CAMERA_MIN_DISTANCE, requiredDistance + CAMERA_DISTANCE_PADDING)

   smoothedFocusPosition = focusPosition
   smoothedCameraDistance = targetDistance

   local cameraPosition = focusPosition + focusToCameraDirection * targetDistance
   currentCamera.CFrame = CFrame.lookAt(cameraPosition, focusPosition, Vector3.yAxis)
   currentCamera.Focus = CFrame.new(focusPosition)
end

-- // Update camera for overhead position
local function updateCamera(deltaTime: number)
   if not currentCamera then
      return
   end

   local focusPosition, boxSize = getAllSubjectsBoundingBox()
   if not focusPosition or not boxSize then
      return
   end

   local tiltRadians = math.rad(CAMERA_TILT_DEGREES_FROM_VERTICAL)
   local yawRadians = math.rad(CAMERA_YAW_DEGREES)

   local horizontalDirection = Vector3.new(math.sin(yawRadians), 0, math.cos(yawRadians))
   local focusToCameraDirection = (Vector3.yAxis * math.cos(tiltRadians) + horizontalDirection * math.sin(tiltRadians)).Unit

   local baseCFrame = CFrame.lookAt(focusPosition + focusToCameraDirection, focusPosition)
   local requiredDistance = getRequiredDistanceForSize(boxSize, baseCFrame, currentCamera.ViewportSize.X / currentCamera.ViewportSize.Y, math.rad(currentCamera.FieldOfView))
   local targetDistance = math.max(CAMERA_MIN_DISTANCE, requiredDistance + CAMERA_DISTANCE_PADDING)

   if not smoothedFocusPosition or not smoothedCameraDistance then
      smoothedFocusPosition = focusPosition
      smoothedCameraDistance = targetDistance
   else
      smoothedFocusPosition = stepSmoothVector3(
         smoothedFocusPosition,
         focusPosition,
         CAMERA_FOCUS_SMOOTH_BASE,
         CAMERA_FOCUS_SMOOTH_DISTANCE_FACTOR,
         CAMERA_FOCUS_SMOOTH_MAX,
         deltaTime
      )
      smoothedCameraDistance = stepSmoothNumber(
         smoothedCameraDistance,
         targetDistance,
         CAMERA_DISTANCE_SMOOTH_BASE,
         CAMERA_DISTANCE_SMOOTH_DISTANCE_FACTOR,
         CAMERA_DISTANCE_SMOOTH_MAX,
         deltaTime
      )
   end

   local cameraPosition = smoothedFocusPosition + focusToCameraDirection * smoothedCameraDistance

	-- Keep orientation stable by deriving camera position from fixed yaw/tilt and smoothed focus+distance.
   currentCamera.CFrame = CFrame.lookAt(cameraPosition, smoothedFocusPosition, Vector3.yAxis)
	currentCamera.Focus = CFrame.new(smoothedFocusPosition)
end

local function startOverheadMode()
   if overheadCameraConnection then
      return
   end
   local character = localPlayer.Character
   if not character then
      repeat
         task.wait()
         character = localPlayer.Character
      until character
   end
   if overheadCameraConnection then
      return
   end

   currentCamera = workspace.CurrentCamera
   currentCamera.CameraType = Enum.CameraType.Scriptable
   currentCamera.FieldOfView = 60
   smoothedFocusPosition = nil
   smoothedCameraDistance = nil
   placeCameraInstantly()
   overheadCameraConnection = RunService.RenderStepped:Connect(updateCamera)
end

local function stopOverheadMode()
   if overheadCameraConnection then
      overheadCameraConnection:Disconnect()
      overheadCameraConnection = nil
   end

   -- I want to position the camera like this:
   -- 3 studs above the player position
   -- 10 studs away from the player position in a direction opposite of their rootpart's lookvector
   local character = localPlayer.Character
   if character then
      local rootPart = character:FindFirstChild("HumanoidRootPart")
      if rootPart then
         local cameraPosition = rootPart.Position + Vector3.new(0, 3, 0) - rootPart.CFrame.LookVector * 10
         currentCamera.CFrame = CFrame.lookAt(cameraPosition, rootPart.Position, Vector3.yAxis)
      end
   end

   currentCamera.CameraType = Enum.CameraType.Custom
   smoothedFocusPosition = nil
   smoothedCameraDistance = nil
   currentCamera = nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CustomCameraController.setMode(mode: "Overhead" | "Regular")
   CustomCameraController.Mode = mode
   if mode == "Overhead" then
      startOverheadMode()
   elseif mode == "Regular" then
      stopOverheadMode()
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CustomCameraController.init()
end

function CustomCameraController.start()
   local function onCharacterAdded(character)
      CustomCameraController.setMode("Overhead")
   end

   if localPlayer.Character then
      onCharacterAdded(localPlayer.Character)
   end

   localPlayer.CharacterAdded:Connect(onCharacterAdded)

   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.IsInRound:Subscribe(function(isInRound: boolean)
      if CustomCameraController.Mode == "Overhead" then
         placeCameraInstantly()
      end
   end)

   game:GetService("ContextActionService"):BindAction("SwitchCameraMode", function(actionName, inputState, inputObject)
      if inputState == Enum.UserInputState.Begin then
         if CustomCameraController.Mode == "Overhead" then
            CustomCameraController.setMode("Regular")
         else
            CustomCameraController.setMode("Overhead")
         end
      end
   end, false, Enum.KeyCode.C)
end

function CustomCameraController.test() end

return CustomCameraController
