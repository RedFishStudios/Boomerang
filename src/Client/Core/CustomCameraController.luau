--[[
   - The camera's preferred centerpoint should be the center of the current map arena.
     However, it can drift from this centerpoint towards the centerpoint calculated from the average center of all players or boomerangs on the map.
]]

local CustomCameraController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CAMERA_HEIGHT = 60
local CAMERA_TILT_DEGREES_FROM_VERTICAL = 30
local CAMERA_BACK_OFFSET = CAMERA_HEIGHT * math.tan(math.rad(CAMERA_TILT_DEGREES_FROM_VERTICAL))

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local currentCamera: Camera? = nil
local currentRootPart: Part? = nil
local topDownCameraConnection: RBXScriptConnection? = nil

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CustomCameraController.Mode = "TopDown" :: "TopDown" | "Regular"

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function updateCamera()
   if not currentCamera then
      return
   end
   if not currentRootPart then
      return
   end

   local focusPosition = currentRootPart.Position
   local targetPosition = focusPosition + Vector3.new(0, CAMERA_HEIGHT, CAMERA_BACK_OFFSET)

   -- Look at the character from a mostly-overhead angle with a 30 degree tilt.
   currentCamera.CFrame = CFrame.lookAt(targetPosition, focusPosition)
	currentCamera.Focus = currentRootPart.CFrame
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
   topDownCameraConnection = RunService.RenderStepped:Connect(updateCamera)
   currentRootPart = character.PrimaryPart
   currentCamera = workspace.CurrentCamera
   currentCamera.CameraType = Enum.CameraType.Scriptable
   currentCamera.FieldOfView = 60
end

local function stopTopDownMode()
   if topDownCameraConnection then
      topDownCameraConnection:Disconnect()
      topDownCameraConnection = nil
   end
   currentCamera = nil
   currentRootPart = nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CustomCameraController.setMode(mode: "TopDown" | "Regular")
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
   local function onCharacterAdded(character)
      CustomCameraController.setMode("TopDown")
   end

   if localPlayer.Character then
      onCharacterAdded(localPlayer.Character)
   end

   localPlayer.CharacterAdded:Connect(onCharacterAdded)
end

function CustomCameraController.start()
end

function CustomCameraController.test() end

return CustomCameraController
