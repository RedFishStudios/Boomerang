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
local ToolController = require(ReplicatedStorage.Client.Core.ToolController)
local CameraPaddingController = require(ReplicatedStorage.Client.Core.CameraPaddingController)
local TopDownCameraLibrary = require(ReplicatedStorage.Shared.Library.TopDownCameraLibrary)
local SettingsController = require(ReplicatedStorage.Client.Core.SettingsController)
local ArenaLibrary = require(ReplicatedStorage.Shared.Library.ArenaLibrary)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local LobbyController = require(ReplicatedStorage.Client.Core.LobbyController)

local localPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CAMERA_TILT_DEGREES_FROM_VERTICAL = 30 -- // How far the top-down camera leans back from straight down (0 = straight down)
local CAMERA_YAW_DEGREES = 0
local CAMERA_DISTANCE_PADDING = 20
local CAMERA_MIN_DISTANCE = 60
local CAMERA_FOCUS_SMOOTH_BASE = 11
local CAMERA_FOCUS_SMOOTH_DISTANCE_FACTOR = 0.08
local CAMERA_FOCUS_SMOOTH_MAX = 42
local CAMERA_DISTANCE_SMOOTH_BASE = 9
local CAMERA_DISTANCE_SMOOTH_DISTANCE_FACTOR = 0.04
local CAMERA_DISTANCE_SMOOTH_MAX = 30
-- // FAKE ORTHOGRAPHIC (2026-11-02): Roblox has no orthographic camera, so the top-down camera uses a narrow field of view
-- // from further away, which flattens perspective (walls lean less, everything keeps nearly the same size across the
-- // arena). The distance is still worked out so everything to show fits, but the camera never goes further than
-- // OVERHEAD_MAX_DISTANCE_FROM_CHARACTER from the player's character: when the narrow view would need more, the field of
-- // view opens up (up to OVERHEAD_MAX_FIELD_OF_VIEW) just enough to fit within that distance.
local OVERHEAD_FIELD_OF_VIEW = 20 -- // Vertical degrees. Lower = flatter, but further away. The old top-down camera used 60
local OVERHEAD_MAX_FIELD_OF_VIEW = 60 -- // The widest it may open to keep everything framed within the distance limit
local OVERHEAD_MAX_DISTANCE_FROM_CHARACTER = 299 -- // Studs (300 with a margin)
local REFERENCE_FIELD_OF_VIEW = 60 -- // CAMERA_DISTANCE_PADDING / CAMERA_MIN_DISTANCE were tuned at this FOV; they scale with it
local PARRY_SHAKE_DURATION = 0.28
local PARRY_SHAKE_POSITION = 0.9
local PARRY_SHAKE_ROTATION_DEGREES = 7
local PARRY_SHAKE_FREQUENCY = 34

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type CameraMode = "Overhead" | "Regular"

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local thrownWeaponsFolder = game.Workspace:WaitForChild("Weapons")

local currentCamera: Camera? = nil
local overheadCameraConnection: RBXScriptConnection? = nil
local cameraShakeConnection: RBXScriptConnection? = nil
local smoothedFocusPosition: Vector3? = nil
local smoothedCameraDistance: number? = nil
local smoothedFieldOfView: number? = nil -- // FAKE ORTHOGRAPHIC (2026-11-02)
local parryShakeStart: number? = nil
local parryShakeEnd: number? = nil

-- // The mode the player wants in the arena (top-down by default; C toggles it). The lobby always forces Regular
-- // (over-the-shoulder) on top of this, and leaving the lobby restores it.
local lastModeSet: CameraMode = "Overhead"

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CustomCameraController.Mode = "Overhead" :: CameraMode

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Get list of objects that should be included in view
local function getCameraFocusMapObjects(): {Instance?}
   local currentMap = ArenaLibrary.getArenaModel()
   if not currentMap then
      return {}
   end
   local cameraFocusFolder = currentMap:FindFirstChild("CameraFocus")
   if not cameraFocusFolder then
      return {}
   end
   return cameraFocusFolder:GetChildren()
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
      for i, p in pairs(getCameraFocusMapObjects()) do
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
      --[[for _, weapon in ipairs(thrownWeaponsFolder:GetChildren()) do
         if ToolController.isHolstered(weapon) then
            continue
         end
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
      end]]
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

local function getPaddingFraming(viewportSize: Vector2): (number, number, number, number)
   local viewportWidth = math.max(viewportSize.X, 1)
   local viewportHeight = math.max(viewportSize.Y, 1)

   local topPadding = math.clamp(CameraPaddingController.getTopPadding(), 0, viewportHeight)
   local bottomPadding = math.clamp(CameraPaddingController.getBottomPadding(), 0, viewportHeight)
   local leftPadding = math.clamp(CameraPaddingController.getLeftPadding(), 0, viewportWidth)
   local rightPadding = math.clamp(CameraPaddingController.getRightPadding(), 0, viewportWidth)

   local usableHalfWidthNdc = math.max(1 - ((leftPadding + rightPadding) / viewportWidth), 1e-3)
   local usableHalfHeightNdc = math.max(1 - ((topPadding + bottomPadding) / viewportHeight), 1e-3)

   local centerNdcX = (leftPadding - rightPadding) / viewportWidth
   local centerNdcY = (bottomPadding - topPadding) / viewportHeight
   return usableHalfWidthNdc, usableHalfHeightNdc, centerNdcX, centerNdcY
end

-- // Get required camera distance for the camera to possess these subjects within its view
local function getRequiredDistanceForSize(size: Vector3, cameraBasis: CFrame, aspectRatio: number, verticalFovRadians: number, usableHalfWidthNdc: number, usableHalfHeightNdc: number)
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

   local distanceFromWidth = if tanHorizontal > 0 then halfWidth / (tanHorizontal * usableHalfWidthNdc) else 0
   local distanceFromHeight = if tanVertical > 0 then halfHeight / (tanVertical * usableHalfHeightNdc) else 0
   return math.max(distanceFromWidth, distanceFromHeight)
end

local function getFocusOffsetForPadding(cameraBasis: CFrame, distance: number, aspectRatio: number, verticalFovRadians: number, centerNdcX: number, centerNdcY: number): Vector3
   local tanVertical = math.tan(verticalFovRadians / 2)
   local horizontalFovRadians = 2 * math.atan(tanVertical * aspectRatio)
   local tanHorizontal = math.tan(horizontalFovRadians / 2)

   local rightShift = -centerNdcX * distance * tanHorizontal
   local upShift = -centerNdcY * distance * tanVertical
   return cameraBasis.RightVector * rightShift + cameraBasis.UpVector * upShift
end

-- // The top-down camera's tilt and target field of view: Cmdr overrides (TopDownCameraLibrary), else the defaults above
local function getTiltDegrees(): number
   return TopDownCameraLibrary.get("Tilt") or CAMERA_TILT_DEGREES_FROM_VERTICAL
end

local function getTargetFieldOfView(): number
   return TopDownCameraLibrary.get("FieldOfView") or OVERHEAD_FIELD_OF_VIEW
end

-- // FAKE ORTHOGRAPHIC (2026-11-02): the furthest the camera may sit from `focusPosition` along `focusToCameraDirection` while
-- // staying within OVERHEAD_MAX_DISTANCE_FROM_CHARACTER of the local character (|F + u*t - C| <= R, solved for the largest t)
local function getMaxCameraDistance(focusPosition: Vector3, focusToCameraDirection: Vector3): number
   local character = localPlayer.Character
   local root = character and character.PrimaryPart
   if not root then
      return OVERHEAD_MAX_DISTANCE_FROM_CHARACTER
   end
   local fromCharacter = focusPosition - root.Position
   local b = focusToCameraDirection:Dot(fromCharacter)
   local c = fromCharacter:Dot(fromCharacter) - OVERHEAD_MAX_DISTANCE_FROM_CHARACTER * OVERHEAD_MAX_DISTANCE_FROM_CHARACTER
   local discriminant = b * b - c
   if discriminant < 0 then
      return 1 -- // The focus itself is out of reach of the character: stay as close as possible
   end
   return math.max(-b + math.sqrt(discriminant), 1)
end

-- // FAKE ORTHOGRAPHIC (2026-11-02): the camera distance, vertical field of view (degrees) and padded focus that show every
-- // subject: the narrow OVERHEAD_FIELD_OF_VIEW when it fits within the distance limit, else the narrowest wider one that does
local function getOverheadFraming(focusPosition: Vector3, boxSize: Vector3, focusToCameraDirection: Vector3, viewportSize: Vector2): (number, number, Vector3)
   local aspectRatio = viewportSize.X / viewportSize.Y
   local usableHalfWidthNdc, usableHalfHeightNdc, centerNdcX, centerNdcY = getPaddingFraming(viewportSize)
   local baseCFrame = CFrame.lookAt(focusPosition + focusToCameraDirection, focusPosition)
   local referenceTan = math.tan(math.rad(REFERENCE_FIELD_OF_VIEW) / 2)

   local function distanceAt(fieldOfView: number): number
      local fovRadians = math.rad(fieldOfView)
      local scale = referenceTan / math.tan(fovRadians / 2)
      local required = getRequiredDistanceForSize(boxSize, baseCFrame, aspectRatio, fovRadians, usableHalfWidthNdc, usableHalfHeightNdc)
      return math.max(CAMERA_MIN_DISTANCE * scale, required + CAMERA_DISTANCE_PADDING * scale)
   end

   local maxDistance = getMaxCameraDistance(focusPosition, focusToCameraDirection)
   local fieldOfView = getTargetFieldOfView()
   local fixedDistance = TopDownCameraLibrary.get("Distance") -- // Cmdr override: a fixed distance, no fitting
   local distance = if fixedDistance then math.min(fixedDistance, maxDistance) else distanceAt(fieldOfView)
   if not fixedDistance and distance > maxDistance then
      -- // Too far: find the narrowest field of view that fits within the limit (binary search)
      local low, high = fieldOfView, math.max(OVERHEAD_MAX_FIELD_OF_VIEW, fieldOfView)
      for _ = 1, 12 do
         local middle = (low + high) / 2
         if distanceAt(middle) > maxDistance then
            low = middle
         else
            high = middle
         end
      end
      fieldOfView = high
      distance = math.min(distanceAt(fieldOfView), maxDistance)
   end

   local focusOffset = getFocusOffsetForPadding(baseCFrame, distance, aspectRatio, math.rad(fieldOfView), centerNdcX, centerNdcY)
   return distance, fieldOfView, focusPosition + focusOffset
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

   -- // FAKE ORTHOGRAPHIC (2026-11-02): a turn of the camera looks bigger in a narrower view, so it scales with the field of view
   local camera = workspace.CurrentCamera
   local rotationDegrees = PARRY_SHAKE_ROTATION_DEGREES * (if camera then camera.FieldOfView / REFERENCE_FIELD_OF_VIEW else 1)
   local rotation = CFrame.fromOrientation(
      math.rad(math.noise(shakeSeed + 11, 0, 0) * rotationDegrees * alpha),
      math.rad(math.noise(0, shakeSeed + 17, 0) * rotationDegrees * alpha),
      math.rad(math.noise(0, 0, shakeSeed + 23) * rotationDegrees * alpha)
   )

   return baseCFrame * CFrame.new(offset) * rotation
end

-- // Instantly place overhead camera to fit all visible subjects with no smoothing
local function placeCameraInstantly()
   if not currentCamera then
      return
   end
   local viewportSize = currentCamera.ViewportSize
   if viewportSize.X < 2 or viewportSize.Y < 2 then
      return -- // No usable view yet (e.g. a minimized window)
   end

   local focusPosition, boxSize = getAllSubjectsBoundingBox()
   if not focusPosition or not boxSize then
      return
   end

   local tiltRadians = math.rad(getTiltDegrees())
   local yawRadians = math.rad(CAMERA_YAW_DEGREES)

   local horizontalDirection = Vector3.new(math.sin(yawRadians), 0, math.cos(yawRadians))
   local focusToCameraDirection = (Vector3.yAxis * math.cos(tiltRadians) + horizontalDirection * math.sin(tiltRadians)).Unit

   local targetDistance, fieldOfView, paddedFocusPosition = getOverheadFraming(focusPosition, boxSize, focusToCameraDirection, viewportSize)

   smoothedFocusPosition = paddedFocusPosition
   smoothedCameraDistance = targetDistance
   smoothedFieldOfView = fieldOfView
   currentCamera.FieldOfView = fieldOfView

   local cameraPosition = paddedFocusPosition + focusToCameraDirection * targetDistance
   currentCamera.CFrame = CFrame.lookAt(cameraPosition, paddedFocusPosition, Vector3.yAxis)
   currentCamera.Focus = CFrame.new(paddedFocusPosition)
end

-- // Update camera for overhead position
local function updateCamera(deltaTime: number)
   if not currentCamera then
      return
   end

   local viewportSize = currentCamera.ViewportSize
   if viewportSize.X < 2 or viewportSize.Y < 2 then
      return -- // No usable view (e.g. a minimized window): keep the last placement
   end

   local focusPosition, boxSize = getAllSubjectsBoundingBox()
   if not focusPosition or not boxSize then
      return
   end

   local tiltRadians = math.rad(getTiltDegrees())
   local yawRadians = math.rad(CAMERA_YAW_DEGREES)

   local horizontalDirection = Vector3.new(math.sin(yawRadians), 0, math.cos(yawRadians))
   local focusToCameraDirection = (Vector3.yAxis * math.cos(tiltRadians) + horizontalDirection * math.sin(tiltRadians)).Unit

   local targetDistance, targetFieldOfView, paddedFocusPosition = getOverheadFraming(focusPosition, boxSize, focusToCameraDirection, viewportSize)

   if not smoothedFocusPosition or not smoothedCameraDistance or not smoothedFieldOfView then
      smoothedFocusPosition = paddedFocusPosition
      smoothedCameraDistance = targetDistance
      smoothedFieldOfView = targetFieldOfView
   else
      -- // FAKE ORTHOGRAPHIC (2026-11-02): the field of view eases like the distance does
      smoothedFieldOfView = stepSmoothNumber(
         smoothedFieldOfView,
         targetFieldOfView,
         CAMERA_DISTANCE_SMOOTH_BASE,
         CAMERA_DISTANCE_SMOOTH_DISTANCE_FACTOR,
         CAMERA_DISTANCE_SMOOTH_MAX,
         deltaTime
      )
      smoothedFocusPosition = stepSmoothVector3(
         smoothedFocusPosition,
         paddedFocusPosition,
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

   -- // FAKE ORTHOGRAPHIC (2026-11-02): never further than the limit from the character, even mid-smoothing
   local cameraDistance = math.min(smoothedCameraDistance, getMaxCameraDistance(smoothedFocusPosition, focusToCameraDirection))
   currentCamera.FieldOfView = smoothedFieldOfView
   local cameraPosition = smoothedFocusPosition + focusToCameraDirection * cameraDistance
   local now = os.clock()

	-- Keep orientation stable by deriving camera position from fixed yaw/tilt and smoothed focus+distance.
	currentCamera.CFrame = applyParryShake(CFrame.lookAt(cameraPosition, smoothedFocusPosition, Vector3.yAxis), now)
	currentCamera.Focus = CFrame.new(smoothedFocusPosition)
end

local function updateCameraShake()
   local camera = workspace.CurrentCamera
   if not camera then
      return
   end

   if CustomCameraController.Mode == "Overhead" then
      return
   end

   local now = os.clock()
   camera.CFrame = applyParryShake(camera.CFrame, now)
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
   -- // The mode may have changed while waiting for the character (e.g. the lobby forced Regular): don't turn top-down back on
   if overheadCameraConnection or CustomCameraController.Mode ~= "Overhead" then
      return
   end

   UserInputService.MouseBehavior = Enum.MouseBehavior.Default
   UserInputService.MouseIconEnabled = true

   currentCamera = workspace.CurrentCamera
   currentCamera.CameraType = Enum.CameraType.Scriptable
   currentCamera.FieldOfView = getTargetFieldOfView()
   smoothedFocusPosition = nil
   smoothedCameraDistance = nil
   smoothedFieldOfView = nil
   placeCameraInstantly()
   overheadCameraConnection = RunService.RenderStepped:Connect(updateCamera)
end

local function stopOverheadMode()
   currentCamera = workspace.CurrentCamera

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
   currentCamera.FieldOfView = REFERENCE_FIELD_OF_VIEW -- // FAKE ORTHOGRAPHIC (2026-11-02): the over-the-shoulder camera keeps the old 60
   smoothedFocusPosition = nil
   smoothedCameraDistance = nil
   smoothedFieldOfView = nil
   currentCamera = nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

local function applyMode(mode: CameraMode)
   CustomCameraController.Mode = mode
   if mode == "Overhead" then
      startOverheadMode()
   elseif mode == "Regular" then
      stopOverheadMode()
   end
end

-- // In the lobby: always over-the-shoulder, with a free mouse
local function applyLobbyMode()
   applyMode("Regular")
   UserInputService.MouseBehavior = Enum.MouseBehavior.Default
   UserInputService.MouseIconEnabled = true
end

-- // Sets the player's arena camera mode. In the lobby it's only remembered (applied when they leave); the lobby stays Regular.
function CustomCameraController.setMode(mode: "Overhead" | "Regular")
   lastModeSet = mode
   if LobbyController.isInLobby() then
      if CustomCameraController.Mode ~= "Regular" then
         applyLobbyMode()
      end
      return
   end
   applyMode(mode)
end

function CustomCameraController.getMode()
   return CustomCameraController.Mode
end

function CustomCameraController.parryEffect()
   if not SettingsController.getValue("CameraShake") then
      return -- // Camera Shake setting is off
   end
   local now = os.clock()
   parryShakeStart = now
   parryShakeEnd = now + PARRY_SHAKE_DURATION
end

function CustomCameraController.cancelParryEffect()
   parryShakeEnd = os.clock()
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

-- // The arena camera mode the Camera Mode setting asks for
local function getSettingMode(): CameraMode
   return if SettingsController.getValue("OverShoulderCamera") then "Regular" else "Overhead"
end

function CustomCameraController.init()
   CustomCameraController.setMode(getSettingMode())

   SettingsController.SettingChangedTasks:Add(function(settingName, _value)
      if settingName == "OverShoulderCamera" then
         CustomCameraController.setMode(getSettingMode())
      end
   end)

   LobbyController.ClientIsInLobbyChangedTasks:Add(function(isInLobby)
      if isInLobby then
         applyLobbyMode() -- // lastModeSet (the arena preference) is kept for when they leave
      else
         applyMode(lastModeSet)
      end
   end)

   -- // Safety net: whatever order joining/spawning/lobby detection happen in, the lobby is never top-down
   RunService.Heartbeat:Connect(function()
      if LobbyController.isInLobby() and CustomCameraController.Mode ~= "Regular" then
         applyLobbyMode()
      end
   end)
end

function CustomCameraController.start()
   local initialModeSet = false
   local function onCharacterAdded(character)
      if initialModeSet then
         return
      end
      initialModeSet = true
      CustomCameraController.setMode(getSettingMode())
   end

   if localPlayer.Character then
      onCharacterAdded(localPlayer.Character)
   end

   localPlayer.CharacterAdded:Connect(onCharacterAdded)

   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.CurrentRoundData:Subscribe(function()
      CustomCameraController.cancelParryEffect()
      if CustomCameraController.Mode == "Overhead" then
         placeCameraInstantly()
      end
   end)

   game:GetService("ContextActionService"):BindAction("SwitchCameraMode", function(actionName, inputState, inputObject)
      if LobbyController.isInLobby() then
         return
      end
      if inputState == Enum.UserInputState.Begin then
         -- // Changes the Camera Mode setting (saved); its change handler in init() switches the camera
         SettingsController.setValue("OverShoulderCamera", CustomCameraController.Mode == "Overhead")
      end
   end, false, Enum.KeyCode.C)

   if not cameraShakeConnection then
      cameraShakeConnection = RunService:BindToRenderStep("CustomCameraParryShake", Enum.RenderPriority.Camera.Value + 1, updateCameraShake)
   end
end

function CustomCameraController.test() end

return CustomCameraController