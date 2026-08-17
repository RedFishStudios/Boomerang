--[[
  Manages a simple system of detecting player deaths/respawns

  Author:
  @Soulsplosion
]]

local SpawnService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local LobbyService = require(ServerStorage.Server.Core.LobbyService)
local IntermissionStageEnums = require(ReplicatedStorage.Shared.Constants.Enums.IntermissionStages)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function safeGetPlayerCharacter(player: Player)
   if not player.Character then
      local passed = 0
      repeat
         task.wait()
         print(`waiting for player character: {player}`)
         passed += 1
      until passed >= 300 or player.Character
      if not player.Character then
         warn(`player character never loaded: {player}`)
         return nil
      end
   end
   return player.Character
end

-- // NOTE: Do not rely on this for critical game logic. See ArenaService for intelligent arena spawnpoint management, and RoundCyclingService for whether Arena or Lobby spawning isused
--    Usage of player.RespawnLocation is for generally improved rendering prioritization by keeping the player with an understanding of the general area they will probably go
local function setPlayerSpawnpoint(player: Player)
   local gameStateData = GameStateLibrary.getGameStateData()
   if gameStateData.IsInRound:Get() and gameStateData.CanRespawn:Get() then
      player.RespawnLocation = ArenaService.getSpawnPoint(player)
   else
      player.RespawnLocation = LobbyService.getSpawnPoint()
      GameTeamService.setOutOfGame(player)
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SpawnService.sendPlayerTo(player: Player, location: Vector3, forceLive: boolean?)
   local character = safeGetPlayerCharacter(player)
   if not character then
      return
   end
   local humanoid = character:FindFirstChildWhichIsA("Humanoid")
   if not humanoid then
      return
   end
   if forceLive and humanoid.Health <= 0 then
      player.CharacterAdded:Once(function()
         character = safeGetPlayerCharacter(player)
         SpawnService.sendPlayerTo(player, location, true)
      end)
      player:LoadCharacterAsync()
      return
   end
   local rootPart = character:FindFirstChild("HumanoidRootPart")
   if not rootPart then
      return
   end
   local rayOrigin = location + Vector3.new(0, 5, 0)
   local rayDirection = Vector3.new(0, -10, 0)
   local raycastParams = RaycastParams.new()
   raycastParams.FilterDescendantsInstances = {character}
   raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
   local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
   if rayResult then
      character:PivotTo(CFrame.new(rayResult.Position + Vector3.new(0, 3, 0)))
   else
      character:PivotTo(CFrame.new(location))
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SpawnService.init()
   local gameStateData = GameStateLibrary.getGameStateData()

   gameStateData.IntermissionStage:Subscribe(function(newIntermissionStage: number?)
      if newIntermissionStage == IntermissionStageEnums.LobbyVoting then
         warn(`lobby voting began!`)
         local lobbySpawnPosition = LobbyService.getSpawnPoint().Position
         for _, player in pairs(Players:GetPlayers()) do
            SpawnService.sendPlayerTo(player, lobbySpawnPosition, true)
         end
      end
   end)

   PlayersUtil.PlayerAdded:Add(function(player: Player)
      setPlayerSpawnpoint(player)
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player)
      setPlayerSpawnpoint(player)
      -- TODO: display death screen, respawn time, etc
   end)

      PlayersUtil.CharacterLoaded:Add(function(player: Player, _character: Model, _humanoid: Humanoid, _rootPart: BasePart)
         -- // Add to LivingPlayersInArena
         if gameStateData.IsInRound:Get() == false then
            return
         end
         if gameStateData.CanRespawn:Get() == false then
            return
         end
         local currentLivingPlayers = gameStateData.LivingPlayersInArena:Get()
         local livingPlayersInArena = table.clone(currentLivingPlayers)
         if not table.find(livingPlayersInArena, player) then
            table.insert(livingPlayersInArena, player)
            GameStateLibrary.applyValues({
               LivingPlayersInArena = livingPlayersInArena,
            })
         end
         ArenaService.sendToArena(player)
      end)
end

function SpawnService.start()

end

function SpawnService.test()

end

return SpawnService