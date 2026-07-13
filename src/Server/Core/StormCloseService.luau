--[[
  StormCloseService

  Description:
  Handles server-side player data

  Author:
  @SixthAtom

  Date:
  20-02-2026
]]

local StormCloseService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ProfileStore = require(ServerStorage.Packages.ProfileStore)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SHRINK_INTERVAL = 5
local SHRINK_MULTIPLIER = 0.9
local MAX_SHRINKS = 5

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local visibleSafetyRadiusPart = Instance.new("Part")
visibleSafetyRadiusPart.Name = "VisibleSafetyRadiusPart"
visibleSafetyRadiusPart.Shape = Enum.PartType.Cylinder
visibleSafetyRadiusPart.Size = Vector3.new(1, 500, 500)
visibleSafetyRadiusPart.Orientation = Vector3.new(0, 0, 90)
visibleSafetyRadiusPart.Anchored = true
visibleSafetyRadiusPart.CanCollide = false
visibleSafetyRadiusPart.CanQuery = false
visibleSafetyRadiusPart.CanTouch = false
visibleSafetyRadiusPart.Transparency = .8
visibleSafetyRadiusPart.Material = Enum.Material.Neon
visibleSafetyRadiusPart.Color = Color3.new(0.247059, 1, 0.74902)
visibleSafetyRadiusPart.Parent = game.ReplicatedStorage.Shared.Assets

local currentStormCloseConnection: RBXScriptConnection? = nil
local currentStormClosePart: BasePart? = nil
local stormCloseElapsed = 0
local stormCloseShrinkCount = 0

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

local function updateStormClose(deltaTime: number)
   local stormClosePart = currentStormClosePart
   if not stormClosePart or not stormClosePart.Parent then
      if currentStormCloseConnection then
         currentStormCloseConnection:Disconnect()
         currentStormCloseConnection = nil
      end
      currentStormClosePart = nil
      stormCloseElapsed = 0
      stormCloseShrinkCount = 0
      return
   end

   stormCloseElapsed += deltaTime
   if stormCloseElapsed < SHRINK_INTERVAL then
      return
   end

   stormCloseElapsed -= SHRINK_INTERVAL
   stormCloseShrinkCount += 1

   stormClosePart.Size = Vector3.new(
      stormClosePart.Size.X,
      stormClosePart.Size.Y * SHRINK_MULTIPLIER,
      stormClosePart.Size.Z * SHRINK_MULTIPLIER
   )

   if stormCloseShrinkCount >= MAX_SHRINKS then
      stormClosePart:Destroy()
      currentStormClosePart = nil

      if currentStormCloseConnection then
         currentStormCloseConnection:Disconnect()
         currentStormCloseConnection = nil
      end

      stormCloseElapsed = 0
      stormCloseShrinkCount = 0
   end
end

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function StormCloseService.begin(centrepoint: Vector3)
   local stormClosePart = visibleSafetyRadiusPart:Clone()
   stormClosePart.Position = Vector3.new(centrepoint.X, GlobalConfig.BoomerangHeight, centrepoint.Z)
   stormClosePart.Orientation = Vector3.new(0, 0, 90)
   stormClosePart.Parent = workspace
   stormClosePart.Size = Vector3.new(1, 500, 500)
   stormClosePart.Transparency = 1
   currentStormClosePart = stormClosePart
   stormCloseElapsed = 0
   stormCloseShrinkCount = 0

   if currentStormCloseConnection then
      currentStormCloseConnection:Disconnect()
      currentStormCloseConnection = nil
   end
   currentStormCloseConnection = RunService.Heartbeat:Connect(updateStormClose)
end

function StormCloseService.teardown()
   if currentStormCloseConnection then
      currentStormCloseConnection:Disconnect()
      currentStormCloseConnection = nil
   end
   if currentStormClosePart and currentStormClosePart.Parent then
      currentStormClosePart:Destroy()
   end
   currentStormClosePart = nil
   stormCloseElapsed = 0
   stormCloseShrinkCount = 0
end

-- // Disable further behavior without tearing down completely
function StormCloseService.disable()
   if currentStormCloseConnection then
      currentStormCloseConnection:Disconnect()
      currentStormCloseConnection = nil
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function StormCloseService.init()
end

function StormCloseService.start()
   CurrentGameState.RoundStartingTasks:Add(function()
      StormCloseService.teardown()
   end)
   CurrentGameState.RoundFinishedTasks:Add(function()
      StormCloseService.disable()
   end)
end

return StormCloseService
