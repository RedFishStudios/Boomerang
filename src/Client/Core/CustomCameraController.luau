--[[
   - The camera's preferred centerpoint should be the center of the current map arena.
     However, it can drift from this centerpoint towards the centerpoint calculated from the average center of all players or boomerangs on the map.
]]

local CustomCameraController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

local localPlayer = Players.LocalPlayer

local MapFolder = game.Workspace:WaitForChild("Arena")

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
local PARRY_SHAKE_DURATION = 0.28
local PARRY_SHAKE_POSITION = 0.9
local PARRY_SHAKE_ROTATION_DEGREES = 7
local PARRY_SHAKE_FREQUENCY = 34

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local thrownWeaponsFolder = game.Workspace:WaitForChild("Weapons")

local currentCamera: Camera? = nil
local overheadCameraConnection: RBXScriptConnection? = nil
local cameraShakeConnection: RBXScriptConnection? = nil
local smoothedFocusPosition: Vector3? = nil
local smoothedCameraDistance: number? = nil
local parryShakeStart: number? = nil
local parryShakeEnd: number? = nil

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CustomCameraController.Mode = "Overhead" :: "Overhead" | "Regular"

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Get list of objects that should be included in view
local function getImportantMapObjects(): {Instance?}
   local currentMap = MapFolder:FindFirstChildWhichIsA("Model")
   if not currentMap then
      return {}
   end
   local Important = currentMap:FindFirstChild("Important")
   if not Important then
      return {}
   end
   return Important:GetChildren()
end

-- // Get parameters for the Overhead camera to have these desired objects within its view
local function getAllSubjectsBoundingBox()
   local min = Vector3.new(math.huge, math.huge, math.huge)
   local max = Vector3.new(-math.huge, -math.huge, -math.huge)

   local positions: {Vector3} = {}
   local sizes: {Vector3} = {}
   local gameStateData = GameStateLibrary.getGameStateData()

   local livingPlayersInArena = gameStateData.LivingPlayersInArena:Get()
   local localPlayerIsInArena = table.find(livingPlayersInArena, localPlayer) ~= nil
   if not localPlayerIsInArena then
      -- Client is not alive in the arena
      if localPlayer.Character and localPlayer.Character.PrimaryPart then
         table.insert(positions, localPlayer.Character.PrimaryPart.Position)
         table.insert(sizes, localPlayer.Character.PrimaryPart.Size)
      end
   else
      -- Client is alive and in map
      for i, p in pairs(getImportantMapObjects()) do
         if p:IsA("BasePart") then
            table.insert(positions, p.Position)
            table.insert(sizes, p.Size)
         elseif p:IsA("Model") then
            local bounds = p:FindFirstChild("CameraBounds") or p.PrimaryPart
            if bounds then
               table.insert(positions, bounds.Position)
               table.insert(sizes, bounds.Size)
            end
         end
      end

      for _, player in ipairs(gameStateData.LivingPlayersInArena:Get()) do
         if player.Team and player.Team.Name == "OutOfGame" then
            warn(`player with out of game team is detected in living players list: {player}`)
            continue
         end
         if player.Character and player.Character.PrimaryPart then
            local position = player.Character.PrimaryPart.Position
            position = Vector3.new(position.X, GlobalConfig.CharacterFocalHeight, position.Z)
            table.insert(positions, position)
            table.insert(sizes, player.Character.PrimaryPart.Size)
         end
      end
      for _, weapon in ipairs(thrownWeaponsFolder:GetChildren()) do
         if weapon:IsA("BasePart") then
            table.insert(positions, weapon.Position)
            table.insert(sizes, weapon.Size)
         elseif weapon:IsA("Model") then
            local primaryPart = weapon.PrimaryPart
            if primaryPart then
               table.insert(positions, primaryPart.Position)
               table.insert(sizes, primaryPart.Size)
            end
         elseif weapon:IsA("Tool") then
            local handle = weapon:FindFirstChild("Handle")
            if handle then
               table.insert(positions, handle.Position)
               table.insert(sizes, handle.Size)
            end
         end
      end
   end

   if #positions == 0 then
      local character = localPlayer.Character
      local root = character and character.PrimaryPart
      if root then
         table.insert(positions, root.Position)
         table.insert(sizes, root.Size)
      end
   end

   if #positions == 0 then
      return nil
   end

   for i, position in ipairs(positions) do
      local p = position
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

local function getParryShakeAlpha(now: number): number
   if not parryShakeStart or not parryShakeEnd then
      return 0
   end

   if now >= parryShakeEnd then
      return 0
   end

   local duration = math.max(parryShakeEnd - parryShakeStart, 1e-4)
   local elapsed = now - parryShakeStart
   local t = math.clamp(elapsed / duration, 0, 1)
   return (1 - t) ^ 2
end

local function applyParryShake(baseCFrame: CFrame, now: number): CFrame
   local alpha = getParryShakeAlpha(now)
   if alpha <= 0 then
      return baseCFrame
   end

   local shakeSeed = now * PARRY_SHAKE_FREQUENCY
   local offset = Vector3.new(
      math.noise(shakeSeed, 0, 0),
      math.noise(0, shakeSeed, 0),
      math.noise(0, 0, shakeSeed)
   ) * (PARRY_SHAKE_POSITION * alpha)

   local rotation = CFrame.fromOrientation(
      math.rad(math.noise(shakeSeed + 11, 0, 0) * PARRY_SHAKE_ROTATION_DEGREES * alpha),
      math.rad(math.noise(0, shakeSeed + 17, 0) * PARRY_SHAKE_ROTATION_DEGREES * alpha),
      math.rad(math.noise(0, 0, shakeSeed + 23) * PARRY_SHAKE_ROTATION_DEGREES * alpha)
   )

   return baseCFrame * CFrame.new(offset) * rotation
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
   local now = os.clock()

	-- Keep orientation stable by deriving camera position from fixed yaw/tilt and smoothed focus+distance.
	currentCamera.CFrame = applyParryShake(CFrame.lookAt(cameraPosition, smoothedFocusPosition, Vector3.yAxis), now)
	currentCamera.Focus = CFrame.new(smoothedFocusPosition)
end

local function updateCameraShake()
   if not currentCamera then
      return
   end

   if CustomCameraController.Mode == "Overhead" then
      return
   end

   local now = os.clock()
   currentCamera.CFrame = applyParryShake(currentCamera.CFrame, now)
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

   UserInputService.MouseBehavior = Enum.MouseBehavior.Default
   UserInputService.MouseIconEnabled = true

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

   UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
   UserInputService.MouseIconEnabled = false

   local character = localPlayer.Character
   if character then
      local rootPart = character:FindFirstChild("HumanoidRootPart")
      if rootPart then
         local cameraPosition = rootPart.Position + Vector3.new(0, 3, 0) - rootPart.CFrame.LookVector * 10
         currentCamera.CFrame = CFrame.lookAt(cameraPosition, rootPart.Position, Vector3.yAxis)
         currentCamera.CameraSubject = character.Humanoid
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

function CustomCameraController.parryEffect()
   print("PARRY EFFECT")
   local now = os.clock()
   parryShakeStart = now
   parryShakeEnd = now + PARRY_SHAKE_DURATION
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
   game:GetService("ContextActionService"):BindAction("ParryTest", function(actionName, inputState, inputObject)
      if inputState == Enum.UserInputState.Begin then
         CustomCameraController.parryEffect()
      end
   end, false, Enum.KeyCode.P)

   if not cameraShakeConnection then
      cameraShakeConnection = RunService:BindToRenderStep("CustomCameraParryShake", Enum.RenderPriority.Camera.Value + 1, updateCameraShake)
   end
end

function CustomCameraController.test() end

return CustomCameraController
