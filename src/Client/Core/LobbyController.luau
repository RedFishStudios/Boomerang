local LobbyController = {}

local player = game.Players.LocalPlayer

local RunService = game:GetService("RunService")

local GameStateLibrary = require(game.ReplicatedStorage.Shared.Library.GameStateLibrary)

local CollisionGroupConstants = require(game.ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local CharacterRenderController = require(game.ReplicatedStorage.Client.Core.CharacterRenderController)
local TasksList = require(game.ReplicatedStorage.Shared.Classes.TasksList)

-------------------------------------------------------------------------------
-- LOCAL VALUES
-------------------------------------------------------------------------------

local isInLobby = false

-------------------------------------------------------------------------------
-- PUBLIC VALUES
-------------------------------------------------------------------------------

LobbyController.ClientIsInLobbyChangedTasks = TasksList.new() :: TasksList.TasksList<(isInLobby: boolean) -> ()>

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

local function updateIsInLobby()
   local character = player.Character
   if not character then
      return
   end

   -- Check using volume check
   local point = character:GetPivot()
   local params = OverlapParams.new()
   params.CollisionGroup = CollisionGroupConstants.LobbyVolume
   local partsInVolume = workspace:GetPartBoundsInBox(point, Vector3.new(1, 1, 1), params)
   if next(partsInVolume) then
      if not isInLobby then
         isInLobby = true
         LobbyController.ClientIsInLobbyChangedTasks:Execute("parallel", isInLobby)
      end
   else
      if isInLobby then
         isInLobby = false
         LobbyController.ClientIsInLobbyChangedTasks:Execute("parallel", isInLobby)
      end
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function LobbyController.isInLobby()
   return isInLobby
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LobbyController.init()
   RunService.Heartbeat:Connect(function()
      updateIsInLobby()
   end)
end

function LobbyController.start()
end

return LobbyController