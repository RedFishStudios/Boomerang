--[[

]]

local CustomCameraController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local localPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

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

	-- Calculate position and rotation
	local offset = Vector3.new(0, 100, 0)
	local targetPosition = currentRootPart.Position + offset
	local targetRotation = CFrame.Angles(-math.pi / 2, 0, 0)
	
	-- Apply camera CFrame
	currentCamera.CFrame = CFrame.new(targetPosition) * targetRotation
	currentCamera.Focus = currentRootPart.CFrame

   print(#CurrentGameState.LivingPlayersInArena:Get())
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
