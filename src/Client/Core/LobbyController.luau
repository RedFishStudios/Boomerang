local LobbyController = {}

local player = game.Players.LocalPlayer

local RunService = game:GetService("RunService")

local GameStateLibrary = require(game.ReplicatedStorage.Shared.Library.GameStateLibrary)

local LobbyLibrary = require(game.ReplicatedStorage.Shared.Library.LobbyLibrary)
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

-- // Jumping is enabled only in the lobby. The client sets it for its own prediction; the server sets the same
-- // state for the authoritative character (CharacterService, T-070). Both use LobbyLibrary.applyJumpState.
local function applyJumpState(character: Model)
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not humanoid then
      return
   end
   LobbyLibrary.applyJumpState(humanoid, isInLobby)
end

local function updateIsInLobby()
   local character = player.Character
   if not character then
      return
   end

   -- Check using volume check
   if LobbyLibrary.isCharacterInLobby(character) then
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

   applyJumpState(character)
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