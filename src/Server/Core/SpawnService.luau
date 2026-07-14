--[[
  Manages where players should spawn

  Author:
  @Soulsplosion
]]

local SpawnService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GameTeamService = require(ServerStorage.Server.Core.GameTeamService)

local LobbyService = require(ServerStorage.Server.Core.LobbyService)

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

local function setPlayerSpawnpoint(player: Player)
   print(`setting player spawnpoint: {player}`)
   local gameStateData = CurrentGameState.getGameStateData()
   if gameStateData.IsInRound:Get() and gameStateData.CanRespawn:Get() then
      print(`player will respawn in arena: {player}`)
      player.RespawnLocation = ArenaService.getSpawnPoint(player)
   else
      print(`player will respawn in lobby: {player}`)
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
   local function initialCharacterSend(player: Player)
      if player.RespawnLocation then
         print(`initial character {player} send to: {player.RespawnLocation}`)
         SpawnService.sendPlayerTo(player, player.RespawnLocation.Position)
      end
   end

   PlayersUtil.PlayerAdded:Add(function(player: Player)
      setPlayerSpawnpoint(player)
      initialCharacterSend(player)
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player)
      setPlayerSpawnpoint(player)
      -- TODO: display death screen, respawn time, etc
   end)
end

function SpawnService.start()

end

function SpawnService.test()

end

return SpawnService