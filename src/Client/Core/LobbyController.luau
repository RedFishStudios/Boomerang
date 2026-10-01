local LobbyController = {}

local player = game.Players.LocalPlayer

local RunService = game:GetService("RunService")

local GameStateLibrary = require(game.ReplicatedStorage.Shared.Library.GameStateLibrary)

local GlobalConfig = require(game.ReplicatedStorage.Shared.Constants.GlobalConfig)
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

-- // Jumping is enabled only in the lobby. Set locally because the client simulates its own character;
-- // the server disables jumping when the character loads (CharacterService), and this re-enables it in the lobby.
local function applyJumpState(character: Model)
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not humanoid then
      return
   end
   local jumpHeight = if isInLobby then GlobalConfig.LobbyJumpHeight else 0
   if humanoid.UseJumpPower then
      humanoid.UseJumpPower = false
   end
   if humanoid.JumpHeight ~= jumpHeight then
      humanoid.JumpHeight = jumpHeight
      humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, isInLobby)
   end
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