-- // Manages clientside replication of player characters, including their own

local CharacterReplicationController = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalInstanceController = require(ReplicatedStorage.Client.Controllers.GlobalInstanceController)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local CharactersFolder = game.Workspace.Characters
local unreliableEvent = SimpleRemotes.getUnreliableEvent("CharacterReplication")

local renders: {
   [Model]: {
      Model: Model,
      HipHeight: number,
      LastPosition: Vector3?
   }
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function onCharacterLoaded(player, character, humanoid: Humanoid, primaryPart: Part)
   humanoid.StateChanged:Connect(function(oldState, newState)
      print(newState)
   end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterReplicationController.init()
   for _, P in pairs(PlayersUtil.getPlayersWithLoadedCharacters()) do
      onCharacterLoaded(P, P.Character, P.Character.Humanoid, P.Character.PrimaryPart)
   end

   PlayersUtil.CharacterLoaded:Add(onCharacterLoaded)
end

function CharacterReplicationController.start()
   
end

return CharacterReplicationController